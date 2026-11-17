import XCTest
@testable import BainzurettaCore

final class EquivalenceTests: XCTestCase {
    struct Fixture: Decodable {
        let name: String, now: String, target: Double, activities: [Activity], home: Home
        let challenge: [Week], records: [String: [Record]], ranking: [String: [Rank]], groups: [[Group]]
        struct Home: Decodable { let total: Double, km: Double, bestYear: Int?, bestSpeed: Double, remaining: Double, projection: Double, weekly: Double }
        struct Week: Decodable { let number: Int, from: Int, to: Int, quota: Double, km: Double, current: Bool }
        struct Record: Decodable {
            let title: String, value: String, subtitle: String, all: Bool, entries: [Entry]
            struct Entry: Decodable { let title: String, subtitle: String, value: String, id: String? }
        }
        struct Rank: Decodable { let year: Int, value: Double, total: Double }
        struct Group: Decodable { let key: String, km: Double, hours: Double, elevation: Double, count: Int, ids: [String] }
    }
    func fixtures() throws -> [Fixture] {
        let url = Bundle.module.url(forResource: "oracle", withExtension: "json", subdirectory: "Fixtures")!
        return try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: url))
    }
    func testStatisticsAgainstActualJavaScript() throws {
        for f in try fixtures() {
            let today = CivilDate.today(Date(timeIntervalSince1970: StravaSync.instant(f.now)!), zone: TimeZone(identifier: "Europe/Rome")!)
            let goal = Statistics.goal(f.activities, today: today, target: f.target)
            XCTAssertEqual(Summary(f.activities).km, f.home.total, accuracy: 1e-7, f.name)
            XCTAssertEqual(goal.km, f.home.km, accuracy: 1e-7, f.name)
            XCTAssertEqual(goal.remaining, f.home.remaining, accuracy: 1e-7, f.name)
            XCTAssertEqual(goal.projection, f.home.projection, f.name)
            XCTAssertEqual(goal.weeklyRequired, f.home.weekly, f.name)
            let best = Statistics.bestSpeedYear(f.activities)
            XCTAssertEqual(best.0, f.home.bestYear, f.name); XCTAssertEqual(best.1, f.home.bestSpeed, accuracy: 1e-7, f.name)
            for (metric, js) in [(RankingMetric.distance,"distanza"),(.weighted,"ponderata"),(.simple,"media"),(.elevation,"dislivello")] {
                let ranks = Statistics.ranking(f.activities, today: today, metric: metric), expected = f.ranking[js]!
                XCTAssertEqual(ranks.count, expected.count)
                for (a, b) in zip(ranks, expected) {
                    XCTAssertEqual(a.year, b.year, f.name); XCTAssertEqual(a.value, b.value, accuracy: 1e-7, f.name); XCTAssertEqual(a.total, b.total, accuracy: 1e-7, f.name)
                }
            }
            let weeks = Statistics.challenge(f.activities, today: today, target: f.target)
            XCTAssertEqual(weeks.count, f.challenge.count, f.name)
            for (a, b) in zip(weeks, f.challenge) {
                XCTAssertEqual(a.number, b.number); XCTAssertEqual(a.from, b.from); XCTAssertEqual(a.to, b.to)
                XCTAssertEqual(a.quota, b.quota, accuracy: 1e-8); XCTAssertEqual(a.km, b.km, accuracy: 1e-7); XCTAssertEqual(a.current, b.current)
            }
            for (i, mode) in [Grouping.month, .week].enumerated() {
                let groups = Statistics.groups(f.activities, by: mode)
                XCTAssertEqual(groups.count, f.groups[i].count)
                for (a,b) in zip(groups, f.groups[i]) {
                    XCTAssertEqual(a.id, b.key); XCTAssertEqual(a.summary.km, b.km, accuracy: 1e-7)
                    XCTAssertEqual(a.summary.computedHours, b.hours, accuracy: 1e-7)
                    XCTAssertEqual(a.summary.elevation, b.elevation, accuracy: 1e-7)
                    XCTAssertEqual(a.summary.count, b.count); XCTAssertEqual(a.items.map(\.id), b.ids)
                }
            }
        }
    }
    func testAll39RecordsAndEveryTop5AgainstActualJavaScript() throws {
        for f in try fixtures() {
            let today = CivilDate.today(Date(timeIntervalSince1970: StravaSync.instant(f.now)!), zone: TimeZone(identifier: "Europe/Rome")!)
            let engine = RecordEngine(f.activities, today: today)
            for c in RecordCategory.allCases {
                let result = engine.records(c), expected = f.records[c.rawValue]!
                XCTAssertEqual(result.count, expected.count, "\(f.name) \(c)")
                for (a,b) in zip(result, expected) {
                    let label = "\(f.name) / \(a.title)"
                    XCTAssertEqual(a.title,b.title,label); XCTAssertEqual(a.value,b.value,label); XCTAssertEqual(a.all,b.all,label); XCTAssertEqual(a.subtitle,b.subtitle,label)
                    XCTAssertEqual(a.entries.count,b.entries.count,label)
                    for (x,y) in zip(a.entries,b.entries) {
                        XCTAssertEqual(x.title,y.title,label); XCTAssertEqual(x.subtitle,y.subtitle,label); XCTAssertEqual(x.value,y.value,label); XCTAssertEqual(x.activity?.id,y.id,label)
                    }
                }
            }
        }
    }
}
