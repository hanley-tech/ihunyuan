import SwiftUI
import SwiftData

@main
struct iHunyuanApp: App {
    @State private var service = HunyuanMTService()
    @State private var recents = RecentLanguages()
    @StateObject private var router = IntentRouter.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(service)
                .environment(recents)
                .environmentObject(router)
                .task { await service.loadIfNeeded() }
                .tint(.accentColor)
        }
        .modelContainer(for: Translation.self)
    }
}

private struct RootView: View {
    @Environment(HunyuanMTService.self) private var service

    var body: some View {
        switch service.loadState {
        case .ready:
            ChatView()
        case .loading(let progress):
            ModelLoadingView(progress: progress, onRetry: nil)
        case .failed(let message):
            FailureView(message: message)
        case .idle:
            ModelLoadingView(progress: 0, onRetry: nil)
        }
    }
}

private struct FailureView: View {
    let message: String
    @Environment(HunyuanMTService.self) private var service

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("Couldn't prepare the translator")
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try again") {
                Task { await service.loadIfNeeded() }
            }
            .buttonStyle(.borderedProminent)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}
