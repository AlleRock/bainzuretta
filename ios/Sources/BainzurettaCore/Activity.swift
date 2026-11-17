import Foundation

public enum ArchiveError: Error, LocalizedError, Equatable {
    case invalid(String), duplicate(String), unavailable
    public var errorDescription: String? {
        switch self {
        case .invalid(let field): return "Archivio non valido: \(field). I dati precedenti sono conservati."
        case .duplicate(let id): return "Identificatore duplicato: \(id)."
        case .unavailable: return "Archivio non leggibile: importa una copia valida o ripristina il backup precedente."
        }
    }
}

/// A lossless JSON tree also retains fields introduced by future web versions.
public enum JSONValue: Codable, Equatable, Sendable {
    case null, bool(Bool), number(Double), string(String), array([JSONValue]), object([String: JSONValue])
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }
    public var text: String? { if case .string(let v) = self { return v }; return nil }
    public var double: Double? { if case .number(let v) = self { return v }; return nil }
    public var isNull: Bool { self == .null }
}

public struct Activity: Codable, Identifiable, Equatable, Sendable {
    public private(set) var fields: [String: JSONValue]
    public var id: String {
        if let n = fields["id"]?.double { return String(Int64(n)) }
        return fields["id"]?.text ?? ""
    }
    public var stravaID: String? { fields["strava_id"]?.double.map { String(Int64($0)) } }
    public var dateText: String { fields["data"]?.text ?? "" }
    public let civil: CivilDate
    public var distance: Double { fields["distanza"]?.double ?? 0 }
    public var hours: Double { fields["tempo"]?.double ?? 0 }
    public var speed: Double { fields["media"]?.double ?? 0 }
    public var elevation: Double { fields["dislivello"]?.double ?? 0 }
    public var cadence: Double { fields["cadenza"]?.double ?? 0 }
    public var name: String { fields["nome"]?.text ?? "" }
    public var utc: String? { fields["data_utc"]?.text }

    public init(fields original: [String: JSONValue]) throws {
        var f = original
        f["id"] = try Self.identifier(f["id"], field: "id")
        guard let date = f["data"]?.text else { throw ArchiveError.invalid("data") }
        civil = try CivilDate(date)
        f["distanza"] = .number(try Self.number(f["distanza"], field: "distanza"))
        let hasHours = f["tempo"] != nil && f["tempo"] != .null
        let hasSpeed = f["media"] != nil && f["media"] != .null
        var hours = hasHours ? try Self.number(f["tempo"], field: "tempo") : 0
        var speed = hasSpeed ? try Self.number(f["media"], field: "media") : 0
        let distance = f["distanza"]!.double!
        if !hasHours && speed > 0 { hours = distance / speed }
        if !hasSpeed && hours > 0 { speed = distance / hours }
        guard hours.isFinite && speed.isFinite else { throw ArchiveError.invalid("durata o media fuori intervallo") }
        f["tempo"] = .number(hours); f["media"] = .number(speed)
        if let sid = f["strava_id"], sid != .null && sid != .string("") {
            f["strava_id"] = try Self.identifier(sid, field: "strava_id", numericOnly: true)
        } else { f.removeValue(forKey: "strava_id") }
        if let name = f["nome"] {
            if name == .null { f["nome"] = .string("") }
            else if name.text == nil { throw ArchiveError.invalid("nome: richiesto testo") }
        }
        for key in ["dislivello", "cadenza"] {
            if let value = f[key], value != .null { f[key] = .number(try Self.number(value, field: key)) }
        }
        if let utc = f["data_utc"] {
            guard let s = utc.text, s.range(of: #"Z$|[+-]\d{2}:\d{2}$"#, options: .regularExpression) != nil else { throw ArchiveError.invalid("data_utc") }
            _ = try CivilDate(s)
        }
        fields = f
    }
    public init(from decoder: Decoder) throws { try self.init(fields: [String: JSONValue](from: decoder)) }
    public func encode(to encoder: Encoder) throws { try fields.encode(to: encoder) }

    public static func number(_ value: JSONValue?, field: String) throws -> Double {
        var n = value?.double
        if let s = value?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
           s.range(of: #"^[+]?(?:\d+(?:[.,]\d*)?|[.,]\d+)(?:[eE][+-]?\d+)?$"#, options: .regularExpression) != nil {
            n = Double(s.replacingOccurrences(of: ",", with: "."))
        }
        guard let n, n.isFinite, n >= 0 else { throw ArchiveError.invalid(field + ": richiesto numero finito non negativo") }
        return n
    }
    static func identifier(_ value: JSONValue?, field: String, numericOnly: Bool = false) throws -> JSONValue {
        if let n = value?.double, n > 0, n <= 9_007_199_254_740_991, n.rounded(.down) == n { return .number(n) }
        if let s = value?.text, s.count <= 128 {
            if s.range(of: #"^[0-9]+$"#, options: .regularExpression) != nil, let n = Double(s), n > 0, n <= 9_007_199_254_740_991 { return .number(n) }
            if !numericOnly && s.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil { return .string(s) }
        }
        throw ArchiveError.invalid(field)
    }
    public func replacing(_ changes: [String: JSONValue]) throws -> Activity { try Activity(fields: fields.merging(changes) { _, new in new }) }
    public static func manual(id: String, day: String, distance: String, duration: String, existing: Activity? = nil) throws -> Activity {
        if existing?.stravaID != nil { throw ArchiveError.invalid("modifica l’attività su Strava") }
        _ = try CivilDate(day)
        let km = try number(.string(distance), field: "distanza")
        let input = duration.trimmingCharacters(in: .whitespacesAndNewlines)
        let hours: Double
        if input.contains(":") {
            guard input.range(of: #"^\d+:\d{1,2}(:\d{1,2})?$"#, options: .regularExpression) != nil else { throw ArchiveError.invalid("usa HH:MM:SS") }
            let p = input.split(separator: ":").compactMap { Double($0) }
            guard p[1] < 60 && (p.count == 2 || p[2] < 60) else { throw ArchiveError.invalid("minuti o secondi superiori a 59") }
            hours = p[0] + p[1] / 60 + (p.count == 3 ? p[2] / 3600 : 0)
        } else { hours = input.isEmpty ? 0 : try number(.string(input), field: "durata") }
        var f = existing?.fields ?? ["id": .string(id)]
        f.merge(["data": .string(String(day.prefix(10)) + "T00:00:00.000Z"), "distanza": .number(km), "tempo": .number(hours), "media": .number(hours > 0 ? km / hours : 0)]) { _, new in new }
        return try Activity(fields: f)
    }
}

public enum ArchiveCodec {
    public static func validate(_ list: [Activity]) throws -> [Activity] {
        var ids = Set<String>(), strava = Set<String>()
        for a in list {
            guard ids.insert(a.id).inserted else { throw ArchiveError.duplicate(a.id) }
            if let sid = a.stravaID, !strava.insert(sid).inserted { throw ArchiveError.duplicate("Strava " + sid) }
        }
        return list
    }
    public static func decode(_ data: Data) throws -> [Activity] {
        var data = data
        if data.starts(with: [0xef, 0xbb, 0xbf]) { data.removeFirst(3) }
        guard String(data: data, encoding: .utf8) != nil else { throw ArchiveError.invalid("codifica UTF-8") }
        return try validate(JSONDecoder().decode([Activity].self, from: data))
    }
    public static func encode(_ list: [Activity]) throws -> Data {
        _ = try validate(list)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(list)
    }
}
