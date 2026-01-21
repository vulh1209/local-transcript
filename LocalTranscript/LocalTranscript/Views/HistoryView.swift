import SwiftUI
import SwiftData
import AppKit

struct HistoryView: View {
    @Query(sort: \TranscriptionRecord.timestamp, order: .reverse)
    private var records: [TranscriptionRecord]
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if records.isEmpty {
                GlassEmptyState(
                    icon: "text.bubble",
                    title: "No Transcriptions",
                    description: "Your transcription history will appear here"
                )
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: GlassDesign.Spacing.sm) {
                            ForEach(records) { record in
                                GlassHistoryCard(record: record)
                                    .contextMenu {
                                        Button {
                                            copyToClipboard(record.text)
                                        } label: {
                                            Label("Copy", systemImage: "doc.on.doc")
                                        }

                                        Button(role: .destructive) {
                                            withAnimation {
                                                modelContext.delete(record)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(GlassDesign.Spacing.md)
                    }

                    // Footer with clear button
                    VStack(spacing: 0) {
                        Divider()
                            .background(GlassDesign.Colors.glassBorderSubtle)

                        GlassClearButton {
                            appState.historyManager.clearAll()
                        }
                        .padding(GlassDesign.Spacing.sm)
                    }
                    .background(.ultraThinMaterial)
                }
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Glass History Card

struct GlassHistoryCard: View {
    let record: TranscriptionRecord
    @State private var isHovered = false
    @State private var showCopiedFeedback = false

    var body: some View {
        VStack(alignment: .leading, spacing: GlassDesign.Spacing.xs) {
            // Main text
            Text(record.text)
                .font(.system(size: 13))
                .lineLimit(3)
                .foregroundStyle(GlassDesign.Colors.textPrimary)

            // Metadata row
            HStack(spacing: GlassDesign.Spacing.xs) {
                // Timestamp
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(record.timestamp, style: .relative)
                }
                .foregroundStyle(GlassDesign.Colors.textTertiary)

                Text("•")
                    .foregroundStyle(GlassDesign.Colors.textTertiary)

                // Language badge
                LanguageBadge(mode: record.languageMode)

                // Duration
                if record.duration > 0 {
                    Text("•")
                        .foregroundStyle(GlassDesign.Colors.textTertiary)

                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.system(size: 10))
                        Text(String(format: "%.1fs", record.duration))
                    }
                    .foregroundStyle(GlassDesign.Colors.textTertiary)
                }

                // Translation badge
                if record.wasTranslated {
                    TranslationBadge()
                }

                Spacer()

                // Copy button (appears on hover)
                if isHovered {
                    Button {
                        copyToClipboard()
                    } label: {
                        Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(showCopiedFeedback ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .font(.caption)
        }
        .padding(GlassDesign.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: GlassDesign.CornerRadius.card)
                .fill(isHovered ? .regularMaterial : .thinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: GlassDesign.CornerRadius.card)
                .stroke(
                    isHovered ? GlassDesign.Colors.glassBorder : GlassDesign.Colors.glassBorderSubtle,
                    lineWidth: isHovered ? 1 : 0.5
                )
        }
        .shadow(
            color: isHovered ? .black.opacity(0.1) : .black.opacity(0.05),
            radius: isHovered ? 8 : 4,
            x: 0,
            y: isHovered ? 4 : 2
        )
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .animation(GlassDesign.Animation.medium, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(record.text, forType: .string)

        withAnimation(GlassDesign.Animation.fast) {
            showCopiedFeedback = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopiedFeedback = false
            }
        }
    }
}
