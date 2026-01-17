import SwiftUI

@Observable
class AppState {
    var isRecording = false

    let permissionManager = PermissionManager()
    let modelManager = ModelManager()
    let launchManager = LaunchManager()
    let audioRecorder = AudioRecorder()
}
