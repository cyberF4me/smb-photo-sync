import SwiftUI

struct DebugLogsView: View {
    @StateObject private var logManager = LogManager.shared

    var body: some View {
        NavigationView {
            List {
                if logManager.logs.isEmpty {
                    Text("No logs yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(logManager.logs.enumerated()), id: \.offset) { index, log in
                        Text(log)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Debug Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        logManager.clear()
                    }
                }
            }
        }
    }
}
