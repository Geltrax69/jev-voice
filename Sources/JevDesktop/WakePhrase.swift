import Foundation

/// A wake phrase must lead the utterance. Preserve the original command text.
enum WakePhrase {
    static func command(in utterance: String, after phrase: String) -> String? {
        func words(_ text: String) -> [(String, Range<String.Index>)] {
            var result: [(String, Range<String.Index>)] = []
            var start: String.Index?
            for index in text.indices {
                if text[index].isLetter || text[index].isNumber {
                    if start == nil { start = index }
                } else if let beginning = start {
                    result.append((String(text[beginning..<index]).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")), beginning..<index))
                    start = nil
                }
            }
            if let start {
                result.append((String(text[start...]).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")), start..<text.endIndex))
            }
            return result
        }
        let expected = words(phrase)
        let spoken = words(utterance)
        guard !expected.isEmpty, spoken.count >= expected.count,
              zip(expected, spoken).allSatisfy({ $0.0.0 == $0.1.0 }) else { return nil }
        let end = spoken[expected.count - 1].1.upperBound
        return String(utterance[end...].drop(while: { $0.isWhitespace || ",.:;!?—–-".contains($0) })).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
