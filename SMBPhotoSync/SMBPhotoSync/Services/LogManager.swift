import Foundation
import Combine

@MainActor
class LogManager: ObservableObject {
    static let shared = LogManager()

    @Published var logs: [String] = []

    private init() {}

    func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)"
        logs.append(logMessage)
        print(logMessage)

        // Keep only last 100 logs
        if logs.count > 100 {
            logs.removeFirst()
        }
    }

    func clear() {
        logs.removeAll()
    }
}
