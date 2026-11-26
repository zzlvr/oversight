/// What a skip button in the floating window does.
public enum SkipAction: Equatable {
    case turnPage(Int)
    /// Keep the current screen for a question later, without sending anything.
    case saveScreen
    case nothing
}

public func skipAction(forward: Bool, pageCount: Int) -> SkipAction {
    if pageCount > 1 { return .turnPage(forward ? 1 : -1) }
    return forward ? .nothing : .saveScreen
}
