import AppIntents
import Foundation

struct SyncPhotosIntent: AppIntent {
    static var title: LocalizedStringResource = "Sync Photos to SMB"
    static var description = IntentDescription("Syncs photos from your library to the configured SMB share")

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        let syncEngine = SyncEngine()

        guard syncEngine.isConfigured else {
            throw SyncError.notConfigured
        }

        await syncEngine.startSync()

        if let error = syncEngine.progress.errorMessage {
            throw SyncError.syncFailed(error)
        }

        return .result(
            dialog: "Synced \(syncEngine.progress.uploadedPhotos) photos, skipped \(syncEngine.progress.skippedPhotos)"
        )
    }
}

enum SyncError: Error, LocalizedError {
    case notConfigured
    case syncFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Please configure SMB settings in the app first"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        }
    }
}

struct SMBPhotoSyncShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SyncPhotosIntent(),
            phrases: [
                "Sync my photos with \(.applicationName)",
                "Upload photos to \(.applicationName)",
                "Backup photos with \(.applicationName)"
            ],
            shortTitle: "Sync Photos",
            systemImageName: "photo.stack"
        )
    }
}
