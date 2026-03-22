import Photos
import UIKit
import AVFoundation

struct PhotoAsset: Sendable {
    let asset: PHAsset
    let fileName: String
    let creationDate: Date
    let fileExtension: String

    nonisolated var remoteFileName: String {
        // Use creation date and identifier to create unique filename
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: creationDate)

        // Get last 8 characters of asset identifier for uniqueness
        let identifier = String(asset.localIdentifier.prefix(8))

        return "\(dateString)_\(identifier).\(fileExtension)"
    }
}

class PhotoLibraryManager {
    static let shared = PhotoLibraryManager()

    private init() {}

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization { status in
                continuation.resume(returning: status == .authorized || status == .limited)
            }
        }
    }

    func fetchAllPhotos() -> [PhotoAsset] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        if let start = SyncFromDateUserDefaults.inclusiveStartOfDayIfEnabled {
            fetchOptions.predicate = NSPredicate(format: "creationDate >= %@", start as NSDate)
        }

        // Fetch both images and videos
        let assets = PHAsset.fetchAssets(with: fetchOptions)
        var photoAssets: [PhotoAsset] = []

        assets.enumerateObjects { asset, _, _ in
            // Only include images and videos, skip other types
            guard asset.mediaType == .image || asset.mediaType == .video else {
                return
            }

            guard let fileName = asset.value(forKey: "filename") as? String,
                  let creationDate = asset.creationDate else {
                return
            }

            let fileExtension = (fileName as NSString).pathExtension.lowercased()

            let photoAsset = PhotoAsset(
                asset: asset,
                fileName: fileName,
                creationDate: creationDate,
                fileExtension: fileExtension.isEmpty ? (asset.mediaType == .video ? "mov" : "jpg") : fileExtension
            )

            photoAssets.append(photoAsset)
        }

        return photoAssets
    }

    func exportPhoto(_ photoAsset: PhotoAsset) async throws -> URL {
        // Handle videos differently from images
        if photoAsset.asset.mediaType == .video {
            return try await exportVideo(photoAsset)
        }

        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        return try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(for: photoAsset.asset, options: options) { data, dataUTI, orientation, info in
                guard let data = data else {
                    continuation.resume(throwing: PhotoError.exportFailed)
                    return
                }

                // Create temporary file
                let tempDirectory = FileManager.default.temporaryDirectory
                let tempFileURL = tempDirectory.appendingPathComponent(photoAsset.remoteFileName)

                do {
                    try data.write(to: tempFileURL)
                    continuation.resume(returning: tempFileURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func exportVideo(_ photoAsset: PhotoAsset) async throws -> URL {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        return try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestAVAsset(forVideo: photoAsset.asset, options: options) { avAsset, _, info in
                guard let urlAsset = avAsset as? AVURLAsset else {
                    continuation.resume(throwing: PhotoError.exportFailed)
                    return
                }

                // Create temporary file
                let tempDirectory = FileManager.default.temporaryDirectory
                let tempFileURL = tempDirectory.appendingPathComponent(photoAsset.remoteFileName)

                do {
                    // Copy video file to temp location
                    if FileManager.default.fileExists(atPath: tempFileURL.path) {
                        try FileManager.default.removeItem(at: tempFileURL)
                    }
                    try FileManager.default.copyItem(at: urlAsset.url, to: tempFileURL)
                    continuation.resume(returning: tempFileURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    nonisolated func cleanupTempFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

enum PhotoError: LocalizedError {
    case exportFailed
    case authorizationDenied

    var errorDescription: String? {
        switch self {
        case .exportFailed:
            return "Failed to export photo"
        case .authorizationDenied:
            return "Photo library access denied"
        }
    }
}
