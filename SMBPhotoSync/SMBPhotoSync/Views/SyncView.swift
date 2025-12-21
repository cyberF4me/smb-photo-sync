import SwiftUI

struct SyncView: View {
    @EnvironmentObject var syncEngine: SyncEngine
    @StateObject private var backgroundSync = BackgroundSyncManager.shared
    @State private var isSyncing = false

    var body: some View {
        VStack(spacing: 20) {
            // Background sync status banner
            if backgroundSync.isBackgroundSyncEnabled {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Background Sync Enabled")
                            .font(.caption)
                            .fontWeight(.semibold)
                        if let lastSync = backgroundSync.lastSyncDate {
                            Text("Last: \(lastSync, style: .relative) ago")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Text(intervalText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            Spacer()

            Image(systemName: isSyncing ? "arrow.triangle.2.circlepath" : "photo.stack")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .rotationEffect(.degrees(isSyncing ? 360 : 0))
                .animation(isSyncing ? .linear(duration: 1.0).repeatForever(autoreverses: false) : .default, value: isSyncing)

            if isSyncing {
                VStack(spacing: 12) {
                    ProgressView(value: syncEngine.progress.progress)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 300)

                    Text(syncEngine.progress.statusMessage)
                        .font(.headline)
                        .multilineTextAlignment(.center)

                    if syncEngine.progress.totalPhotos > 0 {
                        Text("\(syncEngine.progress.scannedPhotos) of \(syncEngine.progress.totalPhotos)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    if !syncEngine.progress.activeUploads.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Uploading:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(syncEngine.progress.activeUploads) { upload in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(upload.filename)
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                        .lineLimit(1)
                                    ProgressView(value: upload.progress)
                                        .progressViewStyle(.linear)
                                        .tint(.blue)
                                }
                            }
                        }
                        .frame(maxWidth: 300)
                    }

                    HStack(spacing: 20) {
                        if syncEngine.progress.uploadedPhotos > 0 {
                            Label("\(syncEngine.progress.uploadedPhotos) uploaded", systemImage: "arrow.up.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }

                        if syncEngine.progress.skippedPhotos > 0 {
                            Label("\(syncEngine.progress.skippedPhotos) skipped", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }

                        if syncEngine.progress.failedPhotos > 0 {
                            Label("\(syncEngine.progress.failedPhotos) failed", systemImage: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    if !syncEngine.progress.lastFailureReason.isEmpty {
                        Text("Last error: \(syncEngine.progress.lastFailureReason)")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .lineLimit(3)
                    }
                }
                .padding()
            } else {
                VStack(spacing: 12) {
                    Text(syncEngine.progress.totalPhotos > 0 ? "Sync Complete" : "Ready to sync photos")
                        .font(.title2)
                        .fontWeight(.medium)

                    if let error = syncEngine.progress.errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Show final stats if a sync was completed
                    if syncEngine.progress.totalPhotos > 0 {
                        VStack(spacing: 8) {
                            Text("Total: \(syncEngine.progress.totalPhotos) items")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            HStack(spacing: 20) {
                                if syncEngine.progress.uploadedPhotos > 0 {
                                    Label("\(syncEngine.progress.uploadedPhotos) uploaded", systemImage: "arrow.up.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }

                                if syncEngine.progress.skippedPhotos > 0 {
                                    Label("\(syncEngine.progress.skippedPhotos) skipped", systemImage: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }

                                if syncEngine.progress.failedPhotos > 0 {
                                    Label("\(syncEngine.progress.failedPhotos) failed", systemImage: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }

                            if !syncEngine.progress.lastFailureReason.isEmpty {
                                Text("Last error: \(syncEngine.progress.lastFailureReason)")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                    .lineLimit(3)
                            }
                        }
                        .padding()
                    }
                }
            }

            Spacer()

            Button(action: {
                if isSyncing {
                    Task {
                        await syncEngine.cancelSync()
                        isSyncing = false
                    }
                } else {
                    startSync()
                }
            }) {
                Label(
                    isSyncing ? "Cancel" : "Start Sync",
                    systemImage: isSyncing ? "stop.circle.fill" : "arrow.triangle.2.circlepath.circle.fill"
                )
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(isSyncing ? Color.red : Color.blue)
                .cornerRadius(10)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    private func startSync() {
        isSyncing = true
        Task { @MainActor in
            await syncEngine.startSync()
            isSyncing = false
        }
    }
    
    private var intervalText: String {
        let hours = Int(backgroundSync.syncInterval / 3600)
        if hours == 1 {
            return "Every hour"
        } else if hours < 24 {
            return "Every \(hours) hours"
        } else {
            return "Daily"
        }
    }
}
