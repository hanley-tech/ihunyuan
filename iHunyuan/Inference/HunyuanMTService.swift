import Foundation
import SwiftUI
import MLX
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import Tokenizers
import NaturalLanguage

enum HunyuanMTError: LocalizedError {
    case modelLoadFailed(String)
    case generationFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .modelLoadFailed(let m): return "Couldn't load the translation model: \(m)"
        case .generationFailed(let m): return "Translation failed: \(m)"
        case .cancelled: return "Translation cancelled."
        }
    }
}

struct PerfSample: Identifiable, Hashable, Sendable {
    let id = UUID()
    let timestamp: Date
    let ttftMs: Double
    let tokensPerSecond: Double
    let generatedTokens: Int
}

/// Sendable holder for streaming state captured by the generation closure —
/// avoids "mutation of captured var in concurrently-executing code" diagnostics.
private final class StreamState: @unchecked Sendable {
    var startedAt: Date = Date()
    var firstTokenAt: Date?
    var generatedCount: Int = 0
    var output: String = ""
    var translatedSegments: [String] = []
}

@Observable
@MainActor
final class HunyuanMTService {
    enum LoadState: Equatable {
        case idle
        case loading(progress: Double)
        case ready
        case failed(String)
    }

    private(set) var loadState: LoadState = .idle
    private(set) var samples: [PerfSample] = []
    private(set) var peakMemoryMB: Double = 0

    private var container: ModelContainer?

    /// Source-of-truth model id on Hugging Face.
    /// `mlx-community/HY-MT1.5-1.8B-8bit` was converted from `tencent/HY-MT1.5-1.8B`
    /// using mlx-lm 0.29.1.
    static let modelID = "mlx-community/HY-MT1.5-1.8B-8bit"

    func loadIfNeeded() async {
        if case .ready = loadState { return }
        if case .loading = loadState { return }

        loadState = .loading(progress: 0)
        do {
            // Register Tencent's `hunyuan_v1_dense` model type before load.
            await HunyuanRegistration.registerIfNeeded()

            // Cap GPU cache so the OS doesn't terminate us under pressure.
            MLX.Memory.cacheLimit = 256 * 1024 * 1024

            let configuration = ModelConfiguration(id: Self.modelID)
            let progressHandler: @Sendable (Progress) -> Void = { [weak self] progress in
                let fraction = progress.fractionCompleted
                Task { @MainActor [weak self] in
                    self?.loadState = .loading(progress: fraction)
                }
            }

            print("[Hunyuan] Loading \(Self.modelID)…")
            let loaded = try await LLMModelFactory.shared.loadContainer(
                from: #hubDownloader(),
                using: #huggingFaceTokenizerLoader(),
                configuration: configuration,
                progressHandler: progressHandler
            )
            self.container = loaded
            self.loadState = .ready
            print("[Hunyuan] Model ready.")
        } catch {
            print("[Hunyuan] Load failed: \(error)")
            self.loadState = .failed(String(describing: error))
        }
    }

    /// Detect the source language locally so we can show a small label —
    /// the model itself does not require source-language input.
    nonisolated func detectSource(_ text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage else { return nil }
        return language.rawValue
    }

    struct StreamUpdate {
        var partialOutput: String
        var ttftMs: Double?
        var tokensPerSecond: Double
        var generatedTokens: Int
    }

