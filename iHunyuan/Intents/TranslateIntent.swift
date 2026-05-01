import AppIntents
import Foundation

struct LanguageEntity: AppEntity, Identifiable, Hashable, Sendable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Language"
    static let defaultQuery = LanguageQuery()

    let id: String
    let englishName: String
    let flag: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(flag) \(englishName)")
    }

    init(_ language: Language) {
        self.id = language.code
        self.englishName = language.englishName
        self.flag = language.flag
    }
}

struct LanguageQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [LanguageEntity] {
        identifiers.compactMap { Languages.byCode[$0] }.map(LanguageEntity.init)
    }

    func entities(matching string: String) async throws -> [LanguageEntity] {
        let q = string.lowercased()
        return Languages.all
            .filter {
                $0.englishName.lowercased().contains(q) ||
                $0.nativeName.lowercased().contains(q) ||
                $0.code.lowercased().contains(q)
            }
            .map(LanguageEntity.init)
    }

    func suggestedEntities() async throws -> [LanguageEntity] {
        Languages.all.prefix(10).map(LanguageEntity.init)
    }
}

struct TranslateTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Translate text"
    static let description = IntentDescription(
        "Translate text on-device with iHunyuan.",
        categoryName: "Translation",
        searchKeywords: ["translate", "language", "hunyuan"]
    )

    static let openAppWhenRun: Bool = true

    @Parameter(title: "Text", inputOptions: .init(multiline: true))
    var text: String

    @Parameter(title: "Target language")
    var target: LanguageEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Translate \(\.$text) to \(\.$target)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let code = target?.id ?? Languages.deviceDefault().code
        IntentRouter.shared.deliver(text: text, targetCode: code)
        return .result(dialog: "Translating to \(target?.englishName ?? Languages.deviceDefault().englishName)…")
    }
}

@MainActor
final class IntentRouter: ObservableObject {
    static let shared = IntentRouter()
    @Published var pending: (text: String, code: String)?
    func deliver(text: String, targetCode: String) {
        pending = (text, targetCode)
    }
}
