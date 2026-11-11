import Foundation

/// One finished dictation.
struct TranscriptEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    let text: String
    let date: Date

    var wordCount: Int { text.split { $0 == " " || $0 == "\n" }.count }
}

/// Recent transcripts, newest first, kept on this Mac only in
/// ~/Library/Application Support/OneTapTranscribe/history.json.
enum TranscriptHistory {
    static let limit = 100

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OneTapTranscribe", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }

    static func load() -> [TranscriptEntry] {
        guard let data = try? Data(contentsOf: fileURL),
              let entries = try? JSONDecoder().decode([TranscriptEntry].self, from: data) else { return [] }
        return entries
    }

    static func save(_ entries: [TranscriptEntry]) {
        guard let data = try? JSONEncoder().encode(Array(entries.prefix(limit))) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }
}
