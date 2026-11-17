import Foundation

public enum Grouping: String, CaseIterable, Identifiable, Codable, Sendable {
    case activities, month, week
    public var id: String { rawValue }
    public var title: String { switch self { case .activities: return "Attività"; case .month: return "Mese"; case .week: return "Settimana" } }
}
public struct Summary: Codable, Equatable, Sendable {
    public var km = 0.0, storedHours = 0.0, weightedKm = 0.0, computedHours = 0.0, speedSum = 0.0, elevation = 0.0
    public var count = 0
    public init(_ items: [Activity]) {
        for a in items {
            km += a.distance; storedHours += a.hours; speedSum += a.speed; elevation += a.elevation; count += 1
            if a.distance > 0 && a.speed > 0 { weightedKm += a.distance; computedHours += a.distance / a.speed }
        }
    }
    public var weightedSpeed: Double { computedHours > 0 ? weightedKm / computedHours : 0 }
    public var simpleSpeed: Double { count > 0 ? speedSum / Double(count) : 0 }
    public var reportSpeed: Double { storedHours > 0 ? km / storedHours : 0 }
}
public struct ActivityGroup: Identifiable, Sendable {
    public let id: String, label: String
    public let items: [Activity]
    public let summary: Summary
    public var speed: Double { summary.computedHours > 0 ? summary.km / summary.computedHours : 0 }
}
public enum RankingMetric: String, CaseIterable, Identifiable, Sendable {
    case distance, weighted, simple, elevation
    public var id: String { rawValue }
    public var title: String {
        switch self { case .distance: return "Distanza Totale (KM)"; case .weighted: return "Media Ponderata (KM Tot / Ore Tot)"; case .simple: return "Media Semplice (KM/H)"; case .elevation: return "Dislivello Totale (m) — dal 2019" }
    }
    public var unit: String { self == .distance ? "km" : self == .elevation ? "m" : "km/h" }
}
public struct RankingEntry: Identifiable, Sendable {
    public let year: Int, value: Double, total: Double
    public var id: Int { year }
}
public struct Goal: Sendable {
    public enum Pace: String, Sendable { case empty, ahead, warning, behind, achieved }
    public let target: Double, km: Double, remaining: Double, projection: Double, weeklyRequired: Double, expected: Double, delta: Double
    public let arrivalDays: Double?, pace: Pace
    public var progress: Double { target > 0 ? km / target : 0 }
}
public struct ChallengeWeek: Identifiable, Sendable {
    public let number: Int, from: Int, to: Int, quota: Double, km: Double, current: Bool
    public var id: Int { from }
    public var delta: Double { km - quota }
    public var label: String { "\(CivilDate.fromDay(from).display.prefix(5)) – \(CivilDate.fromDay(to).display.prefix(5))" }
}
public enum Statistics {
    public static func year(_ data: [Activity], _ year: Int, ytd: Int? = nil) -> [Activity] {
        data.filter { $0.civil.year == year && (ytd == nil || $0.civil.dayOfYear <= ytd!) }
            .enumerated().sorted { $0.element.civil == $1.element.civil ? $0.offset < $1.offset : $0.element.civil > $1.element.civil }.map(\.element)
    }
    public static func groups(_ data: [Activity], by: Grouping) -> [ActivityGroup] {
        var order = [String](), groups = [String: [Activity]]()
        for a in data {
            let key = by == .month ? a.civil.isoMonth : CivilDate.fromDay(a.civil.monday).isoDay
            if groups[key] == nil { order.append(key) }; groups[key, default: []].append(a)
        }
        return order.sorted(by: >).map { key in
            let items = groups[key]!
            let date = try! CivilDate(key.count == 7 ? key + "-01" : key)
            let label = by == .month ? "\(Display.months[date.month - 1]) \(date.year)" : "\(date.display.prefix(5)) – \(CivilDate.fromDay(date.dayNumber + 6).display.prefix(5))"
            return ActivityGroup(id: key, label: label, items: items, summary: Summary(items))
        }
    }
    public static func ranking(_ data: [Activity], today: CivilDate, metric: RankingMetric) -> [RankingEntry] {
        let years = Set(data.map { $0.civil.year }).sorted()
        return years.filter { metric != .elevation || $0 >= 2019 }.map { year in
            let all = data.filter { $0.civil.year == year }, ytd = Summary(all.filter { $0.civil.dayOfYear <= today.dayOfYear })
            let value: Double
            switch metric { case .distance: value = ytd.km; case .weighted: value = ytd.weightedSpeed; case .simple: value = ytd.simpleSpeed; case .elevation: value = ytd.elevation }
            return RankingEntry(year: year, value: value, total: Summary(all).km)
        }.sorted { $0.value == $1.value ? $0.year < $1.year : $0.value > $1.value }
    }
    public static func bestSpeedYear(_ data: [Activity]) -> (Int?, Double) {
        var best: (Int?, Double) = (nil, 0)
        for year in Set(data.map { $0.civil.year }).sorted() {
            let list = data.filter { $0.civil.year == year && $0.speed > 0 }
            let average = list.isEmpty ? 0 : list.reduce(0) { $0 + $1.speed } / Double(list.count)
            if average > best.1 { best = (year, average) }
        }
        return best
    }
    public static func goal(_ data: [Activity], today: CivilDate, target: Double) -> Goal {
        let km = Summary(data.filter { $0.civil.year == today.year }).km
        let days = Double(CivilDate.daysInYear(today.year)), doy = Double(today.dayOfYear)
        let remaining = max(0, target - km), expected = target / days * doy, delta = km - expected
        let pace: Goal.Pace = km <= 0 || target <= 0 ? .empty : remaining <= 0 ? .achieved : delta >= 0 ? .ahead : delta / expected >= -0.1 ? .warning : .behind
        return Goal(target: target, km: km, remaining: remaining, projection: floor(km / max(1, doy) * days + 0.5),
                    weeklyRequired: ceil(remaining / (max(1, days - doy) / 7)), expected: expected, delta: delta,
                    arrivalDays: km > 0 && remaining > 0 ? remaining / km * doy : nil, pace: pace)
    }
    public static func challenge(_ data: [Activity], today: CivilDate, target: Double) -> [ChallengeWeek] {
        let first = CivilDate.dayNumber(year: today.year, month: 1, day: 1), last = CivilDate.dayNumber(year: today.year, month: 12, day: 31)
        let firstMonday = CivilDate.fromDay(first).monday, lastMonday = CivilDate.fromDay(last).monday
        var km = [Int: Double]()
        for a in data where a.civil.year == today.year { km[a.civil.monday, default: 0] += a.distance }
        return stride(from: min(today.monday, lastMonday), through: firstMonday, by: -7).map { monday in
            let from = max(monday, first), to = min(monday + 6, last)
            return ChallengeWeek(number: (monday - firstMonday) / 7 + 1, from: from, to: to,
                                 quota: target / Double(CivilDate.daysInYear(today.year)) * Double(to - from + 1), km: km[monday] ?? 0, current: monday == today.monday)
        }
    }
}
