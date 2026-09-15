import Foundation

public struct DeterministicRefiner: TextRefining {
    public init() {}

    public func refine(
        text input: String,
        dictionary: [DictionaryEntry],
        snippets: [Snippet],
        developerMode: Bool,
        mode: DictationMode
    ) -> RefinementResult {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        var changes: [RefinementChange] = []

        if let snippet = exactSnippet(for: text, snippets: snippets) {
            return RefinementResult(text: snippet.expansion, changes: [.init(kind: .snippet)])
        }

        let explicitSnippetPattern = #"(?i)^insert snippet\s+(.+)$"#
        if let match = firstCapture(in: text, pattern: explicitSnippetPattern),
           let snippet = uniqueSnippet(named: match, snippets: snippets) {
            return RefinementResult(text: snippet.expansion, changes: [.init(kind: .snippet)])
        }

        let withoutFillers = removeFillers(from: text)
        if withoutFillers != text {
            text = withoutFillers
            changes.append(.init(kind: .filler))
        }

        for entry in dictionary.filter(\.isEnabled).sorted(by: { $0.spokenForm.count > $1.spokenForm.count }) {
            let pattern = "(?i)(?<![\\p{L}\\p{N}_])\(NSRegularExpression.escapedPattern(for: entry.spokenForm))(?![\\p{L}\\p{N}_])"
            let updated = replace(text, pattern: pattern, with: escapedTemplate(entry.writtenForm))
            if updated != text {
                text = updated
                changes.append(.init(kind: .correction))
            }
        }

        if developerMode {
            let updated = developerFormat(text)
            if updated != text {
                text = updated
                changes.append(.init(kind: .developerToken))
            }
        }

        // Run de-duplication after spoken developer tokens are converted. This
        // preserves intentional pairs such as “dash dash” -> “--”.
        let withoutRepeatedPhrases = collapseRepeatedPhrases(in: text)
        let withoutRepeats = replace(withoutRepeatedPhrases, pattern: #"(?i)\b([\p{L}\p{N}_'-]+)(?:[\s,]+\1\b)+"#, with: "$1")
        if withoutRepeats != text {
            text = withoutRepeats
            changes.append(.init(kind: .repetition))
        }

        let punctuated = punctuationFormat(text)
        if punctuated != text {
            text = punctuated
            changes.append(.init(kind: .punctuation))
        }

        if mode == .prompt {
            let structured = structurePrompt(text)
            if structured != text {
                text = structured
                changes.append(.init(kind: .promptStructure))
            }
        }

        return RefinementResult(text: text, changes: changes)
    }

    private func removeFillers(from input: String) -> String {
        var text = replace(
            input,
            pattern: #"(?i)(?<![\p{L}\p{N}_])(um+|uh+|erm+|hmm+|mm[ -]?hmm|you know)(?![\p{L}\p{N}_])[,;:]?\s*"#,
            with: ""
        )
        // These words are removed only as a leading warm-up cluster. “Like”
        // elsewhere remains untouched because it may express comparison.
        text = replace(text, pattern: #"(?i)^(?:(?:yeah|okay|ok|so|like)\b[, ]*)+"#, with: "")
        return text
    }

    private func collapseRepeatedPhrases(in input: String) -> String {
        var text = input
        let pattern = #"(?i)\b((?:[\p{L}\p{N}_'-]+\s+){1,5}[\p{L}\p{N}_'-]+)(?:[\s,]+\1\b)+"#
        for _ in 0..<4 {
            let updated = replace(text, pattern: pattern, with: "$1")
            guard updated != text else { break }
            text = updated
        }
        return text
    }

    private enum PromptSection: CaseIterable {
        case goal
        case context
        case requirements
        case doneWhen

        var title: String {
            switch self {
            case .goal: "Goal"
            case .context: "Context"
            case .requirements: "Requirements"
            case .doneWhen: "Done when"
            }
        }
    }

    private func structurePrompt(_ input: String) -> String {
        var prepared = replace(
            input,
            pattern: #"(?i)\s+(?=(?:for context|context(?:\s+is|:)|make sure|requirements?(?:\s+are|\s+include|:)|done when|success means|acceptance criteria)\b)"#,
            with: "\n"
        )
        prepared = replace(prepared, pattern: #"([.!?]+)(?:\s+|$)"#, with: "$1\n")

        var buckets: [PromptSection: [String]] = [:]
        for rawClause in prepared.components(separatedBy: .newlines) {
            var clause = rawClause.trimmingCharacters(in: .whitespacesAndNewlines)
            clause = replace(clause, pattern: #"(?i)^(?:and|but|so)\s+"#, with: "")
            guard !clause.isEmpty else { continue }

            let lowered = clause.lowercased()
            let section: PromptSection
            if lowered.range(of: #"^(done when|success means|acceptance criteria)\b"#, options: .regularExpression) != nil {
                section = .doneWhen
                clause = stripPromptPrefix(from: clause, pattern: #"(?i)^(?:done when|success means|acceptance criteria(?: are|:)?)(?:\s+|:\s*)"#)
            } else if lowered.range(of: #"^(for context|context\b|currently\b|right now\b|because\b)"#, options: .regularExpression) != nil {
                section = .context
                clause = stripPromptPrefix(from: clause, pattern: #"(?i)^(?:for context|context(?: is|:)?)(?:\s+|:\s*)"#)
            } else if lowered.range(of: #"\b(make sure|requirements?\b|must\b|need(?:s)? to\b|should\b|do not\b|don't\b|without\b)"#, options: .regularExpression) != nil {
                section = .requirements
                clause = stripPromptPrefix(from: clause, pattern: #"(?i)^(?:make sure(?: that)?|requirements?(?: are| include|:)?)(?:\s+|:\s*)"#)
            } else {
                section = .goal
                clause = stripPromptPrefix(from: clause, pattern: #"(?i)^(?:goal(?: is|:)?|objective(?: is|:)?|i want (?:you )?to|can you|please)(?:\s+|:\s*)"#)
            }

            clause = clause.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clause.isEmpty else { continue }
            if let first = clause.first, first.isLetter, first.isLowercase {
                clause.replaceSubrange(clause.startIndex...clause.startIndex, with: String(first).uppercased())
            }
            buckets[section, default: []].append(clause)
        }

        let rendered = PromptSection.allCases.compactMap { section -> String? in
            guard let clauses = buckets[section], !clauses.isEmpty else { return nil }
            let body: String
            if section == .requirements || section == .doneWhen {
                body = clauses.map { "- \($0)" }.joined(separator: "\n")
            } else {
                body = clauses.joined(separator: " ")
            }
            return "\(section.title):\n\(body)"
        }
        return rendered.isEmpty ? input : rendered.joined(separator: "\n\n")
    }

    private func stripPromptPrefix(from input: String, pattern: String) -> String {
        replace(input, pattern: pattern, with: "")
    }

    private func exactSnippet(for text: String, snippets: [Snippet]) -> Snippet? {
        let normalized = normalizeTrigger(text)
        let matches = snippets.filter { $0.isEnabled && normalizeTrigger($0.trigger) == normalized }
        return matches.count == 1 ? matches[0] : nil
    }

    private func uniqueSnippet(named name: String, snippets: [Snippet]) -> Snippet? {
        let normalized = normalizeTrigger(name)
        let matches = snippets.filter {
            $0.isEnabled && (normalizeTrigger($0.trigger) == normalized || normalizeTrigger($0.name) == normalized)
        }
        return matches.count == 1 ? matches[0] : nil
    }

    private func normalizeTrigger(_ value: String) -> String {
        value.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private func developerFormat(_ input: String) -> String {
        var text = input
        let fixed: [(String, String)] = [
            (#"(?i)\bdot env\b"#, ".env"),
            (#"(?i)\bdash dash\s+"#, "--"),
            (#"(?i)\bat package dot json\b"#, "@package.json"),
            (#"(?i)\bopen paren\b"#, "("),
            (#"(?i)\bclose paren\b"#, ")"),
            (#"(?i)\bopen bracket\b"#, "["),
            (#"(?i)\bclose bracket\b"#, "]"),
            (#"(?i)\bnew code block swift\b"#, "```swift\n"),
            (#"(?i)\bend code block\b"#, "\n```"),
        ]
        for (pattern, replacement) in fixed {
            text = replace(text, pattern: pattern, with: replacement)
        }

        let caseCommands: [(String, ([String]) -> String)] = [
            ("camel case", { words in words.first!.lowercased() + words.dropFirst().map(\.capitalized).joined() }),
            ("pascal case", { $0.map(\.capitalized).joined() }),
            ("snake case", { $0.map { $0.lowercased() }.joined(separator: "_") }),
            ("screaming snake case", { $0.map { $0.uppercased() }.joined(separator: "_") }),
            ("kebab case", { $0.map { $0.lowercased() }.joined(separator: "-") }),
        ]
        for (command, formatter) in caseCommands {
            let pattern = "(?i)\\b\(command) ([a-zA-Z0-9]+(?: [a-zA-Z0-9]+){0,3})(?=[,.;!?]|$)"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            while let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let range = Range(match.range(at: 1), in: text) {
                let words = text[range].split(separator: " ").map(String.init)
                guard !words.isEmpty else { break }
                let whole = Range(match.range, in: text)!
                text.replaceSubrange(whole, with: formatter(words))
            }
        }
        return text
    }

    private func punctuationFormat(_ input: String) -> String {
        var text = input
        let commands: [(String, String)] = [
            (#"(?i)\bnew paragraph\b"#, "\n\n"),
            (#"(?i)\bnew line\b"#, "\n"),
            (#"(?i)\bcomma\b"#, ","),
            (#"(?i)\bperiod\b"#, "."),
            (#"(?i)\bquestion mark\b"#, "?"),
            (#"(?i)\bcolon\b"#, ":"),
            (#"(?i)\bsemicolon\b"#, ";"),
        ]
        for (pattern, replacement) in commands {
            text = replace(text, pattern: pattern, with: replacement)
        }
        text = replace(text, pattern: #"[ \t]+([,;:?!]|\.(?![\p{L}\p{N}]))"#, with: "$1")
        // Only separate punctuation that follows a word. A leading dot in a
        // developer token such as `.env` must remain attached.
        text = replace(text, pattern: #"(?<=[\p{L}\p{N}])([,.;:?!])(?=[\p{L}\p{N}])"#, with: "$1 ")
        text = replace(text, pattern: #"[ \t]{2,}"#, with: " ")
        text = replace(text, pattern: #"\n[ \t]+"#, with: "\n")

        if let first = text.first, first.isLetter, first.isLowercase {
            text.replaceSubrange(text.startIndex...text.startIndex, with: String(first).uppercased())
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func replace(_ input: String, pattern: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return input }
        let range = NSRange(input.startIndex..., in: input)
        return regex.stringByReplacingMatches(in: input, range: range, withTemplate: replacement)
    }

    private func firstCapture(in input: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)),
              let range = Range(match.range(at: 1), in: input) else { return nil }
        return String(input[range])
    }

    private func escapedTemplate(_ value: String) -> String {
        value.replacingOccurrences(of: "$", with: "\\$")
    }
}
