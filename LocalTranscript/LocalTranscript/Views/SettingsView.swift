import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        Form {
            Section("General") {
                Text("Settings will appear here")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 300)
    }
}
