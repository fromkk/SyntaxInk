#if targetEnvironment(macCatalyst)
import Foundation
import SyntaxInk

public struct SwiftTheme: Theme {
    public typealias Token = SwiftToken

    public var configuration: Configuration

    public init(_ styleResolver: @escaping @Sendable (StyleKind) -> SyntaxStyle) {
        self.configuration = Configuration(styleResolver: styleResolver)
    }

    public func attributes(for token: SwiftToken) -> AttributedString {
        AttributedString(token.text).applying(configuration.style(for: token.styleKind))
    }
}

extension SwiftTheme {
    public enum StyleKind: Sendable {
        case plainText, keywords, comments, documentationMarkup, string, numbers
        case preprocessorStatements, typeDeclarations, otherDeclarations, otherClassNames
        case otherFunctionAndMethodNames, otherTypeNames, otherPropertiesAndGlobals
    }

    public struct Configuration: Sendable {
        public var styleResolver: @Sendable (StyleKind) -> SyntaxStyle
        func style(for kind: StyleKind) -> SyntaxStyle { styleResolver(kind) }
    }
}
#endif
