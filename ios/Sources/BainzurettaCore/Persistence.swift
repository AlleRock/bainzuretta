import Foundation

public struct Preferences: Codable, Equatable, Sendable {
    public var targets: [String: Double] = [:]
    public var recordCategory: RecordCategory = .distance
    public init() {}
    public func target(_ year: Int) -> Double { targets[String(year)] ?? 5000 }
}
public struct SyncWindow: Codable, Equatable, Sendable {
    public var after: Int64, before: Int64, athlete: String
    public init(after: Int64, before: Int64, athlete: String) { self.after = after; self.before = before; self.athlete = athlete }
}
public struct Archive: Codable, Equatable, Sendable {
    public var version = 1
    public var activities: [Activity] = []
    public var preferences = Preferences()
    public var pendingSync: SyncWindow? = nil
    public init() {}
    public func validated() throws -> Archive {
        guard version == 1 else { throw ArchiveError.invalid("versione backup non supportata") }
        _ = try ArchiveCodec.validate(activities)
        guard preferences.targets.allSatisfy({ $0.value.isFinite && $0.value > 0 && $0.value.rounded(.down) == $0.value }) else { throw ArchiveError.invalid("obiettivi") }
        return self
    }
    public static func importing(_ data: Data, current: Archive) throws -> Archive {
        var clean = data
        if clean.starts(with: [0xef, 0xbb, 0xbf]) { clean.removeFirst(3) }
        guard let text = String(data: clean, encoding: .utf8) else { throw ArchiveError.invalid("codifica UTF-8") }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[") {
            var next = current; next.activities = try ArchiveCodec.decode(clean); next.pendingSync = nil; return next
        }
        var next = try JSONDecoder().decode(Archive.self, from: clean).validated(); next.pendingSync = nil; return next
    }
}

/// One atomically replaced native document. Keeping the original dictionary is preferable to lossy database migrations for this personal archive.
public struct FileArchive: Sendable {
    public let directory: URL
    public var file: URL { directory.appendingPathComponent("archive-v1.json") }
    public var previous: URL { directory.appendingPathComponent("previous-v1.json") }
    public init(directory: URL) { self.directory = directory }
    public func load() throws -> Archive {
        guard FileManager.default.fileExists(atPath: file.path) else { return Archive() }
        return try JSONDecoder().decode(Archive.self, from: Data(contentsOf: file)).validated()
    }
    public func recovery() throws -> Archive { try JSONDecoder().decode(Archive.self, from: Data(contentsOf: previous)).validated() }
    public func save(_ archive: Archive, backup: Bool = false, allowCorruptRecovery: Bool = false) throws {
        _ = try archive.validated()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(archive)
        if FileManager.default.fileExists(atPath: file.path) {
            let old = try Data(contentsOf: file)
            do {
                _ = try JSONDecoder().decode(Archive.self, from: old).validated()
                if backup { try old.write(to: previous, options: .atomic) }
            } catch {
                guard allowCorruptRecovery else { throw ArchiveError.unavailable }
                try old.write(to: directory.appendingPathComponent("damaged-\(UUID().uuidString).json"), options: .atomic)
            }
        }
        try data.write(to: file, options: .atomic)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: file.path)
        #endif
    }
    public func reset() throws {
        // Directory contains only Bainzuretta documents. Keep a rollback directory until the new empty archive exists.
        let rollback = directory.deletingLastPathComponent().appendingPathComponent("bainzuretta-reset-\(UUID().uuidString)")
        let exists = FileManager.default.fileExists(atPath: directory.path)
        if exists { try FileManager.default.moveItem(at: directory, to: rollback) }
        do { try save(Archive()) }
        catch {
            try? FileManager.default.removeItem(at: directory)
            if exists { try FileManager.default.moveItem(at: rollback, to: directory) }
            throw error
        }
        if exists { try FileManager.default.removeItem(at: rollback) }
    }
}
