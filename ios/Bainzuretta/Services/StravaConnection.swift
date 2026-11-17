import Foundation
import AuthenticationServices
import CryptoKit
import Observation
import UIKit
import BainzurettaCore

struct BrokerConfiguration: Codable {
    var endpoint: URL, pairingKey: String
    init(endpoint: String, pairingKey: String) throws {
        guard let url = URL(string:endpoint.trimmingCharacters(in:.whitespacesAndNewlines)), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil, !pairingKey.isEmpty else { throw StravaError.configuration }
        self.endpoint = url; self.pairingKey = pairingKey
    }
}
struct StravaToken: Codable {
    struct Athlete: Codable { var id: Int64; var firstname: String? }
    var access_token: String, refresh_token: String, expires_at: Double
    var athlete: Athlete?, scope: String?
}

@MainActor @Observable final class StravaConnection: NSObject, ASWebAuthenticationPresentationContextProviding {
    private(set) var connected = false
    private(set) var name = ""
    private(set) var configured = false
    private let secure = SecureStore()
    private var session: ASWebAuthenticationSession?
    private var refreshTask: Task<StravaToken, Error>?
    private var config: BrokerConfiguration?
    private var token: StravaToken?
    var athleteID: String { token?.athlete.map { String($0.id) } ?? "" }
    var endpointText: String { config?.endpoint.absoluteString ?? "" }
    override init() {
        super.init()
        do {
            config = try secure.read(BrokerConfiguration.self,key:"broker")
            token = try secure.read(StravaToken.self,key:"token")
            update()
        } catch { startupError = error.localizedDescription }
    }
    private(set) var startupError: String?
    private func update() { configured = config != nil; connected = token != nil; name = token?.athlete?.firstname ?? "" }
    func configure(endpoint: String, pairingKey: String) throws {
        guard token == nil else { throw ArchiveError.invalid("disconnetti Strava prima di cambiare il collegamento") }
        let c = try BrokerConfiguration(endpoint:endpoint,pairingKey:pairingKey)
        try secure.write(c,key:"broker"); config = c; update()
    }
    private func broker<T: Decodable>(_ route: String, body: [String:String], as type: T.Type) async throws -> T {
        guard let config else { throw StravaError.configuration }
        var request = URLRequest(url:config.endpoint.appendingPathComponent(route)); request.httpMethod = "POST"; request.timeoutInterval = 45
        request.setValue("application/json",forHTTPHeaderField:"Content-Type"); request.setValue("Bearer "+config.pairingKey,forHTTPHeaderField:"Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        let response = try await URLSessionTransport().send(request), data = try response.checked()
        guard let result = try? JSONDecoder().decode(type,from:data) else { throw StravaError.response }
        return result
    }
    private func random() throws -> String {
        var bytes = [UInt8](repeating:0,count:32)
        guard SecRandomCopyBytes(kSecRandomDefault,bytes.count,&bytes) == errSecSuccess else { throw StravaError.configuration }
        return Data(bytes).base64EncodedString().replacingOccurrences(of:"+",with:"-").replacingOccurrences(of:"/",with:"_").replacingOccurrences(of:"=",with:"")
    }
    func connect() async throws {
        struct Start: Decodable { var url: URL, state: String }
        let verifier = try random(), appState = try random()
        let challenge = Data(SHA256.hash(data:Data(verifier.utf8))).base64EncodedString().replacingOccurrences(of:"+",with:"-").replacingOccurrences(of:"/",with:"_").replacingOccurrences(of:"=",with:"")
        let start = try await broker("start",body:["appState":appState,"challenge":challenge],as:Start.self)
        guard start.url.scheme == "https", start.url.host == "www.strava.com" else { throw StravaError.response }
        let callback: URL = try await withCheckedThrowingContinuation { continuation in
            let auth = ASWebAuthenticationSession(url:start.url,callbackURLScheme:"bainzuretta") { url,error in
                if let url { continuation.resume(returning:url) }
                else if let e = error as? ASWebAuthenticationSessionError, e.code == .canceledLogin { continuation.resume(throwing:StravaError.cancelled) }
                else { continuation.resume(throwing:StravaError.network) }
            }
            auth.presentationContextProvider = self; auth.prefersEphemeralWebBrowserSession = true; session = auth
            if !auth.start() { continuation.resume(throwing:StravaError.configuration) }
        }
        session = nil
        guard callback.scheme == "bainzuretta", callback.host == "strava-callback", let parts = URLComponents(url:callback,resolvingAgainstBaseURL:false) else { throw StravaError.auth }
        let query = parts.queryItems ?? []
        func value(_ name: String) -> String? { query.first { $0.name == name }?.value }
        guard value("state") == start.state else { throw StravaError.auth }
        if let error = value("error") { throw error == "scope" ? StravaError.scope : StravaError.cancelled }
        guard let code = value("code"), let scope = value("scope"), scope.components(separatedBy:CharacterSet(charactersIn:", ")).contains("activity:read_all") else { throw StravaError.scope }
        var next = try await broker("exchange",body:["code":code,"state":start.state,"verifier":verifier],as:StravaToken.self)
        next.scope = scope; try save(next)
    }
    private func save(_ next: StravaToken) throws {
        guard !next.access_token.isEmpty, !next.refresh_token.isEmpty, next.expires_at.isFinite, next.expires_at > 0 else { throw StravaError.response }
        try secure.write(next,key:"token"); token = next; update()
    }
    func accessToken(forceRefresh: Bool = false) async throws -> String {
        guard let current = token else { throw StravaError.auth }
        if !forceRefresh && current.expires_at > Date().timeIntervalSince1970 + 300 { return current.access_token }
        if let refreshTask { return try await refreshTask.value.access_token }
        let task = Task { @MainActor in
            var next = try await broker("refresh",body:["refresh_token":current.refresh_token],as:StravaToken.self)
            next.athlete = next.athlete ?? current.athlete; next.scope = current.scope
            try save(next); return next
        }
        refreshTask = task
        defer { refreshTask = nil }
        do { return try await task.value.access_token }
        catch let e as StravaError where e == .auth { try secure.delete("token"); token = nil; update(); throw e }
    }
    func disconnect(revoke: Bool = false) async throws {
        if revoke {
            let token = try await accessToken()
            var request = URLRequest(url:URL(string:"https://www.strava.com/oauth/deauthorize")!); request.httpMethod = "POST"
            request.setValue("Bearer "+token,forHTTPHeaderField:"Authorization")
            let response = try await URLSessionTransport().send(request); _ = try response.checked()
        }
        try secure.delete("token"); token = nil; update()
    }
    func reset() throws {
        // Only Bainzuretta accounts; no broad Keychain clearing.
        try secure.delete("token"); try secure.delete("broker"); token = nil; config = nil; update()
    }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
