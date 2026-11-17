import Foundation

public enum RecordCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case distance = "dist", speed = "vel", time = "tempo", elevation = "disliv", cadence = "cad", consistency = "cost", curiosity = "cur"
    public var id: String { rawValue }
    public var title: String {
        switch self { case .distance: return "DISTANZA"; case .speed: return "VELOCITÀ"; case .time: return "TEMPO"; case .elevation: return "DISLIVELLO"; case .cadence: return "CADENZA"; case .consistency: return "COSTANZA"; case .curiosity: return "CURIOSITÀ" }
    }
    public var note: String { self == .elevation ? "Dislivello considerato dal 2019" : self == .cadence ? "Solo attività con dato di cadenza" : "" }
}
public struct RecordEntry: Identifiable, Equatable, Sendable {
    public var title: String, subtitle: String = "", value: String, numeric: Double, activity: Activity? = nil
    public var id: String { title + "|" + (activity?.id ?? subtitle) }
}
public struct CyclingRecord: Identifiable, Sendable {
    public var title: String, emoji: String, entries: [RecordEntry], all = false, override: String? = nil, subtitle: String = ""
    public var id: String { title }
    public var value: String { override ?? entries.first?.value ?? "—" }
}

public struct RecordEngine: Sendable {
    public let data: [Activity], today: CivilDate
    public init(_ data: [Activity], today: CivilDate) { self.data = data; self.today = today }
    func stable<T>(_ list: [T], key: (T) -> Double) -> [T] {
        list.enumerated().sorted { key($0.element) == key($1.element) ? $0.offset < $1.offset : key($0.element) > key($1.element) }.map(\.element)
    }
    func activity(_ items: [Activity], key: (Activity) -> Double, value: (Activity) -> String, includeKM: Bool = false, density: Bool = false, all: Bool = false) -> [RecordEntry] {
        let list = stable(items, key: key)
        return (all ? list : Array(list.prefix(5))).map { a in
            var parts = a.name.isEmpty ? [] : [a.name]
            if includeKM { parts.append(Display.number(a.distance, 1) + " km" + (density ? " · \(Display.number(a.elevation, 0)) m" : "")) }
            return RecordEntry(title: a.civil.display, subtitle: parts.joined(separator: " · "), value: value(a), numeric: key(a), activity: a)
        }
    }
    func weekLabel(_ week: Int) -> String { "\(CivilDate.fromDay(4 + week * 7).display) – \(CivilDate.fromDay(10 + week * 7).display)" }
    func groups(_ items: [Activity], kind: Grouping?, key: (Activity) -> Double, value: (Double) -> String) -> [RecordEntry] {
        var sums = [String: Double](), order = [String]()
        for a in items {
            let k = kind == .week ? String(a.civil.absoluteWeek) : kind == .month ? a.civil.isoMonth : String(a.civil.year)
            if sums[k] == nil { order.append(k) }; sums[k, default: 0] += key(a)
        }
        // JS Object.keys enumerates nonnegative integer keys first, ascending.
        if kind == nil || kind == .week { order.sort { (Int($0) ?? 0) < (Int($1) ?? 0) } }
        return stable(order, key: { sums[$0]! }).prefix(5).map { k in
            let label = kind == .week ? weekLabel(Int(k)!) : kind == .month ? "\(Display.months[Int(k.suffix(2))! - 1]) \(k.prefix(4))" : k
            return RecordEntry(title: label, value: value(sums[k]!), numeric: sums[k]!)
        }
    }
    func range(_ min: Double, _ max: Double? = nil, inclusive: Bool = false) -> [Activity] {
        data.filter { $0.distance >= min && (max == nil || (inclusive ? $0.distance <= max! : $0.distance < max!)) }
    }
    func rolling(_ days: Int) -> [RecordEntry] {
        var sums = [Int: Double]()
        for a in data { sums[a.civil.dayNumber, default: 0] += a.distance }
        let daysSorted = sums.keys.sorted()
        var windows = [(from: Int, to: Int, km: Double)]()
        // At most N unique civil days per window. Match the original summation order exactly.
        for (i, start) in daysSorted.enumerated() {
            var total = 0.0, j = i
            while j < daysSorted.count && daysSorted[j] < start + days { total += sums[daysSorted[j]]!; j += 1 }
            windows.append((start, start + days - 1, total))
        }
        var top = [(from: Int, to: Int, km: Double)]()
        for w in stable(windows, key: { $0.km }) {
            if !top.contains(where: { w.from <= $0.to && w.to >= $0.from }) { top.append(w) }
            if top.count == 5 { break }
        }
        return top.map { RecordEntry(title: "dal \(CivilDate.fromDay($0.from).display) al \(CivilDate.fromDay($0.to).display)", value: "\(Display.number($0.km, 0)) km", numeric: $0.km) }
    }
    public func records(_ category: RecordCategory) -> [CyclingRecord] {
        guard !data.isEmpty else { return [] }
        func r(_ emoji: String, _ title: String, _ entries: [RecordEntry], all: Bool = false, override: String? = nil, subtitle: String = "") -> CyclingRecord {
            CyclingRecord(title: title, emoji: emoji, entries: entries, all: all, override: override, subtitle: subtitle)
        }
        let km: (Activity) -> Double = { $0.distance }, speed: (Activity) -> Double = { $0.speed }
        let kmValue: (Activity) -> String = { "\(Display.number($0.distance, 1)) km" }
        let cadence: (Activity) -> Double = { $0.cadence }, cadenceValue: (Activity) -> String = { "\(Display.number($0.cadence, 1)) rpm" }
        let kmGroup: (Double) -> String = { "\(Display.number($0, 0)) km" }
        switch category {
        case .distance:
            let l100 = range(100), l150 = range(150)
            return [r("🏆", "Giro più lungo", activity(data, key: km, value: kmValue)),
                    r("💯", "Uscite ≥100 km", activity(l100, key: km, value: kmValue, all: true), all: true, override: "\(l100.count) uscite"),
                    r("🚀", "Uscite ≥150 km", activity(l150, key: km, value: kmValue, all: true), all: true, override: "\(l150.count) uscite"),
                    r("📅", "Settimana con più km", groups(data, kind: .week, key: km, value: kmGroup)),
                    r("🗓️", "Mese con più km", groups(data, kind: .month, key: km, value: kmGroup)),
                    r("🏅", "Anno con più km", groups(data, kind: nil, key: km, value: kmGroup)),
                    r("🔄", "Max km in 7 giorni mobili", rolling(7))]
        case .speed:
            let titles = ["Media più alta in assoluto", "Media più alta su uscite 30–49,9 km", "Media più alta su uscite 50–99,9 km", "Media più alta su uscite ≥100 km", "Miglior media su uscite 50–60 km", "Miglior media su uscite 100–110 km"]
            let lists = [data, range(30, 50), range(50, 100), range(100), range(50, 60, inclusive: true), range(100, 110, inclusive: true)]
            return zip(titles, lists).enumerated().map { i, pair in
                r(i == 0 ? "⚡" : i >= 4 ? "🎯" : "🚴", pair.0, activity(pair.1.filter { $0.speed > 0 }, key: speed, value: { "\(Display.fixed($0.speed, 2)) km/h" }, includeKM: true))
            }
        case .time:
            return [r("⏱️", "Uscita più lunga", activity(data, key: { $0.hours }, value: { Display.time($0.hours) }, includeKM: true))] +
                [(Grouping.week, "📅", "Settimana"), (.month, "🗓️", "Mese")].map { kind, emoji, title in r(emoji, title + " con più ore in sella", groups(data, kind: kind, key: { $0.hours }, value: Display.hours)) } +
                [r("🏅", "Anno con più ore in sella", groups(data, kind: nil, key: { $0.hours }, value: Display.hours))]
        case .elevation:
            let list = data.filter { $0.civil.year >= 2019 && $0.elevation > 0 }
            let val: (Double) -> String = { "\(Display.number($0, 0)) m" }
            return [r("🏔️", "Più dislivello in un’uscita", activity(list, key: { $0.elevation }, value: { val($0.elevation) }, includeKM: true)),
                    r("📈", "Maggior densità di salita (min 20 km)", activity(list.filter { $0.distance >= 20 }, key: { $0.elevation / $0.distance }, value: { "\(Display.number($0.elevation / $0.distance, 1)) m D+/km" }, includeKM: true, density: true)),
                    r("📅", "Settimana con più dislivello", groups(list, kind: .week, key: { $0.elevation }, value: val)),
                    r("🗓️", "Mese con più dislivello", groups(list, kind: .month, key: { $0.elevation }, value: val)),
                    r("🏅", "Anno con più dislivello", groups(list, kind: nil, key: { $0.elevation }, value: val))]
        case .cadence:
            let titles = ["Cadenza media più alta", "Cadenza media più alta su uscite 30–49,9 km", "Cadenza media più alta su uscite 50–99,9 km", "Cadenza media più alta su uscite ≥100 km"]
            var result = zip(titles, [data, range(30, 50), range(50, 100), range(100)]).map { title, list in r("🦵", title, activity(list.filter { $0.cadence > 0 }, key: cadence, value: cadenceValue, includeKM: true)) }
            let list = data.filter { $0.cadence > 0 }
            let years = Set(list.map { $0.civil.year }).sorted()
            let entries = years.map { year -> RecordEntry in
                let acts = list.filter { $0.civil.year == year }, v = acts.reduce(0) { $0 + $1.cadence } / Double(acts.count)
                return RecordEntry(title: String(year), subtitle: "\(acts.count) uscite con dato", value: "\(Display.number(v, 1)) rpm", numeric: v)
            }
            result.append(r("🏅", "Anno con cadenza media più alta", Array(stable(entries, key: { $0.numeric }).prefix(5))))
            return result
        case .consistency:
            let weeks = Set(data.map { $0.civil.absoluteWeek }).sorted()
            var streaks = [(start: Int, end: Int, len: Int)]()
            var start = weeks[0], previous = weeks[0]
            for week in weeks.dropFirst() {
                if week != previous + 1 { streaks.append((start, previous, previous - start + 1)); start = week }; previous = week
            }
            streaks.append((start, previous, previous - start + 1))
            let entries = stable(streaks, key: { Double($0.len) }).prefix(5).map { s in
                RecordEntry(title: "dal \(CivilDate.fromDay(4 + s.start * 7).display) al \(CivilDate.fromDay(10 + s.end * 7).display)", value: "\(s.len) sett.", numeric: Double(s.len))
            }
            var current = 0, week = today.absoluteWeek; let set = Set(weeks)
            while set.contains(week) { current += 1; week -= 1 }
            let countValue: (Double) -> String = { "\(Int($0)) uscite" }
            return [r("🔥", "Striscia più lunga di settimane consecutive", entries),
                    r("⏳", "Striscia attuale", [], override: current > 0 ? "\(current) sett." : "—", subtitle: current > 0 ? "dal \(CivilDate.fromDay(4 + (today.absoluteWeek - current + 1) * 7).display)" : ""),
                    r("📅", "Settimana con più uscite", groups(data, kind: .week, key: { _ in 1 }, value: countValue)),
                    r("🗓️", "Mese con più uscite", groups(data, kind: .month, key: { _ in 1 }, value: countValue)),
                    r("🏅", "Anno con più uscite", groups(data, kind: nil, key: { _ in 1 }, value: countValue))]
        case .curiosity:
            func counts(_ key: (Activity) -> Int, names: [String]) -> [RecordEntry] {
                var counts = [Int: Double](); for a in data { counts[key(a), default: 0] += 1 }
                return stable(counts.keys.sorted(), key: { counts[$0]! }).prefix(5).map { RecordEntry(title: names[$0], value: "\(Int(counts[$0]!)) uscite", numeric: counts[$0]!) }
            }
            let first = data.min { $0.dateText < $1.dateText }!.civil
            let months = (today.year - first.year) * 12 + today.month - first.month + 1
            return [r("📆", "Giorno della settimana più pedalato", counts({ $0.civil.weekday }, names: Display.weekdays)),
                    r("🌱", "Mese dell’anno più pedalato", counts({ $0.civil.month - 1 }, names: Display.months)),
                    r("🔥", "Max km in 4 giorni", rolling(4)),
                    r("📏", "Media km per uscita", [], override: "\(Display.number(Summary(data).km / Double(data.count), 1)) km"),
                    r("📊", "Media uscite per mese", [], override: "\(Display.number(Double(data.count) / Double(max(1, months)), 1)) uscite"),
                    r("💯", "Numero di uscite ≥100 km", [], override: String(range(100).count)),
                    r("🚀", "Numero di uscite ≥150 km", [], override: String(range(150).count))]
        }
    }
}
