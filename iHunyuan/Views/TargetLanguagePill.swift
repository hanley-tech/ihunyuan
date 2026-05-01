import SwiftUI

struct TargetLanguagePill: View {
    let target: Language
    let detectedSource: Language?
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                if let source = detectedSource {
                    Text(source.flag)
                        .font(.system(size: 18))
                        .accessibilityLabel("Detected source: \(source.englishName)")
                    Image(systemName: "arrow.forward")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Text(target.flag)
                    .font(.system(size: 18))
                Text(target.englishName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(
            .regular.tint(GlassPalette.pillTint).interactive(),
            in: .capsule
        )
    }
}
