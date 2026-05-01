import SwiftUI

struct ComposerView: View {
    @Binding var text: String
    var isBusy: Bool
    var onSubmit: () -> Void
    var onCancel: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Type or paste text…", text: $text, axis: .vertical)
                .lineLimit(1...6)
                .focused($focused)
                .submitLabel(.send)
                .onSubmit {
                    if !isBusy { onSubmit() }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))

            sendButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var sendButton: some View {
        Button {
            if isBusy { onCancel() } else { onSubmit() }
        } label: {
            Image(systemName: isBusy ? "stop.fill" : "arrow.up")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
        }
        .glassEffect(
            .regular.tint(isBusy ? Color.red.opacity(0.6) : Color.accentColor).interactive(),
            in: .circle
        )
        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isBusy)
        .contentTransition(.symbolEffect(.replace))
    }
}
