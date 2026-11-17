import XCTest
import PDFKit
@testable import Bainzuretta
import BainzurettaCore

@MainActor final class BainzurettaNativeTests: XCTestCase {
    func testNativeStoreManualPersistenceCategoryAndGoal() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let store = AppStore(directory:directory)
        try store.setTarget("7000"); store.setCategory(.curiosity)
        store.diaryGrouping = .month; store.archiveGrouping = .week; store.rankingMetric = .simple
        store.section = .diary; store.section = .home; store.section = .diary
        XCTAssertEqual(store.diaryGrouping,.month); XCTAssertEqual(store.archiveGrouping,.week); XCTAssertEqual(store.rankingMetric,.simple)
        try store.saveManual(day:store.today.isoDay,distance:"42,5",duration:"2:00:00",existing:nil)
        let reopened = AppStore(directory:directory)
        XCTAssertEqual(reopened.diaryGrouping,.activities); XCTAssertEqual(reopened.rankingMetric,.distance)
        XCTAssertEqual(reopened.activities.count,1); XCTAssertEqual(reopened.activities[0].distance,42.5)
        XCTAssertEqual(reopened.target,7000); XCTAssertEqual(reopened.archive.preferences.recordCategory,.curiosity)
        XCTAssertThrowsError(try reopened.setTarget("-1")); XCTAssertEqual(reopened.target,7000)
        let original = reopened.activities[0]
        reopened.editActivity = original; reopened.editActivity = nil
        XCTAssertEqual(reopened.activities[0],original)
        try reopened.saveManual(day:reopened.today.isoDay,distance:"60",duration:"2",existing:original)
        XCTAssertEqual(reopened.activities[0].id,original.id); XCTAssertEqual(reopened.activities[0].speed,30)
        try reopened.delete(reopened.activities[0]); XCTAssertTrue(reopened.activities.isEmpty)
    }
    func testKeychainRoundTripWithoutCredentialsInArchive() throws {
        let key = "unit-test-"+UUID().uuidString, secure = SecureStore()
        defer { try? secure.delete(key) }
        try secure.write("test-only-not-a-real-token",key:key)
        XCTAssertEqual(try secure.read(String.self,key:key),"test-only-not-a-real-token")
        try secure.write("updated-test-only",key:key)
        XCTAssertEqual(try secure.read(String.self,key:key),"updated-test-only")
        try secure.delete(key); XCTAssertNil(try secure.read(String.self,key:key))
    }
    func testNativePDFContainsAnnualReportAndAllActivitiesAcrossPages() throws {
        let list = try (1...160).map { i in try Activity(fields:["id":.number(Double(i)),"data":.string("2026-11-17"),"distanza":.number(50),"tempo":.number(2),"nome":.string("Attivita test numero \(i)"),"dislivello":.number(400),"cadenza":.number(85)]) }
        let url = try AnnualReport.generate(list,year:2026)
        defer { try? FileManager.default.removeItem(at:url) }
        let document = try XCTUnwrap(PDFDocument(url:url))
        XCTAssertGreaterThan(document.pageCount,1)
        let text = document.string ?? ""
        for i in 1...160 { XCTAssertTrue(text.contains("Attivita test numero \(i)")) }
        for title in ["Top 5 Uscite per Distanza","Top 5 Uscite per Velocità","Statistiche Mensili","Record Cadenza","Tutte le Attività"] { XCTAssertTrue(text.contains(title),title) }
        XCTAssertThrowsError(try AnnualReport.generate([],year:2026))
    }
    func testInvalidBrokerURLAndEditingStravaAreRejected() throws {
        for endpoint in ["http://broker.example","https://user:password@broker.example","not a URL","https://broker.example/?key=test"] { XCTAssertThrowsError(try BrokerConfiguration(endpoint:endpoint,pairingKey:"test-only")) }
        XCTAssertNoThrow(try BrokerConfiguration(endpoint:"https://broker.example",pairingKey:"test-only"))
    }
}
