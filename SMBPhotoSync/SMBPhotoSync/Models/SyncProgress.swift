import Foundation

struct UploadProgress: Identifiable {
    let id = UUID()
    let filename: String
    var progress: Double
}

struct SyncProgress {
    var totalPhotos: Int = 0
    var scannedPhotos: Int = 0
    var uploadedPhotos: Int = 0
    var skippedPhotos: Int = 0
    var failedPhotos: Int = 0
    var currentFileName: String = ""
    var activeUploads: [UploadProgress] = []
    var isScanning: Bool = false
    var isUploading: Bool = false
    var errorMessage: String?
    var lastFailureReason: String = ""

    var progress: Double {
        guard totalPhotos > 0 else { return 0 }
        return Double(scannedPhotos) / Double(totalPhotos)
    }

    var statusMessage: String {
        if let error = errorMessage {
            return "Error: \(error)"
        }

        if isScanning {
            return "Scanning remote directory..."
        }

        if isUploading {
            return "Uploading: \(currentFileName)"
        }

        if totalPhotos > 0 && scannedPhotos == totalPhotos {
            return "Complete: \(uploadedPhotos) uploaded, \(skippedPhotos) skipped, \(failedPhotos) failed"
        }

        return "Ready to sync"
    }
}
