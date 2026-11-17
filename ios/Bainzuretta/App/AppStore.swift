import SwiftUI
import Observation
import BainzurettaCore

enum AppSection: String, CaseIterable, Identifiable {
    case home = "HOME", diary = "DIARIO", challenge = "SFIDA", archive = "ARCHIVIO", ranking = "RANKING", records = "RECORD"
    var id: String { rawValue }
    var icon: String { switch self { case .home: return "house.fill"; case .diary: return "book.closed.fill"; case .challenge: return "flag.checkered"; case .archive: return "archivebox.fill"; case .ranking: return "trophy.fill"; case .records: return "crown.fill" } }
}
struct Notice: Identifiable { var id = UUID(); var text: String }

@MainActor @Observable final class AppStore {
    private(set) var archive = Archive()
    private(set) var readable = true
    private(set) var busy = false
    var section: AppSection = .home
    var selectedYear: Int?
    var editActivity: Activity?
    var notice: Notice?
    var pendingRemoval: SyncResult?
    var syncMessage = ""
    var now = Date()
    let strava = StravaConnection()
    private let disk: FileArchive
    var today: CivilDate { CivilDate.today(now) }
    var activities: [Activity] { archive.activities }
    var target: Double { archive.preferences.target(today.year) }
    var years: [Int] { Set(activities.map { $0.civil.year }).filter { $0 != today.year }.sorted(by: >) }
    var hasRecovery: Bool { FileManager.default.fileExists(atPath:disk.previous.path) }
    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("Bainzuretta",isDirectory:true)
        disk = FileArchive(directory:base)
        do { archive = try disk.load() } catch { readable = false; report(error) }
        selectedYear = years.first
        if let error = strava.startupError { notice = Notice(text:error) }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            try? disk.reset(); archive = Archive(); readable = true
        }
        #endif
    }
    func refreshClock() { now = Date() }
    func report(_ error: Error) { notice = Notice(text:error.localizedDescription) }
    private func commit(_ next: Archive, backup: Bool = false, recovery: Bool = false) throws {
        guard !busy else { throw ArchiveError.invalid("attendi il termine della sincronizzazione") }
        guard readable || recovery else { throw ArchiveError.unavailable }
        try disk.save(next,backup:backup,allowCorruptRecovery:recovery)
        archive = next; readable = true
        if selectedYear == nil || !years.contains(selectedYear!) { selectedYear = years.first }
    }
    func setTarget(_ text: String) throws {
        guard let n = Double(text), n.isFinite, n > 0, n.rounded(.down) == n, n <= 9_007_199_254_740_991 else { throw ArchiveError.invalid("inserisci un obiettivo intero positivo") }
        var next = archive; next.preferences.targets[String(today.year)] = n; try commit(next)
    }
    func setCategory(_ category: RecordCategory) {
        var next = archive; next.preferences.recordCategory = category
        do { try commit(next) } catch { report(error) }
    }
    func saveManual(day: String, distance: String, duration: String, existing: Activity?) throws {
        var next = archive
        var id = Int64(Date().timeIntervalSince1970 * 1000)
        let ids = Set(activities.map(\.id)); while ids.contains(String(id)) { id += 1 }
        let activity = try Activity.manual(id:String(id),day:day,distance:distance,duration:duration,existing:existing)
        if let existing {
            guard let i = next.activities.firstIndex(where:{$0.id == existing.id}) else { throw ArchiveError.invalid("attività non più presente") }
            next.activities[i] = activity
        } else { next.activities.append(activity) }
        try commit(next); editActivity = nil; syncMessage = "Attività salvata"
    }
    func delete(_ activity: Activity) throws {
        var next = archive; next.activities.removeAll { $0.id == activity.id }; try commit(next)
    }
    func candidate(_ data: Data) throws -> Archive { try Archive.importing(data,current:archive) }
    func importArchive(_ next: Archive) throws { try commit(next,backup:true,recovery:!readable); syncMessage = "Importate \(next.activities.count) attività" }
    func restore() throws { var next = try disk.recovery(); next.pendingSync = nil; try commit(next,backup:readable,recovery:!readable) }
    func reset() throws {
        guard !busy else { throw ArchiveError.invalid("attendi il termine della sincronizzazione") }
        // Preserve the file if credential deletion fails.
        try strava.reset(); try disk.reset(); archive = Archive(); readable = true; selectedYear = nil; editActivity = nil; pendingRemoval = nil; syncMessage = "Dati azzerati"
    }
    func openYear(_ year: Int) { selectedYear = year; section = .archive }
    func connect() async {
        guard !busy else { return }; busy = true
        do { try await strava.connect(); busy = false; await sync() }
        catch { busy = false; report(error) }
    }
    func disconnect(revoke: Bool) async {
        guard !busy else { return }; busy = true
        defer { busy = false }
        do { try await strava.disconnect(revoke:revoke); var next = archive; next.pendingSync = nil; try disk.save(next); archive = next; syncMessage = "Strava disconnesso" }
        catch { report(error) }
    }
    func sync(resync: Bool = false, silent: Bool = false) async {
        guard !busy, readable, strava.connected else { return }; busy = true
        defer { busy = false }
        do {
            let timestamp = Int64(Date().timeIntervalSince1970), athlete = strava.athleteID
            let window: SyncWindow
            if resync { window = SyncWindow(after:timestamp - 60 * 86400,before:timestamp+1,athlete:athlete) }
            else if let pending = archive.pendingSync, pending.athlete == athlete, pending.after >= 0, pending.after < pending.before, pending.before <= timestamp + 60 { window = pending }
            else { window = SyncWindow(after:StravaSync.incrementalAfter(activities),before:timestamp+1,athlete:athlete) }
            if !resync { var next = archive; next.pendingSync = window; try disk.save(next); archive = next }
            var token = try await strava.accessToken()
            let remote = StravaRemote()
            let downloaded: [Activity]
            do { downloaded = try await remote.download(token:token,window:window,resync:resync) }
            catch let e as StravaError where e == .auth {
                token = try await strava.accessToken(forceRefresh:true)
                downloaded = try await remote.download(token:token,window:window,resync:resync)
            }
            let result = try StravaSync.merge(existing:activities,downloaded:downloaded,window:window,resync:resync)
            var next = archive; next.activities = result.activities; next.pendingSync = nil
            try disk.save(next); archive = next
            if !result.missing.isEmpty { pendingRemoval = result }
            syncMessage = "\(result.added) nuove · \(result.updated) aggiornate"
            if selectedYear == nil { selectedYear = years.first }
        } catch { if !silent { report(error) }; syncMessage = "Sincronizzazione non completata. Riprova." }
    }
    func confirmRemoval() throws {
        guard let pending = pendingRemoval else { return }
        let ids = Set(pending.missing.map(\.id))
        var next = archive; next.activities.removeAll { ids.contains($0.id) }; try commit(next); pendingRemoval = nil
    }
}
