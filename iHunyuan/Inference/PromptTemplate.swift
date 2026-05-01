import Foundation

enum PromptTemplate {
    /// HY-MT prompt format from the model card.
    /// Chinese targets get the Chinese instruction, everything else gets the English one.
    static func userMessage(source: String, target: Language) -> String {
        // HY-MT is trained on single-segment translation — blank lines act
        // as paragraph separators in its training data and the model often
        // stops after the first segment. Collapse runs of newlines so the
        // whole input is treated as one segment.
        let collapsed = source.replacingOccurrences(
            of: "\n[\n\\s]*\n",
            with: "\n",
            options: .regularExpression
        )
        let trimmed = collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
        switch target.code {
        case "zh", "zh-Hant", "yue":
            let zhTarget: String
            switch target.code {
            case "zh-Hant": zhTarget = "繁體中文"
            case "yue":     zhTarget = "粵語"
            default:        zhTarget = "中文"
            }
            return "将以下文本翻译为\(zhTarget)，注意只需要输出翻译后的结果，不要额外解释：\n\n\(trimmed)"
        default:
            return "Translate the following segment into \(target.promptName), without additional explanation.\n\n\(trimmed)"
        }
    }
}
