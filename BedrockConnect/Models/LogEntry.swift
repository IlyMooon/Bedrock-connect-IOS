import Foundation

public struct LogEntry: Identifiable, Equatable {
    public let id = UUID()
    public let timestamp: Date
    public let message: String
    public let level: String

    public init(message: String, level: String = "INFO", timestamp: Date = Date()) {
        self.message = message
        self.level = level
        self.timestamp = timestamp
    }

    public var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}
