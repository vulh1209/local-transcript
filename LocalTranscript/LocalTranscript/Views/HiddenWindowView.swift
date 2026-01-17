import SwiftUI

struct HiddenWindowView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequest)) { _ in
                Task { @MainActor in
                    // Temporarily show dock icon so Settings can receive focus
                    NSApp.setActivationPolicy(.regular)
                    try? await Task.sleep(for: .milliseconds(100))

                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()

                    try? await Task.sleep(for: .milliseconds(200))
                    if let window = NSApp.windows.first(where: {
                        $0.identifier?.rawValue == "com.apple.SwiftUI.Settings" ||
                        $0.title.localizedCaseInsensitiveContains("settings")
                    }) {
                        window.makeKeyAndOrderFront(nil)
                        window.orderFrontRegardless()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .settingsWindowClosed)) { _ in
                // Hide dock icon again
                NSApp.setActivationPolicy(.accessory)
            }
    }
}

extension Notification.Name {
    static let openSettingsRequest = Notification.Name("openSettingsRequest")
    static let settingsWindowClosed = Notification.Name("settingsWindowClosed")
}
