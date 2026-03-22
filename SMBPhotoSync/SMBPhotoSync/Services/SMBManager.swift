import Foundation
import AMSMB2

actor SMBManager {
    private var client: SMB2Manager?

    func connect(credentials: SMBCredentials) async throws {
        // Disconnect existing connection first
        disconnect()

        let serverURL = URL(string: "smb://\(credentials.serverAddress)")!

        let credential = URLCredential(
            user: credentials.username,
            password: credentials.password,
            persistence: .forSession
        )

        let newClient = SMB2Manager(
            url: serverURL,
            domain: "",
            credential: credential
        )

        client = newClient

        guard let client = client else {
            throw SMBError.connectionFailed
        }

        try await client.connectShare(name: credentials.shareName)
    }

    func disconnect() {
        client?.disconnectShare()
        client = nil
    }

    func listFiles(atPath path: String) async throws -> [String] {
        guard let client = client else {
            throw SMBError.notConnected
        }

        let entries = try await client.contentsOfDirectory(atPath: path)

        let fileNames = entries.compactMap { entry -> String? in
            guard entry[URLResourceKey.fileResourceTypeKey] as? URLFileResourceType == .regular else {
                return nil
            }
            return entry[URLResourceKey.nameKey] as? String
        }

        return fileNames
    }

    func createDirectory(atPath path: String) async throws {
        guard let client = client else {
            throw SMBError.notConnected
        }

        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        // Share root already exists; do not mkdir.
        if trimmed.isEmpty || trimmed == "/" {
            return
        }

        do {
            try await client.createDirectory(atPath: trimmed)
        } catch {
            let nsError = error as NSError
            // Ignore error if directory already exists (error code 17 = EEXIST)
            if nsError.code == 17 || nsError.code == NSFileWriteFileExistsError {
                return
            }
            throw error
        }
    }

    func uploadFile(localURL: URL, toPath remotePath: String, progress: (@Sendable (Int64, Int64) -> Void)? = nil) async throws {
        guard let client = client else {
            throw SMBError.notConnected
        }

        // Get file size for progress calculation
        let fileSize = try FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? Int64 ?? 0

        // Convert our progress callback to AMSMB2's format
        let smbProgress: (@Sendable (Int64) -> Bool)? = progress != nil ? { @Sendable bytesWritten in
            progress?(bytesWritten, fileSize)
            return true // Continue upload
        } : nil

        try await client.uploadItem(at: localURL, toPath: remotePath, progress: smbProgress)
    }

    func fileExists(atPath path: String) async throws -> Bool {
        guard let client = client else {
            throw SMBError.notConnected
        }

        do {
            _ = try await client.attributesOfItem(atPath: path)
            return true
        } catch {
            let nsError = error as NSError
            // File doesn't exist
            if nsError.domain == NSCocoaErrorDomain &&
               (nsError.code == NSFileNoSuchFileError || nsError.code == NSFileReadNoSuchFileError) {
                return false
            }
            throw error
        }
    }
}

enum SMBError: LocalizedError {
    case connectionFailed
    case notConnected
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to connect to SMB server"
        case .notConnected:
            return "Not connected to SMB server"
        case .uploadFailed:
            return "Failed to upload file"
        }
    }
}
