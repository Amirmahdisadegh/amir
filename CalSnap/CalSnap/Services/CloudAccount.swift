import Foundation
import Observation

/// Email account + cloud backup using Firebase Auth & Firestore REST APIs.
/// No SDK / no plist — the user supplies a Web API key and project ID.
@Observable
final class CloudAccount {

    var email: String?          // signed-in email (nil = signed out)
    var projectID: String {
        didSet { UserDefaults.standard.set(projectID, forKey: K.project) }
    }
    var lastSync: Date? {
        didSet { UserDefaults.standard.set(lastSync, forKey: K.lastSync) }
    }
    var status: String?         // last message / error for the UI
    var busy = false

    private var idToken: String?

    var apiKey: String? {
        get { KeychainService.shared.read(key: K.apiKey) }
        set {
            if let v = newValue, !v.isEmpty { KeychainService.shared.save(key: K.apiKey, value: v) }
            else { KeychainService.shared.delete(key: K.apiKey) }
        }
    }
    private var refreshToken: String? {
        get { KeychainService.shared.read(key: K.refresh) }
        set {
            if let v = newValue { KeychainService.shared.save(key: K.refresh, value: v) }
            else { KeychainService.shared.delete(key: K.refresh) }
        }
    }
    private var localId: String? {
        get { UserDefaults.standard.string(forKey: K.localId) }
        set { UserDefaults.standard.set(newValue, forKey: K.localId) }
    }

    var isConfigured: Bool { !(apiKey?.isEmpty ?? true) && !projectID.isEmpty }
    var isSignedIn: Bool { email != nil && refreshToken != nil }

    init() {
        projectID = UserDefaults.standard.string(forKey: K.project) ?? ""
        email = UserDefaults.standard.string(forKey: K.email)
        lastSync = UserDefaults.standard.object(forKey: K.lastSync) as? Date
    }

    // MARK: Auth

    @MainActor
    func signUp(email: String, password: String) async -> Bool {
        await authenticate(endpoint: "signUp", email: email, password: password)
    }

    @MainActor
    func signIn(email: String, password: String) async -> Bool {
        await authenticate(endpoint: "signInWithPassword", email: email, password: password)
    }

    func signOut() {
        email = nil
        refreshToken = nil
        localId = nil
        idToken = nil
        UserDefaults.standard.removeObject(forKey: K.email)
    }

    @MainActor
    private func authenticate(endpoint: String, email: String, password: String) async -> Bool {
        guard let apiKey, isConfigured else { status = "Add your Firebase key & project ID first."; return false }
        busy = true; defer { busy = false }
        let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:\(endpoint)?key=\(apiKey)")!
        let body = ["email": email, "password": password, "returnSecureToken": true] as [String: Any]
        guard let json = await postJSON(url, body) else { status = "Network error."; return false }
        if let err = (json["error"] as? [String: Any])?["message"] as? String {
            status = friendly(err); return false
        }
        guard let token = json["idToken"] as? String,
              let refresh = json["refreshToken"] as? String,
              let uid = json["localId"] as? String else { status = "Unexpected response."; return false }
        idToken = token
        refreshToken = refresh
        localId = uid
        self.email = email
        UserDefaults.standard.set(email, forKey: K.email)
        status = nil
        return true
    }

    /// Exchanges the refresh token for a fresh id token.
    private func refreshIfNeeded() async -> Bool {
        guard let apiKey, let refresh = refreshToken else { return false }
        let url = URL(string: "https://securetoken.googleapis.com/v1/token?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=refresh_token&refresh_token=\(refresh)".data(using: .utf8)
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["id_token"] as? String else { return false }
        idToken = token
        if let newRefresh = json["refresh_token"] as? String { refreshToken = newRefresh }
        return true
    }

    // MARK: Sync (Firestore REST)

    @MainActor
    func backup(_ snapshot: CloudSnapshot) async -> Bool {
        guard await prepare(), let uid = localId else { return false }
        busy = true; defer { busy = false }
        guard let data = try? JSONEncoder().encode(snapshot),
              let jsonString = String(data: data, encoding: .utf8) else { status = "Encode failed."; return false }

        let url = docURL(uid)
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(idToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["fields": ["data": ["stringValue": jsonString]]]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (_, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) == true else {
            status = "Backup failed."; return false
        }
        lastSync = Date(); status = nil
        return true
    }

    @MainActor
    func restore() async -> CloudSnapshot? {
        guard await prepare(), let uid = localId else { return nil }
        busy = true; defer { busy = false }
        var request = URLRequest(url: docURL(uid))
        request.setValue("Bearer \(idToken ?? "")", forHTTPHeaderField: "Authorization")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fields = json["fields"] as? [String: Any],
              let dataField = fields["data"] as? [String: Any],
              let jsonString = dataField["stringValue"] as? String,
              let snapshot = try? JSONDecoder().decode(CloudSnapshot.self, from: Data(jsonString.utf8))
        else { status = "Nothing to restore yet."; return nil }
        lastSync = Date(); status = nil
        return snapshot
    }

    private func prepare() async -> Bool {
        guard isConfigured, isSignedIn else { status = "Sign in first."; return false }
        if await refreshIfNeeded() { return true }
        status = "Session expired — sign in again."
        return false
    }

    private func docURL(_ uid: String) -> URL {
        URL(string: "https://firestore.googleapis.com/v1/projects/\(projectID)/databases/(default)/documents/calsnap/\(uid)")!
    }

    // MARK: Helpers

    private func postJSON(_ url: URL, _ body: [String: Any]) async -> [String: Any]? {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private func friendly(_ code: String) -> String {
        switch code {
        case "EMAIL_EXISTS": return "That email already has an account — sign in instead."
        case "EMAIL_NOT_FOUND", "INVALID_PASSWORD", "INVALID_LOGIN_CREDENTIALS": return "Wrong email or password."
        case "WEAK_PASSWORD : Password should be at least 6 characters": return "Password must be at least 6 characters."
        case "INVALID_EMAIL": return "That email looks invalid."
        default: return code.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private enum K {
        static let apiKey = "calsnap.cloud.apikey"
        static let project = "calsnap.cloud.project"
        static let refresh = "calsnap.cloud.refresh"
        static let localId = "calsnap.cloud.localId"
        static let email = "calsnap.cloud.email"
        static let lastSync = "calsnap.cloud.lastSync"
    }
}
