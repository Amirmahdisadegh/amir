import Foundation

/// A single actor that owns the URLSession, the session cookie, credentials and
/// the transparent re-login retry logic for the 3x-ui panel.
actor APIClient {
    static let shared = APIClient()

    private var config: PanelConfig
    private var allowInsecureTLS: Bool
    private var session: URLSession
    private let insecureDelegate = InsecureTLSDelegate()
    private var isLoggedIn = false

    // Mock mode short-circuits every request with fake data (used by previews).
    var mockMode: Bool = false

    private init() {
        self.config = KeychainStore.loadConfig() ?? .default
        self.allowInsecureTLS = UserDefaults.standard.bool(forKey: "allowInsecureTLS")
        self.session = APIClient.makeSession(insecure: allowInsecureTLS,
                                             delegate: insecureDelegate)
    }

    private static func makeSession(insecure: Bool, delegate: InsecureTLSDelegate) -> URLSession {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        cfg.timeoutIntervalForResource = 30
        cfg.httpCookieStorage = HTTPCookieStorage.shared
        cfg.httpCookieAcceptPolicy = .always
        cfg.httpShouldSetCookies = true
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: cfg,
                          delegate: insecure ? delegate : nil,
                          delegateQueue: nil)
    }

    // MARK: - Configuration

    func updateConfig(_ newConfig: PanelConfig) {
        self.config = newConfig
        self.isLoggedIn = false
        KeychainStore.saveConfig(newConfig)
    }

    func currentConfig() -> PanelConfig { config }

    func setInsecureTLS(_ allow: Bool) {
        guard allow != allowInsecureTLS else { return }
        allowInsecureTLS = allow
        UserDefaults.standard.set(allow, forKey: "allowInsecureTLS")
        session = APIClient.makeSession(insecure: allow, delegate: insecureDelegate)
        isLoggedIn = false
    }

    func setMockMode(_ on: Bool) { mockMode = on }

    // MARK: - Auth

    /// Perform a fresh login and persist credentials on success.
    @discardableResult
    func login() async throws -> Bool {
        if mockMode { isLoggedIn = true; return true }
        guard let url = config.url("login") else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "username=\(config.username.formURLEncoded)&password=\(config.password.formURLEncoded)"
        request.httpBody = body.data(using: .utf8)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.from(error)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.panelUnreachable }
        if http.statusCode == 401 { throw APIError.invalidCredentials }

        if let env = try? JSONDecoder().decode(APIStatusEnvelope.self, from: data) {
            if env.success {
                isLoggedIn = true
                KeychainStore.saveConfig(config)
                return true
            } else {
                throw APIError.invalidCredentials
            }
        }
        // Non-JSON body usually means the login page HTML was returned → bad creds.
        throw APIError.invalidCredentials
    }

    // MARK: - Core request with transparent re-login

    /// POST a form/JSON body and decode the `{success,msg,obj}` envelope.
    private func request<T: Decodable>(
        path: String,
        method: String = "POST",
        formBody: String? = nil,
        jsonBody: Data? = nil,
        decode: T.Type,
        isRetry: Bool = false
    ) async throws -> T {
        if !isLoggedIn {
            try await login()
        }
        guard let url = config.url(path) else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        if let formBody {
            req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            req.httpBody = formBody.data(using: .utf8)
        } else if let jsonBody {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = jsonBody
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.from(error)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.panelUnreachable }

        // Session expiry: 401 or the panel returning an HTML login page.
        let looksLikeLoginHTML = Self.isHTMLLogin(data: data, response: http)
        if (http.statusCode == 401 || looksLikeLoginHTML) && !isRetry {
            isLoggedIn = false
            try await login()
            return try await request(path: path, method: method, formBody: formBody,
                                     jsonBody: jsonBody, decode: decode, isRetry: true)
        }
        if http.statusCode == 401 || looksLikeLoginHTML {
            throw APIError.sessionExpired
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let snippet = String(data: data.prefix(200), encoding: .utf8) ?? ""
            throw APIError.decoding(snippet)
        }
    }

    private static func isHTMLLogin(data: Data, response: HTTPURLResponse) -> Bool {
        if let contentType = response.value(forHTTPHeaderField: "Content-Type"),
           contentType.contains("text/html") {
            return true
        }
        if let text = String(data: data.prefix(120), encoding: .utf8) {
            let lower = text.lowercased()
            return lower.contains("<!doctype html") || lower.contains("<html")
        }
        return false
    }

    // MARK: - Endpoints

    func fetchInbounds() async throws -> [Inbound] {
        if mockMode { return MockData.inbounds }
        let env = try await request(path: "panel/api/inbounds/list",
                                    decode: APIEnvelope<[Inbound]>.self)
        guard env.success else { throw APIError.server(env.msg ?? "Failed to load inbounds") }
        return env.obj ?? []
    }

    func fetchOnlineClients() async throws -> [String] {
        if mockMode { return MockData.onlineEmails }
        let env = try await request(path: "panel/api/inbounds/onlines",
                                    decode: APIEnvelope<[String]>.self)
        return env.obj ?? []
    }

    func fetchServerStatus() async throws -> ServerStatus {
        if mockMode { return MockData.serverStatus }
        let env = try await request(path: "server/status",
                                    decode: APIEnvelope<ServerStatus>.self)
        guard let status = env.obj else {
            throw APIError.server(env.msg ?? "No server status")
        }
        return status
    }

    // MARK: - Client mutations

    func addClient(inboundId: Int, client: Client) async throws {
        if mockMode { return }
        let settingsJSON = try encodeClientSettings([client])
        let body = try JSONEncoder().encode(ClientMutation(id: inboundId, settings: settingsJSON))
        let env = try await request(path: "panel/api/inbounds/addClient",
                                    jsonBody: body, decode: APIStatusEnvelope.self)
        guard env.success else { throw APIError.server(env.msg ?? "Add client failed") }
    }

    func updateClient(inboundId: Int, client: Client) async throws {
        if mockMode { return }
        let settingsJSON = try encodeClientSettings([client])
        let body = try JSONEncoder().encode(ClientMutation(id: inboundId, settings: settingsJSON))
        let env = try await request(path: "panel/api/inbounds/updateClient/\(client.id)",
                                    jsonBody: body, decode: APIStatusEnvelope.self)
        guard env.success else { throw APIError.server(env.msg ?? "Update client failed") }
    }

    func deleteClient(inboundId: Int, clientId: String) async throws {
        if mockMode { return }
        let env = try await request(path: "panel/api/inbounds/\(inboundId)/delClient/\(clientId)",
                                    decode: APIStatusEnvelope.self)
        guard env.success else { throw APIError.server(env.msg ?? "Delete client failed") }
    }

    func resetClientTraffic(inboundId: Int, email: String) async throws {
        if mockMode { return }
        let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? email
        let env = try await request(path: "panel/api/inbounds/\(inboundId)/resetClientTraffic/\(encodedEmail)",
                                    decode: APIStatusEnvelope.self)
        guard env.success else { throw APIError.server(env.msg ?? "Reset traffic failed") }
    }

    // MARK: - Helpers

    /// The panel expects `settings` as a JSON *string* containing a `clients` array.
    private func encodeClientSettings(_ clients: [Client]) throws -> String {
        struct Payload: Encodable { let clients: [Client] }
        let data = try JSONEncoder().encode(Payload(clients: clients))
        return String(data: data, encoding: .utf8) ?? "{\"clients\":[]}"
    }

    private struct ClientMutation: Encodable {
        let id: Int
        let settings: String
    }
}

extension String {
    /// Percent-encode for application/x-www-form-urlencoded bodies.
    var formURLEncoded: String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}
