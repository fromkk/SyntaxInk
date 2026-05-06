#if targetEnvironment(macCatalyst)
import Foundation
import SyntaxInk

public struct SwiftGrammar: Grammar {
    public typealias Token = SwiftToken

    public init() {}

    public func tokenize(_ code: String) -> [SwiftToken] {
        Tokenizer(code: code).tokenize()
    }
}

private struct Tokenizer {
    let code: String

    private static let keywords: Set<String> = [
        "Any", "as", "associatedtype", "actor", "async", "await",
        "break", "borrowing", "case", "catch", "class", "consuming", "continue", "convenience",
        "default", "defer", "deinit", "didSet", "distributed", "do", "dynamic",
        "else", "enum", "extension",
        "fallthrough", "false", "fileprivate", "final", "for", "func",
        "get", "guard",
        "if", "import", "in", "indirect", "infix", "init", "inout", "internal", "is", "isolated",
        "lazy", "let", "left",
        "mutating", "nil", "nonisolated", "nonmutating",
        "open", "operator", "optional", "override",
        "package", "postfix", "precedencegroup", "prefix", "private", "protocol", "public",
        "repeat", "required", "rethrows", "return", "right",
        "self", "Self", "set", "some", "static", "struct", "subscript", "super", "switch",
        "throw", "throws", "true", "try", "typealias",
        "unowned", "var", "weak", "where", "while", "willSet",
    ]

    private static let preprocessorKeywords: Set<String> = [
        "#if", "#else", "#elseif", "#endif", "#available", "#unavailable",
        "#warning", "#error", "#sourceLocation", "#selector", "#keyPath",
        "#column", "#dsohandle", "#file", "#filePath", "#fileID", "#function", "#line",
        "#isolation", "#expect",
    ]

    func tokenize() -> [SwiftToken] {
        var tokens: [SwiftToken] = []
        var i = code.startIndex
        while i < code.endIndex {
            tokens.append(next(from: &i))
        }
        return tokens
    }

    private func next(from i: inout String.Index) -> SwiftToken {
        if let t = docBlockComment(from: &i) { return t }
        if let t = docLineComment(from: &i) { return t }
        if let t = blockComment(from: &i) { return t }
        if let t = lineComment(from: &i) { return t }
        if let t = multilineString(from: &i) { return t }
        if let t = string(from: &i) { return t }
        if let t = preprocessor(from: &i) { return t }
        if let t = number(from: &i) { return t }
        if let t = identifier(from: &i) { return t }
        return single(from: &i, kind: .plainText)
    }

    private func docBlockComment(from i: inout String.Index) -> SwiftToken? {
        guard code[i...].hasPrefix("/**"), !code[i...].hasPrefix("/***") else { return nil }
        return until(from: &i, end: "*/", kind: .documentationMarkup)
    }

    private func docLineComment(from i: inout String.Index) -> SwiftToken? {
        guard code[i...].hasPrefix("///") else { return nil }
        return toEOL(from: &i, kind: .documentationMarkup)
    }

    private func blockComment(from i: inout String.Index) -> SwiftToken? {
        guard code[i...].hasPrefix("/*") else { return nil }
        return until(from: &i, end: "*/", kind: .comments)
    }

    private func lineComment(from i: inout String.Index) -> SwiftToken? {
        guard code[i...].hasPrefix("//") else { return nil }
        return toEOL(from: &i, kind: .comments)
    }

    private func multilineString(from i: inout String.Index) -> SwiftToken? {
        guard code[i...].hasPrefix("\"\"\"") else { return nil }
        var j = code.index(i, offsetBy: 3)
        while j < code.endIndex {
            if code[j...].hasPrefix("\"\"\"") {
                let end = code.index(j, offsetBy: 3)
                defer { i = end }
                return SwiftToken(text: String(code[i..<end]), styleKind: .string)
            }
            code.formIndex(after: &j)
        }
        defer { i = code.endIndex }
        return SwiftToken(text: String(code[i...]), styleKind: .string)
    }

