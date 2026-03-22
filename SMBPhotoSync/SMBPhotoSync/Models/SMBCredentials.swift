import Foundation

struct SMBCredentials: Codable {
    var serverAddress: String
    var shareName: String
    var username: String
    var password: String
    /// Path within the share. Use empty or whitespace-only to use the share root (no subfolder).
    var remotePath: String

    var isValid: Bool {
        !serverAddress.isEmpty &&
        !shareName.isEmpty &&
        !username.isEmpty &&
        !password.isEmpty
    }

    /// Trimmed path within the share; empty means the root of the connected share.
    var trimmedRemotePath: String {
        remotePath.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Directory path for SMB list/create: `"/"` is share root; otherwise a relative folder without outer slashes.
    var smbDirectoryPath: String {
        let t = trimmedRemotePath
        if t.isEmpty { return "/" }
        var p = t
        while p.hasPrefix("/") || p.hasPrefix("\\") { p.removeFirst() }
        while p.hasSuffix("/") || p.hasSuffix("\\") { p.removeLast() }
        return p.isEmpty ? "/" : p
    }

    /// Destination path for an uploaded file within the share.
    func smbUploadPath(forFileName fileName: String) -> String {
        let dir = smbDirectoryPath
        if dir == "/" {
            return fileName
        }
        return "\(dir)/\(fileName)"
    }

    init(
        serverAddress: String = "",
        shareName: String = "",
        username: String = "",
        password: String = "",
        remotePath: String = ""
    ) {
        self.serverAddress = serverAddress
        self.shareName = shareName
        self.username = username
        self.password = password
        self.remotePath = remotePath
    }
}
