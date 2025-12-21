import Foundation
import BackgroundTasks
import UIKit
import Combine

@MainActor
class BackgroundSyncManager: ObservableObject {
    static let shared = BackgroundSyncManager()
    
    private let taskIdentifier = "com.smb.photosync.refresh"
    private let defaults = UserDefaults.standard
    
    @Published var isBackgroundSyncEnabled: Bool {
        didSet {
            defaults.set(isBackgroundSyncEnabled, forKey: "backgroundSyncEnabled")
            if isBackgroundSyncEnabled {
                scheduleNextBackgroundSync()
            } else {
                cancelBackgroundSync()
            }
        }
    }
    
    @Published var syncInterval: TimeInterval {
        didSet {
            defaults.set(syncInterval, forKey: "syncInterval")
            if isBackgroundSyncEnabled {
                scheduleNextBackgroundSync()
            }
        }
    }
    
    @Published var wifiOnlySync: Bool {
        didSet {
            defaults.set(wifiOnlySync, forKey: "wifiOnlySync")
        }
    }
    
    @Published var lastSyncDate: Date? {
        didSet {
            if let date = lastSyncDate {
                defaults.set(date, forKey: "lastSyncDate")
            }
        }
    }
    
    @Published var lastSyncPhotoCount: Int {
        didSet {
            defaults.set(lastSyncPhotoCount, forKey: "lastSyncPhotoCount")
        }
    }
    
    private init() {
        self.isBackgroundSyncEnabled = defaults.bool(forKey: "backgroundSyncEnabled")
        self.syncInterval = defaults.double(forKey: "syncInterval") == 0 ? 14400 : defaults.double(forKey: "syncInterval") // Default 4 hours
        self.wifiOnlySync = defaults.bool(forKey: "wifiOnlySync")
        self.lastSyncDate = defaults.object(forKey: "lastSyncDate") as? Date
        self.lastSyncPhotoCount = defaults.integer(forKey: "lastSyncPhotoCount")
    }
    
    // MARK: - Background Task Registration
    
    func registerBackgroundTasks() {
        let success = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            Task {
                await self.handleBackgroundSync(task: task as! BGAppRefreshTask)
            }
        }

        Task { @MainActor in
            if success {
                LogManager.shared.log("✅ Background task registration succeeded")
            } else {
                LogManager.shared.log("❌ Background task registration FAILED - check Info.plist")
            }
        }
    }
    
    // MARK: - Background Sync Scheduling
    
    func scheduleNextBackgroundSync() {
        cancelBackgroundSync()

        guard isBackgroundSyncEnabled else {
            Task { @MainActor in
                LogManager.shared.log("⏸️ Background sync is disabled")
            }
            return
        }

        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: syncInterval)

        do {
            try BGTaskScheduler.shared.submit(request)
            let nextSyncTime = Date(timeIntervalSinceNow: syncInterval)
            Task { @MainActor in
                LogManager.shared.log("✅ Background sync scheduled for \(nextSyncTime)")
                LogManager.shared.log("⏱️  Interval: \(syncInterval / 3600) hours")
            }
        } catch {
            Task { @MainActor in
                LogManager.shared.log("❌ Failed to schedule: \(error.localizedDescription)")
            }
        }
    }
    
    func cancelBackgroundSync() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
    }
    
    // MARK: - Background Sync Execution
    
    private func handleBackgroundSync(task: BGAppRefreshTask) async {
        // Schedule the next sync
        scheduleNextBackgroundSync()
        
        // Set expiration handler
        task.expirationHandler = {
            print("⏱️ Background sync expired")
        }
        
        let shouldSync = await shouldPerformSync()
        
        if shouldSync {
            print("🔄 Starting background sync...")
            let result = await performBackgroundSync()
            task.setTaskCompleted(success: result)
            print("✅ Background sync completed: \(result)")
        } else {
            print("⏭️ Skipping background sync (no new photos or synced recently)")
            task.setTaskCompleted(success: true)
        }
    }
    
    // MARK: - Smart Sync Logic
    
    func shouldPerformSync() async -> Bool {
        // Check if WiFi-only is enabled
        if wifiOnlySync && !isConnectedToWiFi() {
            print("📵 WiFi-only enabled but not on WiFi")
            return false
        }
        
        // Check if we synced recently (within last hour)
        if let lastSync = lastSyncDate, Date().timeIntervalSince(lastSync) < 3600 {
            print("⏱️ Synced recently, skipping")
            return false
        }
        
        // Check if there are new photos
        let hasNewPhotos = await hasNewPhotosToSync()
        if !hasNewPhotos {
            print("📸 No new photos to sync")
        }
        
        return hasNewPhotos
    }
    
    private func hasNewPhotosToSync() async -> Bool {
        let photoManager = PhotoLibraryManager.shared
        
        // Request authorization if needed
        let authorized = await photoManager.requestAuthorization()
        guard authorized else { return false }
        
        let currentPhotoCount = photoManager.fetchAllPhotos().count
        
        // If we've never synced, or photo count increased
        if lastSyncPhotoCount == 0 || currentPhotoCount > lastSyncPhotoCount {
            return true
        }
        
        return false
    }
    
    private func isConnectedToWiFi() -> Bool {
        // Check network connection type
        // This is a simplified check - you might want to use NWPathMonitor for more accuracy
        let reachability = Reachability()
        return reachability.connection == .wifi
    }
    
    private func performBackgroundSync() async -> Bool {
        let syncEngine = SyncEngine()
        
        guard syncEngine.isConfigured else {
            print("⚠️ Not configured, skipping sync")
            return false
        }
        
        await syncEngine.startSync()
        
        // Update last sync info
        await MainActor.run {
            self.lastSyncDate = Date()
            self.lastSyncPhotoCount = syncEngine.progress.totalPhotos
        }
        
        // Return success if no error
        return syncEngine.progress.errorMessage == nil
    }
    
    // MARK: - Manual Sync Tracking

    func recordManualSync(totalPhotos: Int) {
        lastSyncDate = Date()
        lastSyncPhotoCount = totalPhotos
    }

    // MARK: - Testing Helper

    func triggerManualBackgroundSync() async -> Bool {
        await MainActor.run {
            LogManager.shared.log("🧪 Manual background sync triggered")
        }
        let result = await performBackgroundSync()
        await MainActor.run {
            LogManager.shared.log(result ? "✅ Test sync completed successfully" : "❌ Test sync failed")
        }
        return result
    }
}

// MARK: - Simple Reachability Check

enum ReachabilityConnection {
    case wifi
    case cellular
    case none
}

class Reachability {
    var connection: ReachabilityConnection {
        // This is a simplified implementation
        // In production, you'd use Network framework's NWPathMonitor
        return .wifi // For now, assume WiFi
    }
}
