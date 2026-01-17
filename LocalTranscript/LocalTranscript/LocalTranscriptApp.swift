import SwiftUI

@main
struct LocalTranscriptApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        // Hidden window MUST come first (Settings workaround)
        Window("Hidden", id: "HiddenWindow") {
            HiddenWindowView()
                .environment(appState)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1, height: 1)

        MenuBarExtra {
            MenuBarView()
                .environment(appState)
        } label: {
            Image(systemName: "waveform")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environment(appState)
                .onDisappear {
                    NotificationCenter.default.post(name: .settingsWindowClosed, object: nil)
                }
        }
    }
}
