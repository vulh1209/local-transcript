import SwiftUI

// MARK: - Glass Section

struct GlassSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: GlassDesign.Spacing.xs) {
            // Section header
            HStack(spacing: GlassDesign.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .padding(.horizontal, GlassDesign.Spacing.xxs)

            // Section content with glass effect
            VStack(alignment: .leading, spacing: GlassDesign.Spacing.sm) {
                content
            }
            .padding(GlassDesign.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: GlassDesign.CornerRadius.medium)
                    .fill(.regularMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: GlassDesign.CornerRadius.medium)
                    .stroke(
                        LinearGradient(
                            colors: [
                                GlassDesign.Colors.glassBorder,
                                GlassDesign.Colors.glassBorderSubtle
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
        }
    }
}

// MARK: - Glass Toggle

struct GlassToggle: View {
    let title: String
    @Binding var isOn: Bool

    init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        self._isOn = isOn
    }

    var body: some View {
        Toggle(title, isOn: $isOn)
            .toggleStyle(GlassToggleStyle())
    }
}

struct GlassToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
                .font(.system(size: 13))

            Spacer()

            ZStack {
                Capsule()
                    .fill(configuration.isOn ? Color.accentColor : Color.gray.opacity(0.25))
                    .frame(width: 42, height: 25)
                    .overlay {
                        Capsule()
                            .stroke(
                                configuration.isOn
                                    ? Color.accentColor.opacity(0.3)
                                    : GlassDesign.Colors.glassBorderSubtle,
                                lineWidth: 0.5
                            )
                    }
                    .shadow(
                        color: configuration.isOn ? Color.accentColor.opacity(0.3) : .clear,
                        radius: 4,
                        x: 0,
                        y: 0
                    )

                Circle()
                    .fill(.white)
                    .frame(width: 21, height: 21)
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                    .offset(x: configuration.isOn ? 8.5 : -8.5)
            }
            .onTapGesture {
                withAnimation(GlassDesign.Animation.smooth) {
                    configuration.isOn.toggle()
                }
            }
        }
    }
}

// MARK: - Glass Segmented Picker

struct GlassSegmentedPicker<T: Hashable, Label: View>: View {
    @Binding var selection: T
    let options: [T]
    @ViewBuilder let label: (T) -> Label

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(GlassDesign.Animation.smooth) {
                        selection = option
                    }
                } label: {
                    label(option)
                        .font(.system(size: 12, weight: selection == option ? .semibold : .regular))
                        .foregroundStyle(selection == option ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, GlassDesign.Spacing.xs)
                        .background {
                            if selection == option {
                                RoundedRectangle(cornerRadius: GlassDesign.CornerRadius.small)
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: GlassDesign.CornerRadius.small + 3)
                .fill(Color.gray.opacity(0.12))
        }
    }
}

// MARK: - Glass Slider

struct GlassSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let title: String
    let valueLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: GlassDesign.Spacing.xs) {
            HStack {
                Text(title)
                    .font(.system(size: 13))
                Spacer()
                Text(valueLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, GlassDesign.Spacing.xs)
                    .padding(.vertical, GlassDesign.Spacing.xxs)
                    .background {
                        Capsule()
                            .fill(.ultraThinMaterial)
                    }
            }

            Slider(value: $value, in: range, step: step)
                .tint(.accentColor)
        }
    }
}

// MARK: - Glass Permission Row

struct GlassPermissionRow: View {
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: GlassDesign.Spacing.sm) {
            // Status icon
            ZStack {
                Circle()
                    .fill(isGranted ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isGranted ? .green : .orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !isGranted {
                Button {
                    action()
                } label: {
                    Text("Grant")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, GlassDesign.Spacing.sm)
                        .padding(.vertical, GlassDesign.Spacing.xs - 2)
                        .background {
                            Capsule()
                                .fill(Color.accentColor)
                        }
                        .shadow(color: Color.accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(GlassDesign.Spacing.xs)
        .background {
            RoundedRectangle(cornerRadius: GlassDesign.CornerRadius.small)
                .fill(isHovered ? GlassDesign.Colors.glassPrimary : .clear)
        }
        .animation(GlassDesign.Animation.fast, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content
    var showShadow: Bool = true

    var body: some View {
        content
            .background {
                RoundedRectangle(cornerRadius: GlassDesign.CornerRadius.card)
                    .fill(.thinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: GlassDesign.CornerRadius.card)
                    .stroke(
                        LinearGradient(
                            colors: [
                                GlassDesign.Colors.glassBorder,
                                GlassDesign.Colors.glassBorderSubtle
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
            .shadow(
                color: showShadow ? .black.opacity(0.06) : .clear,
                radius: 6,
                x: 0,
                y: 3
            )
    }
}

// MARK: - Glass Empty State

struct GlassEmptyState: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: GlassDesign.Spacing.md) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 80, height: 80)

                Image(systemName: icon)
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.secondary, .secondary.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            VStack(spacing: GlassDesign.Spacing.xs) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(GlassDesign.Colors.textPrimary)

                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(GlassDesign.Colors.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(GlassDesign.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Glass Clear Button

struct GlassClearButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: GlassDesign.Spacing.xs) {
                Image(systemName: "trash")
                Text("Clear All")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(isHovered ? .red : .secondary)
            .padding(.horizontal, GlassDesign.Spacing.md)
            .padding(.vertical, GlassDesign.Spacing.xs)
            .background {
                Capsule()
                    .fill(isHovered ? Color.red.opacity(0.1) : .clear)
            }
            .overlay {
                Capsule()
                    .stroke(
                        isHovered ? Color.red.opacity(0.3) : GlassDesign.Colors.glassBorderSubtle,
                        lineWidth: 0.5
                    )
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(GlassDesign.Animation.fast) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Language Badge

struct LanguageBadge: View {
    let mode: String

    var body: some View {
        Text(mode)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                Capsule()
                    .stroke(GlassDesign.Colors.glassBorderSubtle, lineWidth: 0.5)
            }
    }
}

// MARK: - Translation Badge

struct TranslationBadge: View {
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "globe")
                .font(.system(size: 8))
            Text("EN")
        }
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}
