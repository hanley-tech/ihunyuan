import SwiftUI

struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var appVersion: String {
        let bundle = Bundle.main
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    madeByCard
                    creditsCard
                    privacyCard
                    Text(appVersion)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
                .padding(20)
            }
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.18), .clear, Color(red: 0.42, green: 0.78, blue: 1.0).opacity(0.12)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image("AppIconArtwork")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 110, height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 14, y: 8)
                .padding(.top, 4)
            Text("iHunyuan")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text("On-device translation across 38 languages.\nNo network needed after the first download.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private var madeByCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Made by", systemImage: "hammer.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                Image("HTAIProfile")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                    .overlay(
                        Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Hanley Leung")
                        .font(.title3.weight(.semibold))
                    Text("Hanley Talks AI · HTAI")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                linkChip(label: "YouTube", system: "play.rectangle.fill",
                         url: "https://www.youtube.com/@hanleytalksai")
                linkChip(label: "GitHub", system: "chevron.left.forwardslash.chevron.right",
                         url: "https://github.com/hanley-tech/ihunyuan")
            }
            .padding(.top, 2)
        }
        .padding(18)
        .iHGlass(cornerRadius: 24, tint: Color.accentColor.opacity(0.15))
    }

    private var creditsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Built on", systemImage: "shippingbox.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            creditRow(
                title: "Hunyuan-MT 1.5",
                detail: "Tencent · 1.8B translation model",
                url: "https://huggingface.co/tencent/HY-MT1.5-1.8B"
            )
            Divider().opacity(0.4)
            creditRow(
                title: "MLX Swift",
                detail: "Apple · on-device ML framework",
                url: "https://github.com/ml-explore/mlx-swift-lm"
            )
            Divider().opacity(0.4)
            creditRow(
                title: "Hugging Face Transformers",
                detail: "Tokenizers & weight downloads",
                url: "https://github.com/huggingface/swift-transformers"
            )
        }
        .padding(18)
        .iHGlass(cornerRadius: 24)
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Privacy", systemImage: "lock.shield.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Every translation runs on your device. The only network call is the one-time model download from Hugging Face. Your text never leaves your iPhone.")
                .font(.footnote)
                .foregroundStyle(.primary)
                .lineSpacing(2)
        }
        .padding(18)
        .iHGlass(cornerRadius: 24, tint: Color.green.opacity(0.10))
    }

    private func creditRow(title: String, detail: String, url: String) -> some View {
        Button {
            if let u = URL(string: url) { openURL(u) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func linkChip(label: String, system: String, url: String) -> some View {
        Button {
            if let u = URL(string: url) { openURL(u) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: system)
                Text(label)
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}
