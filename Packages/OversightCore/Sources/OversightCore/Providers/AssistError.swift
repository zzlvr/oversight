import Foundation

public enum AssistError: Error, Equatable {
    case missingKey
    case noFrame
    case http(status: Int, message: String)
    case emptyAnswer
    case timeout
    case busy
    case invalidKey
    case invalidModel

    /// English text shown to the user; also the localization key.
    public var messageKey: String {
        switch self {
        case .missingKey: return "Add your API key in Settings"
        case .noFrame: return "No screen captured yet. Start the broadcast"
        case .timeout: return "The request timed out. Try again"
        case .emptyAnswer: return "The AI returned an empty answer"
        case .busy: return "Still working on the last question"
        case .invalidKey: return "Invalid API key"
        case .invalidModel: return "Invalid model name"
        case .http(let status, _):
            if status == 401 || status == 403 { return "Invalid API key" }
            if status == 0 { return "No network connection" }
            return "The AI service returned an error"
        }
    }
}
