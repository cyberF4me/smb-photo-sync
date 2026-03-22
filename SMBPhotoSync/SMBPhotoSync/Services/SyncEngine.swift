import Foundation
import Combine

@MainActor
class SyncEngine: ObservableObject {
    @Published var progress = SyncProgress()
    @Published var credentials: SMBCredentials
    @Published var isConfigured: Bool = false

    private let smbManager = SMBManager()
    private let photoManager = PhotoLibraryManager.shared
    private let keychainManager = KeychainManager.shared

    private var isSyncing = false

    init() {
        // Try to load credentials from Keychain
        if let savedCredentials = try? keychainManager.loadCredentials() {
            self.credentials = savedCredentials
            self.isConfigured = savedCredentials.isValid
        } else {
            self.credentials = SMBCredentials()
            self.isConfigured = false
        }
    }

    func saveCredentials(_ newCredentials: SMBCredentials) throws {
        try keychainManager.saveCredentials(newCredentials)
        self.credentials = newCredentials
        self.isConfigured = newCredentials.isValid
    }

    func testConnection() async throws {
        try await smbManager.connect(credentials: credentials)
        await smbManager.disconnect()
    }

    func startSync() async {
        guard !isSyncing else { return }
        guard isConfigured else {
            progress.errorMessage = "Please configure SMB credentials first"
            return
        }

        isSyncing = true
        progress = SyncProgress()

        do {
            // Request photo library access
            let authorized = await photoManager.requestAuthorization()
            guard authorized else {
                throw PhotoError.authorizationDenied
            }

            // Connect to SMB
            try await smbManager.connect(credentials: credentials)

            // Ensure remote directory exists (no-op for share root)
            let smbDir = credentials.smbDirectoryPath
            try await smbManager.createDirectory(atPath: smbDir)

            // Scan remote directory for existing files
            progress.isScanning = true
            let existingFiles = try await smbManager.listFiles(atPath: smbDir)
            let existingFilesSet = Set(existingFiles)
            progress.isScanning = false

            // Fetch all photos
            let photos = photoManager.fetchAllPhotos()
            progress.totalPhotos = photos.count

            // Filter photos that need to be uploaded
            let photosToUpload = photos.filter { !existingFilesSet.contains($0.remoteFileName) }

            // Update skip count for existing photos
            progress.skippedPhotos = photos.count - photosToUpload.count
            progress.scannedPhotos = progress.skippedPhotos

            // Upload photos in parallel (10 concurrent uploads)
            progress.isUploading = true

            // Capture credentials for use in tasks
            let uploadCredentials = credentials

            await withTaskGroup(of: (Bool, String, String).self) { group in
                var activeUploads = 0
                var photoIndex = 0

                while photoIndex < photosToUpload.count || activeUploads > 0 {
                    // Add new tasks up to the concurrency limit
                    while activeUploads < 10 && photoIndex < photosToUpload.count {
                        let photo = photosToUpload[photoIndex]
                        photoIndex += 1
                        activeUploads += 1

                        group.addTask {
                            let uploadPath = uploadCredentials.smbUploadPath(forFileName: photo.remoteFileName)

                            // Add to active uploads
                            await MainActor.run {
                                self.progress.activeUploads.append(UploadProgress(filename: photo.remoteFileName, progress: 0.0))
                            }

                            do {
                                // Export photo to temporary location
                                let localURL = try await self.photoManager.exportPhoto(photo)

                                // Create a dedicated SMB connection for this upload
                                let uploadManager = SMBManager()

                                // Upload to SMB with retry on connection failure
                                var uploadSuccess = false
                                var retryCount = 0
                                while !uploadSuccess && retryCount < 3 {
                                    do {
                                        try await uploadManager.connect(credentials: uploadCredentials)

                                        // Upload with progress callback
                                        try await uploadManager.uploadFile(localURL: localURL, toPath: uploadPath) { @Sendable bytesWritten, totalBytes in
                                            let uploadProgress = Double(bytesWritten) / Double(totalBytes)
                                            let filename = photo.remoteFileName
                                            Task { @MainActor in
                                                if let index = self.progress.activeUploads.firstIndex(where: { $0.filename == filename }) {
                                                    self.progress.activeUploads[index].progress = uploadProgress
                                                }
                                            }
                                        }

                                        await uploadManager.disconnect()
                                        uploadSuccess = true
                                    } catch {
                                        await uploadManager.disconnect()
                                        if retryCount < 2 {
                                            retryCount += 1
                                            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                                            continue
                                        }
                                        throw error
                                    }
                                }

                                // Cleanup temp file
                                self.photoManager.cleanupTempFile(localURL)

                                return (true, photo.remoteFileName, "")
                            } catch {
                                let errorMsg = "\(photo.fileName): \(error.localizedDescription)"
                                print("Failed to upload \(errorMsg)")
                                return (false, photo.remoteFileName, errorMsg)
                            }
                        }
                    }

                    // Wait for one task to complete
                    if let result = await group.next() {
                        activeUploads -= 1

                        await MainActor.run {
                            let (success, filename, errorMessage) = result

                            // Always remove from active uploads
                            self.progress.activeUploads.removeAll { $0.filename == filename }

                            if success {
                                self.progress.uploadedPhotos += 1
                                self.progress.currentFileName = filename
                            } else {
                                self.progress.failedPhotos += 1
                                self.progress.lastFailureReason = errorMessage
                            }
                            self.progress.scannedPhotos += 1
                        }
                    }
                }
            }

            progress.isUploading = false
            await smbManager.disconnect()

            // Record sync completion for background sync manager
            BackgroundSyncManager.shared.recordManualSync(totalPhotos: progress.totalPhotos)

        } catch {
            progress.errorMessage = error.localizedDescription
            await smbManager.disconnect()
        }

        isSyncing = false
    }

    func cancelSync() async {
        await smbManager.disconnect()
        isSyncing = false
    }
}
