import Foundation
import ServiceManagement

@Observable
class LaunchManager {
    var launchAtLogin: Bool = false {
        didSet {
            guard oldValue != launchAtLogin else { return }
            updateLoginItem()
        }
    }

    init() {
        syncFromSystem()
    }

    /// Sync state from system (user may have changed in System Settings)
    func syncFromSystem() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func updateLoginItem() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Revert on failure
            print("Failed to update login item: \(error)")
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
