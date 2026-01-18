import Foundation
import SwiftData

@Observable
class HistoryManager {
    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?

    init() {
        setupContainer()
    }

    private func setupContainer() {
        do {
            let schema = Schema([TranscriptionRecord.self])
            let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("LocalTranscript", isDirectory: true)

            // Create directory if needed
            try FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)

            let storeURL = appSupportURL.appendingPathComponent("history.store")
            let config = ModelConfiguration("LocalTranscript", schema: schema, url: storeURL)
            modelContainer = try ModelContainer(for: schema, configurations: config)
            modelContext = ModelContext(modelContainer!)
        } catch {
            print("Failed to setup SwiftData: \(error)")
        }
    }

    var container: ModelContainer? { modelContainer }

    func save(text: String, languageMode: String, duration: TimeInterval, wasTranslated: Bool = false) {
        guard let context = modelContext else { return }
        let record = TranscriptionRecord(text: text, languageMode: languageMode, duration: duration, wasTranslated: wasTranslated)
        context.insert(record)
        try? context.save()

        // Keep only last 100 records
        pruneOldRecords()
    }

    func delete(_ record: TranscriptionRecord) {
        guard let context = modelContext else { return }
        context.delete(record)
        try? context.save()
    }

    func clearAll() {
        guard let context = modelContext else { return }
        do {
            try context.delete(model: TranscriptionRecord.self)
            try context.save()
        } catch {
            print("Failed to clear history: \(error)")
        }
    }

    private func pruneOldRecords() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<TranscriptionRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        do {
            let records = try context.fetch(descriptor)
            if records.count > 100 {
                for record in records.dropFirst(100) {
                    context.delete(record)
                }
                try context.save()
            }
        } catch {
            print("Failed to prune records: \(error)")
        }
    }
}
