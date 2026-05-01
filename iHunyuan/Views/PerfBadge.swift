import SwiftUI

struct PerfBadge: View {
    let translation: Translation

    var body: some View {
        HStack(spacing: 8) {
            Label(formattedTokensPerSecond, systemImage: "speedometer")
                .font(.caption2.weight(.medium))
                .labelStyle(.titleAndIcon)

            Text("·")
                .foregroundStyle(.tertiary)

            Text("\(Int(translation.ttftMs)) ms first token")
                .font(.caption2)

            Text("·")
                .foregroundStyle(.tertiary)

            Text("\(translation.generatedTokens) tok")
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
        .padding(.top, 2)
    }

    private var formattedTokensPerSecond: String {
        let value = translation.tokensPerSecond
        if value >= 100 { return "\(Int(value)) tok/s" }
        return String(format: "%.1f tok/s", value)
    }
}

struct LiveStreamingBadge: View {
    let ttftMs: Double?
    let tokensPerSecond: Double
    let generatedTokens: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "speedometer")
                .symbolEffect(.pulse, options: .repeating)
            if generatedTokens == 0 {
                Text("Warming up…")
            } else {
                Text(String(format: "%.1f tok/s", tokensPerSecond))
                if let ttftMs {
                    Text("· \(Int(ttftMs)) ms")
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
    }
}
