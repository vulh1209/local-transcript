import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \TranscriptionRecord.timestamp, order: .reverse)
    private var records: [TranscriptionRecord]
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if records.isEmpty {
                ContentUnavailableView(
                    "No Transcriptions",
                    systemImage: "text.bubble",
                    description: Text("Your transcription history will appear here")
                )
            } else {
                VStack(spacing: 0) {
                    List {
                        ForEach(records) { record in
                            HistoryRow(record: record)
                        }
                        .onDelete(perform: deleteRecords)
                    }

                    Divider()

                    Button(role: .destructive) {
                        appState.historyManager.clearAll()
                    } label: {
                        Label("Clear All", systemImage: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .padding(8)
                }
            }
        }
    }

    private func deleteRecords(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(records[index])
        }
    }
}

struct HistoryRow: View {
    let record: TranscriptionRecord
    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.text)
                .lineLimit(3)

            HStack {
                Text(record.timestamp, style: .relative)
                Text("-")
                Text(record.languageMode)
                if record.duration > 0 {
                    Text("-")
                    Text(String(format: "%.1fs", record.duration))
                }
                if record.wasTranslated {
                    Text("EN")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .contextMenu {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(record.text, forType: .string)
                isCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    isCopied = false
                }
            } label: {
                Label(isCopied ? "Copied!" : "Copy", systemImage: "doc.on.doc")
            }
        }
        .padding(.vertical, 4)
    }
}
