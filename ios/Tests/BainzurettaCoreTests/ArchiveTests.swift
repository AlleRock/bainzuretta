import XCTest
@testable import BainzurettaCore

final class ArchiveTests: XCTestCase {
    func activity(_ id: Int = 1, date: String = "2026-11-17", km: Double = 50) throws -> Activity {
        try Activity(fields: ["id":.number(Double(id)),"data":.string(date),"distanza":.number(km),"tempo":.number(2),"future":.object(["nested":.array([.bool(true),.null])])])
    }
    func testWebRoundTripUnknownFieldsAndNormalization() throws {
        let raw = Data(#"[{"id":"001","strava_id":"9007199254740991","data":"2026-01-01T00:01:00+14:00","distanza":"42,5","media":25.5,"future":{"nested":[true,null]},"nome":null}]"#.utf8)
        let list = try ArchiveCodec.decode(raw), a = list[0]
        XCTAssertEqual(a.id,"1"); XCTAssertEqual(a.stravaID,"9007199254740991"); XCTAssertEqual(a.hours,42.5/25.5)
        XCTAssertEqual(a.civil.isoDay,"2026-01-01"); XCTAssertEqual(try ArchiveCodec.decode(ArchiveCodec.encode(list)),list)
        XCTAssertEqual(a.fields["future"],.object(["nested":.array([.bool(true),.null])]))
        XCTAssertEqual(try ArchiveCodec.decode(Data([0xef,0xbb,0xbf]) + raw),list)
    }
    func testInvalidInputAndDuplicateIDsAreRejected() throws {
        for date in ["٢٠٢٦-01-01","2026-02-29","2026-13-01","2026-01-01T24:00:00Z","2026-01-01T12:60:00Z","bad"] { XCTAssertThrowsError(try activity(date:date)) }
        for number in [JSONValue.number(-1),.bool(true),.string(""),.string("NaN"),.string("-3")] {
            XCTAssertThrowsError(try Activity(fields:["id":.number(1),"data":.string("2026-01-01"),"distanza":number]))
        }
        let a = try activity(); XCTAssertThrowsError(try ArchiveCodec.validate([a,a]))
        let b = try activity(2).replacing(["strava_id":.number(99)])
        XCTAssertThrowsError(try ArchiveCodec.validate([a.replacing(["strava_id":.number(99)]),b]))
        XCTAssertThrowsError(try ArchiveCodec.decode(Data([0xff])))
        XCTAssertThrowsError(try ArchiveCodec.decode(Data("{}".utf8)))
    }
    func testManualEditRetainsMetadataAndCanBeCancelled() throws {
        let a = try activity(), draft = try Activity.manual(id:a.id,day:"2026-10-25",distance:"30,5",duration:"1:02:03",existing:a)
        XCTAssertEqual(a.distance,50); XCTAssertEqual(draft.distance,30.5); XCTAssertEqual(draft.hours,1+2.0/60+3.0/3600)
        XCTAssertEqual(draft.id,a.id); XCTAssertEqual(draft.fields["future"],a.fields["future"])
        XCTAssertThrowsError(try Activity.manual(id:"2",day:"2026-01-01",distance:"1",duration:"00:60"))
        XCTAssertThrowsError(try Activity.manual(id:"2",day:"2026-01-01",distance:"1",duration:"1",existing:a.replacing(["strava_id":.number(1)])))
    }
    func testPersistenceImportRecoveryRepeatedImportAndFullBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let store = FileArchive(directory:directory)
        var first = Archive(); first.activities = [try activity()]; first.preferences.targets["2026"] = 8000; first.preferences.recordCategory = .cadence
        try store.save(first)
        XCTAssertEqual(try FileArchive(directory:directory).load(),first)
        let web = try ArchiveCodec.encode([activity(2)]), imported = try Archive.importing(web,current:first)
        XCTAssertEqual(imported.preferences,first.preferences)
        try store.save(imported,backup:true); XCTAssertEqual(try store.recovery(),first)
        let repeated = try Archive.importing(web,current:imported); XCTAssertEqual(repeated,imported)
        try store.save(repeated,backup:true); XCTAssertEqual(try store.load().activities.count,1)
        let full = try JSONEncoder().encode(first); XCTAssertEqual(try Archive.importing(full,current:Archive()),first)
        XCTAssertThrowsError(try Archive.importing(Data("bad".utf8),current:first)); XCTAssertEqual(try store.load(),imported)
        try Data("corrupt".utf8).write(to:store.file)
        XCTAssertThrowsError(try store.load()); XCTAssertThrowsError(try store.save(first))
        XCTAssertEqual(String(data:try Data(contentsOf:store.file),encoding:.utf8),"corrupt")
        try store.save(first,allowCorruptRecovery:true); XCTAssertEqual(try store.load(),first)
        try store.reset(); XCTAssertEqual(try store.load(),Archive()); XCTAssertFalse(FileManager.default.fileExists(atPath:store.previous.path))
    }
    func testLeapYearBoundaryWeeksCivilDatesAndYTD() throws {
        XCTAssertEqual(CivilDate.daysInYear(2000),366); XCTAssertEqual(CivilDate.daysInYear(2100),365)
        XCTAssertEqual(try CivilDate("2024-02-29").dayOfYear,60)
        XCTAssertEqual(try CivilDate("2026-01-01T00:01:00+14:00").monday,try CivilDate("2025-12-29T23:59:00Z").monday)
        let today = try CivilDate("2024-12-31"), weeks = Statistics.challenge([],today:today,target:3660)
        XCTAssertEqual(weeks.reduce(0){$0+$1.quota},3660,accuracy:1e-8)
        XCTAssertEqual(weeks.first!.to,today.dayNumber); XCTAssertEqual(weeks.last!.from,try CivilDate("2024-01-01").dayNumber)
        let list = [try activity(1,date:"2023-03-01"),try activity(2,date:"2023-03-02")]
        XCTAssertEqual(Statistics.year(list,2023,ytd:60).map(\.id),["1"])
    }
    func testGoalPaceProjectionPercentAndArrival() throws {
        let date = try CivilDate("2024-07-01"), list = [try activity(km:2000)]
        // Put the synthetic activity in the goal year.
        let data = [try list[0].replacing(["data":.string("2024-06-30")])]
        let goal = Statistics.goal(data,today:date,target:3660)
        XCTAssertEqual(goal.expected,1830); XCTAssertEqual(goal.projection,4000)
        XCTAssertEqual(goal.weeklyRequired,64); XCTAssertEqual(goal.pace,.ahead)
        XCTAssertEqual(goal.progress,2000/3660.0); XCTAssertEqual(goal.arrivalDays!,151.89,accuracy:1e-8)
        XCTAssertEqual(Statistics.goal(data,today:date,target:1500).pace,.achieved)
        XCTAssertEqual(Statistics.goal([],today:date,target:3660).pace,.empty)
        let warning = [try data[0].replacing(["distanza":.number(1700)])]
        XCTAssertEqual(Statistics.goal(warning,today:date,target:3660).pace,.warning)
        let behind = [try data[0].replacing(["distanza":.number(100)])]
        XCTAssertEqual(Statistics.goal(behind,today:date,target:3660).pace,.behind)
        XCTAssertEqual(Display.fixed(1.125,2),"1.13"); XCTAssertEqual(Display.fixed(2.675,2),"2.67"); XCTAssertEqual(Display.fixed(2.625,2),"2.63")
        XCTAssertEqual(Display.time(1e100),"—"); XCTAssertEqual(Display.hours(1e100),"—")
        XCTAssertThrowsError(try Activity.manual(id:"2",day:"2026-01-01",distance:"1",duration:"١:٢٠"))
    }
    func testLargeArchiveAndRecordsPerformance() throws {
        let list = try (0..<12000).map { i in try activity(i+1,date:CivilDate.fromDay(16000+i/3).isoDay,km:Double(i%180)) }
        let encoded = try ArchiveCodec.encode(list); XCTAssertEqual(try ArchiveCodec.decode(encoded).count,12000)
        let start = Date(), engine = RecordEngine(list,today:try CivilDate("2026-11-17"))
        XCTAssertEqual(RecordCategory.allCases.reduce(0){$0+engine.records($1).count},39)
        XCTAssertLessThan(Date().timeIntervalSince(start),20)
    }
}
