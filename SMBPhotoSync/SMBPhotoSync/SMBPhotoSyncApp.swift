import SwiftUI

@main
struct SMBPhotoSyncApp: App {
    @StateObject private var syncEngine = SyncEngine()

    init() {
        // Register background tasks on app launch
        Task { @MainActor in
            BackgroundSyncManager.shared.registerBackgroundTasks()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(syncEngine)
                .onAppear {
                    // Schedule background sync if enabled
                    Task { @MainActor in
                        if BackgroundSyncManager.shared.isBackgroundSyncEnabled {
                            BackgroundSyncManager.shared.scheduleNextBackgroundSync()
                        }
                    }
                }
        }
    }
}
