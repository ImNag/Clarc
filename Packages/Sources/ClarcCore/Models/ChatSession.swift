import Foundation

public struct ChatSession: Identifiable, Codable, Sendable {
    public let id: String
    public let projectId: UUID
    public var title: String
    public var messages: [ChatMessage]
    public let createdAt: Date
    public var updatedAt: Date
    public var isPinned: Bool
    public var model: String?

    public init(
        id: String,
        projectId: UUID,
        title: String = "New Session",
        messages: [ChatMessage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isPinned: Bool = false,
        model: String? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
        self.model = model
    }

    private enum CodingKeys: String, CodingKey {
        case id, projectId, title, messages, createdAt, updatedAt, isPinned, model
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        projectId = try container.decode(UUID.self, forKey: .projectId)
        title = try container.decode(String.self, forKey: .title)
        messages = try container.decode([ChatMessage].self, forKey: .messages)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        model = try container.decodeIfPresent(String.self, forKey: .model)
    }

    public struct Summary: Identifiable, Codable, Sendable {
        public let id: String
        public let projectId: UUID
        public var title: String
        public let createdAt: Date
        public var updatedAt: Date
        public var isPinned: Bool
        public var model: String?

        public init(id: String, projectId: UUID, title: String, createdAt: Date, updatedAt: Date, isPinned: Bool, model: String? = nil) {
            self.id = id
            self.projectId = projectId
            self.title = title
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isPinned = isPinned
            self.model = model
        }
    }

    public var summary: Summary {
        Summary(
            id: id,
            projectId: projectId,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isPinned: isPinned,
            model: model
        )
    }
}

extension ChatSession.Summary {
    public func makeSession() -> ChatSession {
        ChatSession(id: id, projectId: projectId, title: title,
                    messages: [], createdAt: createdAt,
                    updatedAt: updatedAt, isPinned: isPinned, model: model)
    }
}
