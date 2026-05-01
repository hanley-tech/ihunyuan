import SwiftUI

struct ModelLoadingView: View {
    let progress: Double
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(.tertiary.opacity(0.25), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: max(0.02, progress))
                    .stroke(
                        Color.accentColor.gradient,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth(duration: 0.4), value: progress)
                Image(systemName: "globe")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.tint)
                    .symbolEffect(.pulse, options: .repeating)
            }
            .frame(width: 130, height: 130)

            VStack(spacing: 6) {
                Text("Preparing your translator")
                    .font(.title3.weight(.semibold))
                Text(progress > 0
                     ? "\(Int(progress * 100))% downloaded"
                     : "Connecting to Hugging Face…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            Text("First-time download is about 1.9 GB.\nAfter this, everything runs on-device — no internet needed.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let onRetry {
                Button("Retry", systemImage: "arrow.clockwise", action: onRetry)
                    .padding(.top, 6)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.18), .clear, Color.accentColor.opacity(0.08)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}
