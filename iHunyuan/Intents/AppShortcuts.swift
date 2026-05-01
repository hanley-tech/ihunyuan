import AppIntents

struct iHunyuanShortcuts: AppShortcutsProvider {
    static let shortcutTileColor: ShortcutTileColor = .lightBlue

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TranslateTextIntent(),
            phrases: [
                "Translate with \(.applicationName)",
                "Use \(.applicationName) to translate",
                "Translate to \(\.$target) with \(.applicationName)"
            ],
            shortTitle: "Translate",
            systemImageName: "character.bubble"
        )
    }
}
