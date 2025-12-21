import Foundation

struct SMBCredentials: Codable {
    var serverAddress: String
    var shareName: String
    var username: String
    var password: String
    var remotePath: String // Path within the share where photos should be stored

    var isValid: Bool {
        !serverAddress.isEmpty &&
        !shareName.isEmpty &&
        !username.isEmpty &&
        !password.isEmpty
    }

    init(
        serverAddress: String = "",
        shareName: String = "",
        username: String = "",
        password: String = "",
        remotePath: String = "Photos"
    ) {
        self.serverAddress = serverAddress
        self.shareName = shareName
        self.username = username
        self.password = password
        self.remotePath = remotePath
    }
}
