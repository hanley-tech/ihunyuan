import SwiftUI

struct SourceBubble: View {
    let text: String
    let detectedSource: Language?

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

            if let source = detectedSource {
                Text("\(source.flag) \(source.englishName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(
            .regular.tint(GlassPalette.bubbleSourceTint),
            in: .rect(cornerRadii: .init(topLeading: 22, bottomLeading: 22, bottomTrailing: 8, topTrailing: 22))
        )
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, 60)
    }
}

struct TargetBubble: View {
    let translation: Translation
    let isStreaming: Bool
    var onCopy: () -> Void
    var onShare: () -> Void
    var onRetranslate: () -> Void
    var onShowStats: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(translation.targetLanguage.flag)
                    .font(.caption)
                Text(translation.targetLanguage.englishName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if isStreaming {
                    StreamingDots()
                }
            }

            Text(translation.targetText.isEmpty && !isStreaming ? "—" : translation.targetText)
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

            if let error = translation.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if !isStreaming && translation.errorMessage == nil {
                PerfBadge(translation: translation)
                    .onTapGesture { onShowStats() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(
            .regular.tint(GlassPalette.bubbleTargetTint),
            in: .rect(cornerRadii: .init(topLeading: 22, bottomLeading: 8, bottomTrailing: 22, topTrailing: 22))
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 60)
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc", action: onCopy)
                .disabled(translation.targetText.isEmpty)
            Button("Share", systemImage: "square.and.arrow.up", action: onShare)
                .disabled(translation.targetText.isEmpty)
            Divider()
            Button("Re-translate", systemImage: "arrow.clockwise", action: onRetranslate)
            Button("Show speed", systemImage: "speedometer", action: onShowStats)
        }
    }
}

private struct StreamingDots: View {
    @State private var phase: Int = 0
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(.secondary)
                    .frame(width: 4, height: 4)
                    .opacity(phase == i ? 1 : 0.3)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(280))
                phase = (phase + 1) % 3
            }
        }
    }
}
