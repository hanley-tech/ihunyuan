import SwiftUI

struct LanguagePickerSheet: View {
    @Binding var selection: Language
    let recents: [Language]
    var onPick: (Language) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [Language] {
        guard !query.isEmpty else { return Languages.all }
        let q = query.lowercased()
        return Languages.all.filter {
            $0.englishName.lowercased().contains(q) ||
            $0.nativeName.lowercased().contains(q) ||
            $0.code.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !recents.isEmpty && query.isEmpty {
                    Section {
                        ForEach(recents) { language in
                            row(language)
                        }
                    } header: {
                        Text("Recent")
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(filtered) { language in
                        row(language)
                    }
                } header: {
                    Text(query.isEmpty ? "All languages" : "Results")
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.12), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .searchable(text: $query, prompt: "Search 38 languages")
            .navigationTitle("Translate to")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func row(_ language: Language) -> some View {
        Button {
            selection = language
            onPick(language)
            dismiss()
        } label: {
            HStack(spacing: 14) {
                Text(language.flag)
                    .font(.system(size: 26))
                VStack(alignment: .leading, spacing: 1) {
                    Text(language.englishName)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(language.nativeName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if selection.code == language.code {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
