import SwiftUI

struct FloatingIndicator: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.red)
                .frame(width: 12, height: 12)

            Text("Recording")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial)
        }
    }
}