    private func string(from i: inout String.Index) -> SwiftToken? {
        guard code[i] == "\"" else { return nil }
        var j = code.index(after: i)
        while j < code.endIndex {
            let c = code[j]
            if c == "\\" { code.formIndex(after: &j); if j < code.endIndex { code.formIndex(after: &j) } }
            else if c == "\"" { code.formIndex(after: &j); defer { i = j }; return SwiftToken(text: String(code[i..<j]), styleKind: .string) }
            else if c == "\n" { break }
            else { code.formIndex(after: &j) }
        }
        defer { i = j }
        return SwiftToken(text: String(code[i..<j]), styleKind: .string)
    }

    private func preprocessor(from i: inout String.Index) -> SwiftToken? {
        guard code[i] == "#" else { return nil }
        var j = i
        code.formIndex(after: &j)
        while j < code.endIndex && (code[j].isLetter || code[j] == "_") { code.formIndex(after: &j) }
        let word = String(code[i..<j])
        guard Self.preprocessorKeywords.contains(word) else { return nil }
        defer { i = j }
        return SwiftToken(text: word, styleKind: .preprocessorStatements)
    }

    private func number(from i: inout String.Index) -> SwiftToken? {
        guard code[i].isNumber else { return nil }
        var j = i
        if code[j...].hasPrefix("0x") { code.formIndex(&j, offsetBy: 2); while j < code.endIndex && code[j].isHexDigit { code.formIndex(after: &j) } }
        else if code[j...].hasPrefix("0b") { code.formIndex(&j, offsetBy: 2); while j < code.endIndex && (code[j] == "0" || code[j] == "1") { code.formIndex(after: &j) } }
        else {
            while j < code.endIndex && (code[j].isNumber || code[j] == "_") { code.formIndex(after: &j) }
            if j < code.endIndex && code[j] == ".", code.index(after: j) < code.endIndex && code[code.index(after: j)].isNumber {
                code.formIndex(after: &j)
                while j < code.endIndex && (code[j].isNumber || code[j] == "_") { code.formIndex(after: &j) }
            }
            if j < code.endIndex && (code[j] == "e" || code[j] == "E") {
                code.formIndex(after: &j)
                if j < code.endIndex && (code[j] == "+" || code[j] == "-") { code.formIndex(after: &j) }
                while j < code.endIndex && code[j].isNumber { code.formIndex(after: &j) }
            }
        }
        guard j > i else { return nil }
        defer { i = j }
        return SwiftToken(text: String(code[i..<j]), styleKind: .numbers)
    }

    private func identifier(from i: inout String.Index) -> SwiftToken? {
        guard code[i].isLetter || code[i] == "_" else { return nil }
        var j = i
        while j < code.endIndex && (code[j].isLetter || code[j].isNumber || code[j] == "_") { code.formIndex(after: &j) }
        let word = String(code[i..<j])
        defer { i = j }
        if Self.keywords.contains(word) { return SwiftToken(text: word, styleKind: .keywords) }
        if let first = word.first, first.isUppercase { return SwiftToken(text: word, styleKind: .otherClassNames) }
        return SwiftToken(text: word, styleKind: .plainText)
    }

    private func until(from i: inout String.Index, end: String, kind: SwiftTheme.StyleKind) -> SwiftToken {
        var j = i
        while j < code.endIndex {
            if code[j...].hasPrefix(end) { code.formIndex(&j, offsetBy: end.count); defer { i = j }; return SwiftToken(text: String(code[i..<j]), styleKind: kind) }
            code.formIndex(after: &j)
        }
        defer { i = code.endIndex }
        return SwiftToken(text: String(code[i...]), styleKind: kind)
    }

    private func toEOL(from i: inout String.Index, kind: SwiftTheme.StyleKind) -> SwiftToken {
        var j = i
        while j < code.endIndex && code[j] != "\n" { code.formIndex(after: &j) }
        defer { i = j }
        return SwiftToken(text: String(code[i..<j]), styleKind: kind)
    }

    private func single(from i: inout String.Index, kind: SwiftTheme.StyleKind) -> SwiftToken {
        let t = SwiftToken(text: String(code[i]), styleKind: kind)
        code.formIndex(after: &i)
        return t
    }
}
#endif
