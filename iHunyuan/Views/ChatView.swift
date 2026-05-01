import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HunyuanMTService.self) private var service
    @Environment(RecentLanguages.self) private var recents

    @Query(sort: \Translation.createdAt, order: .forward)
    private var translations: [Translation]

    @State private var target: Language = Languages.deviceDefault()
    @State private var draft: String = ""
    @State private var showLanguagePicker = false
    @State private var showStats = false
    @State private var showAbout = false
    @State private var streamTask: Task<Void, Never>?
    @State private var liveTtft: Double?
    @State private var liveTps: Double = 0
    @State private var liveTokens: Int = 0
    @Namespace private var glassNS

    var body: some View {
        ZStack(alignment: .top) {
            background

            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                ScrollViewReader { scroller in
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            if translations.isEmpty { emptyState }
                            ForEach(translations) { translation in
                                bubblePair(translation)
                                    .id(translation.id)
                            }
                            if streamTask != nil {
                                LiveStreamingBadge(
                                    ttftMs: liveTtft,
                                    tokensPerSecond: liveTps,
                                    generatedTokens: liveTokens
                                )
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 4)
                            }
                            Color.clear.frame(height: 80).id("bottom")
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: translations.count) { _, _ in
                        withAnimation(.smooth) { scroller.scrollTo("bottom") }
                    }
                    .onChange(of: liveTokens) { _, _ in
                        withAnimation(.smooth) { scroller.scrollTo("bottom") }
                    }
                }

                ComposerView(
                    text: $draft,
                    isBusy: streamTask != nil,
                    onSubmit: send,
                    onCancel: cancel
                )
                .padding(.bottom, 4)
            }

            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 10) {
                    TargetLanguagePill(
                        target: target,
                        detectedSource: detectedSource,
                        onTap: { showLanguagePicker = true }
                    )
                    .glassEffectID("pill", in: glassNS)

                    Spacer()

                    Menu {
                        Button("Performance", systemImage: "speedometer") { showStats = true }
                        Button("About iHunyuan", systemImage: "info.circle") { showAbout = true }
                        Divider()
                        Button("Clear history", systemImage: "trash", role: .destructive, action: clearAll)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 38, height: 38)
                    }
                    .glassEffect(.regular.interactive(), in: .circle)
                    .glassEffectID("menu", in: glassNS)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerSheet(
                selection: $target,
                recents: recents.languages,
                onPick: { picked in
                    target = picked
                    recents.bump(picked)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showStats) {
            PerfStatsSheet(
                samples: service.samples,
                peakMemoryMB: service.peakMemoryMB,
                modelName: HunyuanMTService.modelID
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAbout) {
            AboutSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            if recents.languages.isEmpty {
                recents.bump(target)
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.20),
                Color.clear,
                Color(red: 0.42, green: 0.78, blue: 1.0).opacity(0.15)
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "character.bubble")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
            Text("Translate offline in 38 languages")
                .font(.title3.weight(.semibold))
            Text("Type or paste anything below — it stays on your phone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }

    private var detectedSource: Language? {
        guard let last = translations.last else { return nil }
        return last.detectedSourceLanguage
    }

    private func bubblePair(_ translation: Translation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SourceBubble(
                text: translation.sourceText,
                detectedSource: translation.detectedSourceLanguage
            )
            TargetBubble(
                translation: translation,
                isStreaming: translation.isStreaming,
                onCopy: { UIPasteboard.general.string = translation.targetText },
                onShare: { share(translation.targetText) },
                onRetranslate: { retranslate(translation) },
                onShowStats: { showStats = true }
            )
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, streamTask == nil else { return }
        draft = ""

        let detected = service.detectSource(text)
        let translation = Translation(
            sourceText: text,
            targetCode: target.code,
            detectedSourceCode: detected
        )
        modelContext.insert(translation)
        try? modelContext.save()
        recents.bump(target)

        runStream(for: translation)
    }

    private func retranslate(_ translation: Translation) {
        guard streamTask == nil else { return }
        translation.targetText = ""
        translation.errorMessage = nil
        translation.isStreaming = true
        translation.targetCode = target.code
        translation.tokensPerSecond = 0
        translation.ttftMs = 0
        translation.generatedTokens = 0
        try? modelContext.save()
        runStream(for: translation)
    }

    private func runStream(for translation: Translation) {
        liveTtft = nil
        liveTps = 0
        liveTokens = 0

        let target = self.target
        streamTask = Task {
            defer {
                Task { @MainActor in
                    self.streamTask = nil
                }
            }
            do {
                for try await update in service.translate(source: translation.sourceText, to: target) {
                    translation.targetText = update.partialOutput
                    if let ttft = update.ttftMs { translation.ttftMs = ttft; liveTtft = ttft }
                    translation.tokensPerSecond = update.tokensPerSecond
                    translation.generatedTokens = update.generatedTokens
                    liveTps = update.tokensPerSecond
                    liveTokens = update.generatedTokens
                }
                translation.isStreaming = false
                try? modelContext.save()
            } catch {
                translation.isStreaming = false
                translation.errorMessage = error.localizedDescription
                try? modelContext.save()
            }
        }
    }

    private func cancel() {
        streamTask?.cancel()
        streamTask = nil
    }

    private func clearAll() {
        for t in translations { modelContext.delete(t) }
        try? modelContext.save()
    }

    private func share(_ text: String) {
        guard !text.isEmpty else { return }
        let activity = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.rootViewController?
            .present(activity, animated: true)
    }
}
