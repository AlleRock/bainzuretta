import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum StravaError: Error, LocalizedError, Equatable {
    case network, auth, scope, rateLimit, response, configuration, cancelled
    public var errorDescription: String? {
        switch self {
        case .network: return "Connessione assente o interrotta. Riprova: l’archivio è conservato."
        case .auth: return "Sessione Strava scaduta o revocata. Riconnetti l’account."
        case .scope: return "Concedi a Bainzuretta il permesso activity:read_all."
        case .rateLimit: return "Limite richieste Strava raggiunto. Riprova tra qualche minuto."
        case .response: return "Risposta di Strava non valida. Nessuna modifica all’archivio."
        case .configuration: return "Configura il collegamento sicuro a Strava nella HOME."
        case .cancelled: return "Connessione Strava annullata."
        }
    }
}
public struct HTTPResponse: Sendable {
    public var data: Data, status: Int
    public init(data: Data, status: Int) { self.data = data; self.status = status }
    public func checked() throws -> Data {
        switch status {
        case 200..<300: return data
        case 400, 401, 403: throw StravaError.auth
        case 429: throw StravaError.rateLimit
        default: throw StravaError.response
        }
    }
}
public protocol HTTPTransport: Sendable { func send(_ request: URLRequest) async throws -> HTTPResponse }
public struct URLSessionTransport: HTTPTransport {
    public init() {}
    public func send(_ request: URLRequest) async throws -> HTTPResponse {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw StravaError.response }
            return HTTPResponse(data: data, status: http.statusCode)
        } catch let e as StravaError { throw e }
        catch is CancellationError { throw CancellationError() }
        catch { throw StravaError.network }
    }
}
public struct StravaRemote: Sendable {
    public let transport: any HTTPTransport
    public init(transport: any HTTPTransport = URLSessionTransport()) { self.transport = transport }
    public static let cyclingTypes = ["Ride", "VirtualRide", "EBikeRide", "MountainBikeRide"]
    public static func activity(_ act: [String: JSONValue]) throws -> Activity {
        guard let id = act["id"], let date = act["start_date_local"]?.text else { throw StravaError.response }
        let distance = try Activity.number(act["distance"], field: "distance") / 1000
        let hours = try Activity.number(act["moving_time"], field: "moving_time") / 3600
        func fixed(_ n: Double, _ decimals: Int) -> JSONValue { .number(Double(Display.fixed(n, decimals))!) }
        var f: [String: JSONValue] = ["id": id, "strava_id": id, "data": .string(date), "distanza": fixed(distance, 2), "tempo": fixed(hours, 4), "media": fixed(hours > 0 ? distance / hours : 0, 2), "nome": act["name"] ?? .string(""), "dislivello": (act["total_elevation_gain"] == .null ? .number(0) : act["total_elevation_gain"] ?? .number(0)), "cadenza": (act["average_cadence"] == .null ? .number(0) : act["average_cadence"] ?? .number(0))]
        if let utc = act["start_date"], utc != .null && utc != .string("") && utc != .bool(false) && utc != .number(0) { f["data_utc"] = utc }
        return try Activity(fields: f)
    }
    public func download(token: String, window: SyncWindow, resync: Bool = false) async throws -> [Activity] {
        var result = [Activity](), seen = [String: Int](), page = 1
        while true {
            try Task.checkCancellation()
            var c = URLComponents(string: "https://www.strava.com/api/v3/athlete/activities")!
            c.queryItems = [URLQueryItem(name: "per_page", value: "100"), URLQueryItem(name: "page", value: String(page)), URLQueryItem(name: "before", value: String(window.before))]
            if window.after > 0 { c.queryItems!.append(URLQueryItem(name: "after", value: String(window.after))) }
            var request = URLRequest(url: c.url!); request.timeoutInterval = 45
            request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
            let response = try await transport.send(request)
            let raw = try response.checked()
            guard let acts = try? JSONDecoder().decode([[String: JSONValue]].self, from: raw) else { throw StravaError.response }
            for act in acts where Self.cyclingTypes.contains(act["type"]?.text ?? "") {
                let a = try Self.activity(act)
                guard let sid = a.stravaID else { throw StravaError.response }
                if let index = seen[sid] { if resync { result[index] = a } }
                else { seen[sid] = result.count; result.append(a) }
            }
            if acts.count < 100 { break }; page += 1
        }
        return result
    }
}
public struct SyncResult: Sendable {
    public var activities: [Activity], missing: [Activity], added: Int, updated: Int
    public func removingMissing() -> [Activity] {
        let ids = Set(missing.map(\.id)); return activities.filter { !ids.contains($0.id) }
    }
}
public enum StravaSync {
    public static func instant(_ text: String) -> Double? {
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return (formatter.date(from: text) ?? ISO8601DateFormatter().date(from: text))?.timeIntervalSince1970
    }
    public static func incrementalAfter(_ data: [Activity]) -> Int64 {
        guard let latest = data.filter({ $0.stravaID != nil }).max(by: { $0.civil < $1.civil }) else { return 0 }
        return max(0, Int64(floor(latest.utc.flatMap(instant) ?? Double(latest.civil.dayNumber) * 86400)) - 86400)
    }
    public static func safelyInside(_ activity: Activity, window: SyncWindow) -> Bool {
        if let utc = activity.utc, let time = instant(utc) { return time > Double(window.after) && time < Double(window.before) }
        let day = Double(activity.civil.dayNumber) * 86400
        return day - 14 * 3600 > Double(window.after) && day + 86400 + 12 * 3600 < Double(window.before)
    }
    public static func merge(existing: [Activity], downloaded: [Activity], window: SyncWindow, resync: Bool) throws -> SyncResult {
        var next = existing, ids = Set(existing.map(\.id)), byStrava = [String: Int]()
        for (i, a) in next.enumerated() { if let sid = a.stravaID { byStrava[sid] = i } }
        var added = 0, updated = 0
        for var a in downloaded {
            guard let sid = a.stravaID else { throw StravaError.response }
            if let index = byStrava[sid] {
                if resync {
                    let old = next[index]
                    var changes = a.fields; changes.removeValue(forKey: "id")
                    let changed = ["data", "data_utc", "distanza", "tempo", "media", "nome", "dislivello", "cadenza"].contains { key in
                        guard let value = changes[key] else { return false }
                        if let text = value.text { return (old.fields[key]?.text ?? "") != text }
                        return abs((old.fields[key]?.double ?? 0) - (value.double ?? 0)) > 1e-6
                    }
                    if changed { next[index] = try old.replacing(changes); updated += 1 }
                }
            } else {
                if ids.contains(a.id) {
                    var key = "strava_" + sid, n = 1
                    while ids.contains(key) { key = "strava_\(sid)_\(n)"; n += 1 }
                    a = try a.replacing(["id": .string(key)])
                }
                ids.insert(a.id); byStrava[sid] = next.count; next.append(a); added += 1
            }
        }
        let downloadedIDs = Set(downloaded.compactMap(\.stravaID))
        // Preserve web safeguard: an empty cycling response must never propose mass deletion.
        let missing = !resync || downloaded.isEmpty ? [] : next.filter { a in
            a.stravaID.map { !downloadedIDs.contains($0) && safelyInside(a, window: window) } ?? false
        }
        next = next.enumerated().sorted { $0.element.civil == $1.element.civil ? $0.offset < $1.offset : $0.element.civil > $1.element.civil }.map(\.element)
        return SyncResult(activities: try ArchiveCodec.validate(next), missing: missing, added: added, updated: updated)
    }
}
