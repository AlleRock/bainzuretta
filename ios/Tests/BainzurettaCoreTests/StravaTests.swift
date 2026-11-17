import XCTest
@testable import BainzurettaCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

actor MockTransport: HTTPTransport {
    var responses: [HTTPResponse], requests: [URLRequest] = []
    init(_ responses: [HTTPResponse]) { self.responses = responses }
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        requests.append(request)
        guard !responses.isEmpty else { throw StravaError.network }
        return responses.removeFirst()
    }
}
final class StravaTests: XCTestCase {
    func raw(_ id: Int, type: String = "Ride") -> [String:JSONValue] {
        ["id":.number(Double(id)),"type":.string(type),"distance":.number(42501),"moving_time":.number(7201),"start_date_local":.string("2026-11-01T00:01:00Z"),"start_date":.string("2026-10-31T23:01:00Z"),"name":.string("Test"),"total_elevation_gain":.number(450),"average_cadence":.number(84)]
    }
    func response(_ acts: [[String:JSONValue]]) throws -> HTTPResponse { HTTPResponse(data:try JSONEncoder().encode(acts),status:200) }
    func testPaginationFiltersAndDuplicates() async throws {
        var page = (1...98).map { raw($0) }; page += [raw(99,type:"Run"),raw(1)]
        let transport = MockTransport([try response(page),try response([raw(100,type:"MountainBikeRide"),raw(101,type:"GravelRide")])])
        let window = SyncWindow(after:12,before:99,athlete:"1")
        let list = try await StravaRemote(transport:transport).download(token:"test-only",window:window)
        XCTAssertEqual(list.count,99); XCTAssertEqual(list[0].distance,42.5); XCTAssertEqual(list[0].hours,2.0003); XCTAssertEqual(list[0].speed,21.25)
        let requests = await transport.requests; XCTAssertEqual(requests.count,2)
        XCTAssertTrue(requests[1].url!.absoluteString.contains("page=2")); XCTAssertTrue(requests[1].url!.absoluteString.contains("before=99"))
    }
    func testNetworkErrorsMalformedResponsesAndNoPartialCommit() async throws {
        for status in [401,403,429,500] {
            let transport = MockTransport([HTTPResponse(data:Data(),status:status)])
            do { _ = try await StravaRemote(transport:transport).download(token:"test",window:SyncWindow(after:0,before:100,athlete:"1")); XCTFail("expected error") }
            catch { XCTAssertEqual(error as? StravaError,status == 429 ? .rateLimit : status == 500 ? .response : .auth) }
        }
        for responses in [[HTTPResponse(data:Data("{}".utf8),status:200)], [try response((1...100).map{raw($0)})]] {
            do { _ = try await StravaRemote(transport:MockTransport(responses)).download(token:"test",window:SyncWindow(after:0,before:100,athlete:"1")); XCTFail("expected error") } catch {}
        }
    }
    func testResyncPreservesIDsMetadataAndDeletionRequiresDecision() throws {
        let a = try StravaRemote.activity(raw(1)).replacing(["id":.string("original"),"future":.bool(true)]), b = try StravaRemote.activity(raw(2))
        let window = SyncWindow(after:1_790_000_000,before:1_800_000_000,athlete:"1")
        let changed = try a.replacing(["distanza":.number(100)])
        let result = try StravaSync.merge(existing:[a,b],downloaded:[changed],window:window,resync:true)
        XCTAssertEqual(result.updated,1); XCTAssertEqual(result.activities.count,2); XCTAssertEqual(result.activities[0].id,"original")
        XCTAssertEqual(result.activities[0].fields["future"],.bool(true))
        XCTAssertEqual(result.missing.count,1); XCTAssertEqual(result.removingMissing().count,1)
        let empty = try StravaSync.merge(existing:[a,b],downloaded:[],window:window,resync:true)
        XCTAssertTrue(empty.missing.isEmpty); XCTAssertEqual(empty.activities.count,2)
    }
    func testIncrementalAndCollisionSafety() throws {
        let remote = try StravaRemote.activity(raw(1)), manual = try remote.replacing(["strava_id":.null])
        let window = SyncWindow(after:0,before:1_800_000_000,athlete:"1")
        let result = try StravaSync.merge(existing:[manual],downloaded:[remote,remote],window:window,resync:false)
        XCTAssertEqual(result.added,1); XCTAssertEqual(result.activities.map(\.id),["1","strava_1"])
        XCTAssertEqual(try StravaSync.merge(existing:result.activities,downloaded:[remote],window:window,resync:false).added,0)
        XCTAssertEqual(StravaSync.incrementalAfter([remote]),Int64(StravaSync.instant(remote.utc!)!)-86400)
    }
}
