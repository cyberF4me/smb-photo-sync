import SwiftUI

struct ContentView: View {
    @EnvironmentObject var syncEngine: SyncEngine
    @State private var showingSettings = false

    var body: some View {
        NavigationView {
            VStack {
                if syncEngine.isConfigured {
                    SyncView()
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "externaldrive.badge.wifi")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)

                        Text("SMB Photo Sync")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Sync your photos to SMB share")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Button(action: {
                            showingSettings = true
                        }) {
                            Label("Configure SMB Settings", systemImage: "gear")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                    }
                }
            }
            .navigationTitle("Photo Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(isPresented: $showingSettings)
            }
        }
    }
}