    /// Streams a translation. Yields partial outputs and final perf metrics.
    ///
    /// HY-MT is trained on single-segment translation. Multi-line input
    /// (poetry, lyrics, paragraphs) often makes it stop after the first
    /// segment. We split on newlines and translate each non-empty line
    /// separately, then rejoin with the original line breaks — this is
    /// the same pattern Tencent's own demo uses.
    func translate(
        source: String,
        to target: Language
    ) -> AsyncThrowingStream<StreamUpdate, Error> {
        AsyncThrowingStream { continuation in
            let task = Task<Void, Never> {
                do {
                    guard let container = self.container else {
                        throw HunyuanMTError.modelLoadFailed("Model not loaded")
                    }

                    // Lower temperature than Tencent's "general use" recipe
                    // (0.7) — for pure translation we want determinism so the
                    // model doesn't occasionally leak the source language
                    // into the output. topK 20 from Tencent's recommendation.
                    let parameters = GenerateParameters(
                        temperature: 0.3,
                        topP: 0.6,
                        topK: 20,
                        repetitionPenalty: 1.05
                    )

                    // Preserve blank lines by keeping all components.
                    let segments = source.components(separatedBy: "\n")
                    let state = StreamState()
                    state.startedAt = Date()

                    for (index, raw) in segments.enumerated() {
                        try Task.checkCancellation()
                        let trimmed = raw.trimmingCharacters(in: .whitespaces)
                        if trimmed.isEmpty {
                            state.translatedSegments.append("")
                            let combined = state.translatedSegments.joined(separator: "\n")
                            let elapsed = Date().timeIntervalSince(state.firstTokenAt ?? state.startedAt)
                            let tps = elapsed > 0 ? Double(state.generatedCount) / elapsed : 0
                            let ttft = state.firstTokenAt.map { $0.timeIntervalSince(state.startedAt) * 1000 }
                            continuation.yield(StreamUpdate(
                                partialOutput: combined,
                                ttftMs: ttft,
                                tokensPerSecond: tps,
                                generatedTokens: state.generatedCount
                            ))
                            continue
                        }

                        let userText = PromptTemplate.userMessage(source: trimmed, target: target)
                        let segmentInfo: GenerateCompletionInfo? = try await container.perform { [continuation, state, userText] context in
                            let userInput = UserInput(chat: [.user(userText)])
                            let lmInput = try await context.processor.prepare(input: userInput)

                            let stream = try MLXLMCommon.generate(
                                input: lmInput,
                                parameters: parameters,
                                context: context
                            )

                            var segmentOutput = ""
                            var info: GenerateCompletionInfo?
                            for await event in stream {
                                try Task.checkCancellation()
                                switch event {
                                case .chunk(let text):
                                    if state.firstTokenAt == nil { state.firstTokenAt = Date() }
                                    state.generatedCount += 1
                                    segmentOutput += text
                                    let combined = (state.translatedSegments + [segmentOutput])
                                        .joined(separator: "\n")
                                    let elapsed = Date().timeIntervalSince(state.firstTokenAt ?? state.startedAt)
                                    let tps = elapsed > 0 ? Double(state.generatedCount) / elapsed : 0
                                    let ttft = state.firstTokenAt.map { $0.timeIntervalSince(state.startedAt) * 1000 }
                                    continuation.yield(StreamUpdate(
                                        partialOutput: combined,
                                        ttftMs: ttft,
                                        tokensPerSecond: tps,
                                        generatedTokens: state.generatedCount
                                    ))
                                case .info(let i):
                                    info = i
                                case .toolCall:
                                    continue
                                }
                            }
                            state.translatedSegments.append(segmentOutput)
                            return info
                        }

                        if let stopReason = segmentInfo?.stopReason {
                            print("[Hunyuan] Segment \(index + 1)/\(segments.count) stop=\(stopReason) tokens=\(segmentInfo?.generationTokenCount ?? 0)")
                        }
                    }

                    let ttft = state.firstTokenAt.map { $0.timeIntervalSince(state.startedAt) * 1000 } ?? 0
                    let totalElapsed = Date().timeIntervalSince(state.firstTokenAt ?? state.startedAt)
                    let finalTps = totalElapsed > 0 ? Double(state.generatedCount) / totalElapsed : 0

                    let sample = PerfSample(
                        timestamp: Date(),
                        ttftMs: ttft,
                        tokensPerSecond: finalTps,
                        generatedTokens: state.generatedCount
                    )
                    await MainActor.run {
                        self.samples.append(sample)
                        if self.samples.count > 50 {
                            self.samples.removeFirst(self.samples.count - 50)
                        }
                        self.peakMemoryMB = max(self.peakMemoryMB, DeviceInfo.residentMemoryMB)
                    }

                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: HunyuanMTError.cancelled)
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

private extension GenerateCompletionInfo {
    var tokensPerSecond: Double {
        guard generateTime > 0 else { return 0 }
        return Double(generationTokenCount) / generateTime
    }
}
