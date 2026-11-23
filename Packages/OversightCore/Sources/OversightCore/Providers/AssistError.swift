import Foundation

public enum AssistError: Error, Equatable {
    case missingKey
    case noFrame
    case http(status: Int, message: String)
    case emptyAnswer
    case timeout
    case busy
}
