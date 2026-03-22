import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var syncEngine: SyncEngine
    @StateObject private var backgroundSync = BackgroundSyncManager.shared
    @Binding var isPresented: Bool

    @State private var serverAddress: String = ""
    @State private var shareName: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var remotePath: String = ""

    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isTesting = false
    @State private var showingSuccess = false
    @State private var showingDebugLogs = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("SMB Server")) {
                    TextField("Server Address", text: $serverAddress)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    TextField("Share Name", text: $shareName)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                Section(header: Text("Credentials")) {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }

                Section(header: Text("Remote Path"), footer: Text("Optional subfolder inside the share. Leave empty to put files directly in the share root—for example when the share is already \\\\server\\Camera, set Share Name to Camera and leave this blank.")) {
                    TextField("Subfolder (optional)", text: $remotePath)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                Section {
                    Button(action: testConnection) {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(isTesting ? "Testing Connection..." : "Test Connection")
                        }
                    }
                    .disabled(isTesting || !isFormValid)
                }
                
                Section(header: Text("Sync from date"), footer: Text("When enabled, only photos and videos with a creation date on or after this day are included in sync.")) {
                    Toggle("Limit to photos from date", isOn: $backgroundSync.syncFromDateEnabled)

                    if backgroundSync.syncFromDateEnabled {
                        DatePicker(
                            "Include from",
                            selection: $backgroundSync.syncFromDate,
                            displayedComponents: .date
                        )
                    }
                }

                Section(header: Text("Background Sync"), footer: backgroundSyncFooter) {
                    Toggle("Enable Background Sync", isOn: $backgroundSync.isBackgroundSyncEnabled)

                    if backgroundSync.isBackgroundSyncEnabled {
                        Picker("Sync Interval", selection: $backgroundSync.syncInterval) {
                            Text("Every 1 hour").tag(3600.0)
                            Text("Every 2 hours").tag(7200.0)
                            Text("Every 4 hours").tag(14400.0)
                            Text("Every 6 hours").tag(21600.0)
                            Text("Every 12 hours").tag(43200.0)
                        }

                        Toggle("WiFi Only", isOn: $backgroundSync.wifiOnlySync)

                        Button("Test Background Sync") {
                            testBackgroundSync()
                        }
                        .foregroundColor(.blue)
                    }

                    if let lastSync = backgroundSync.lastSyncDate {
                        HStack {
                            Text("Last Sync")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                    }
                }

                Section(header: Text("Debug")) {
                    Button("View Debug Logs") {
                        showingDebugLogs = true
                    }
                }

                Section(header: Text("Example")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Server Address: 192.168.1.100")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Share Name: photos")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Remote Path: iPhone/2024")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("SMB Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                    }
                    .disabled(!isFormValid)
                }
            }
            .alert("Connection Successful", isPresented: $showingSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Successfully connected to SMB server")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingDebugLogs) {
                DebugLogsView()
            }
            .onAppear {
                loadCurrentSettings()
            }
        }
    }

    private var isFormValid: Bool {
        !serverAddress.isEmpty &&
        !shareName.isEmpty &&
        !username.isEmpty &&
        !password.isEmpty
    }
    
    private var backgroundSyncFooter: Text {
        Text("iOS will automatically sync photos in the background at the selected interval. This works best when combined with Shortcuts automations for immediate syncing when needed.")
    }

    private func loadCurrentSettings() {
        serverAddress = syncEngine.credentials.serverAddress
        shareName = syncEngine.credentials.shareName
        username = syncEngine.credentials.username
        password = syncEngine.credentials.password
        remotePath = syncEngine.credentials.remotePath
    }

    private func saveSettings() {
        let newCredentials = SMBCredentials(
            serverAddress: serverAddress,
            shareName: shareName,
            username: username,
            password: password,
            remotePath: remotePath
        )

        do {
            try syncEngine.saveCredentials(newCredentials)
            isPresented = false
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func testConnection() {
        isTesting = true

        let testCredentials = SMBCredentials(
            serverAddress: serverAddress,
            shareName: shareName,
            username: username,
            password: password,
            remotePath: remotePath
        )

        Task {
            do {
                try syncEngine.saveCredentials(testCredentials)
                try await syncEngine.testConnection()
                await MainActor.run {
                    isTesting = false
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    isTesting = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }

    private func testBackgroundSync() {
        Task {
            let success = await backgroundSync.triggerManualBackgroundSync()
            await MainActor.run {
                if success {
                    showingSuccess = true
                } else {
                    errorMessage = "Background sync test failed. Check the Xcode console for details."
                    showingError = true
                }
            }
        }
    }
}
