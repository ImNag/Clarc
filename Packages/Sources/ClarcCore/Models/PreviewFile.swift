import Foundation

public struct PreviewFile: Identifiable, Sendable {
    public let id = UUID()
    public let path: String
    public let name: String

    public init(path: String, name: String) {
        self.path = path
        self.name = name
    }
}
