import Foundation

public struct PromptPreset: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var prompt: String

    public init(id: UUID = UUID(), title: String, prompt: String) {
        self.id = id
        self.title = title
        self.prompt = prompt
    }
}
