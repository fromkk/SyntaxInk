#if targetEnvironment(macCatalyst)
public struct SwiftToken: Sendable {
    public let text: String
    public let styleKind: SwiftTheme.StyleKind
}
#endif
