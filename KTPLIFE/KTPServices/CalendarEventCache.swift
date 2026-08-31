import Foundation

actor CalendarEventCache {
    static let shared = CalendarEventCache()

    struct Snapshot {
        let events: [CalendarEvent]
        let updatedAt: Date
    }

    private struct StoredSnapshot: Codable {
        let events: [CalendarEvent]
        let updatedAt: Date
    }

    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directory = baseURL.appendingPathComponent("KTPLIFE", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("calendar-events.json")
    }

    func load(accountID: String) -> Snapshot? {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshots = try? JSONDecoder().decode([String: StoredSnapshot].self, from: data),
              let snapshot = snapshots[accountID]
        else { return nil }
        return Snapshot(events: snapshot.events, updatedAt: snapshot.updatedAt)
    }

    func save(_ events: [CalendarEvent], accountID: String, updatedAt: Date = Date()) {
        var snapshots: [String: StoredSnapshot] = [:]
        if let existingData = try? Data(contentsOf: fileURL),
           let existingSnapshots = try? JSONDecoder().decode([String: StoredSnapshot].self, from: existingData) {
            snapshots = existingSnapshots
        }
        snapshots[accountID] = StoredSnapshot(events: events, updatedAt: updatedAt)
        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }
        try? data.write(to: fileURL, options: .atomic)
    }
}
