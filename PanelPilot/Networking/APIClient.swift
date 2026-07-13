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
        // Credentials are persisted only after a *successful* login (see login()),
        // so a failed attempt never strands the user with saved-but-invalid config.
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

    /// Make requests look like they come from the panel's own web UI, so a
    /// reverse proxy / Cloudflare / WAF in front of the panel doesn't reject
    /// them with 403 for lacking browser-like headers.
    private func applyBrowserHeaders(_ req: inout URLRequest) {
        req.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 "
            + "(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent")
        req.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        req.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        req.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        if let base = config.url("") {
            req.setValue(base.absoluteString, forHTTPHeaderField: "Referer")
            if let scheme = base.scheme, let host = base.host {
                let port = base.port.map { ":\($0)" } ?? ""
                req.setValue("\(scheme)://\(host)\(port)", forHTTPHeaderField: "Origin")
            }
        }
        // Bearer API token is the panel's documented auth for programmatic
        // clients — it authorizes every /panel/api/* endpoint and skips CSRF.
        if config.usesToken {
            let token = config.apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    // MARK: - Auth

    /// Perform a fresh login and persist credentials on success.
    @discardableResult
    func login() async throws -> Bool {
        if mockMode { isLoggedIn = true; return true }

        // Bearer-token mode: no cookie login. Verify the token with one
        // authenticated call, then treat the actor as logged in.
        if config.usesToken {
            try await verifyToken()
            isLoggedIn = true
            KeychainStore.saveConfig(config)
            return true
        }

        guard let url = config.url("login") else { throw APIError.invalidURL }

        // Warm-up GET: browsers load the login page first, which sets any
        // anti-bot / session cookie the server expects on the subsequent POST.
        // Some panels (or a proxy in front) answer a cold, cookieless POST with 403.
        if let warmURL = config.url("login") {
            var warm = URLRequest(url: warmURL)
            warm.httpMethod = "GET"
            warm.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                          forHTTPHeaderField: "Accept")
            applyBrowserHeaders(&warm)
            // Restore the HTML Accept overwritten by applyBrowserHeaders.
            warm.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                          forHTTPHeaderField: "Accept")
            _ = try? await session.data(for: warm)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        applyBrowserHeaders(&request)
        let body = "username=\(config.username.formURLEncoded)&password=\(config.password.formURLEncoded)"
        request.httpBody = body.data(using: .utf8)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.from(error)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.panelUnreachable }

        if let env = try? JSONDecoder().decode(APIStatusEnvelope.self, from: data) {
            if env.success {
                isLoggedIn = true
                KeychainStore.saveConfig(config)
                return true
            }
            // Panel replied with JSON but rejected the request — show its real message
            // so genuine bad credentials are distinguishable from other server errors.
            let msg = (env.msg ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = msg.lowercased()
            if lower.contains("password") || lower.contains("username")
                || lower.contains("رمز") || lower.contains("کاربر") || msg.isEmpty {
                throw APIError.invalidCredentials
            }
            throw APIError.server(msg)
        }

        if http.statusCode == 401 { throw APIError.invalidCredentials }

        // Non-JSON body: surface the status + a snippet so we can see what the panel returned
        // (HTML login page, redirect, Cloudflare challenge, wrong base path, etc.).
        let snippet = String(data: data.prefix(300), encoding: .utf8)?
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces) ?? "<binary>"
        throw APIError.server("HTTP \(http.statusCode) · \(config.url("login")?.absoluteString ?? "") · \(snippet)")
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
        applyBrowserHeaders(&req)
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

        // Auth failure: 401/403 or the panel returning an HTML login page.
        let looksLikeLoginHTML = Self.isHTMLLogin(data: data, response: http)
        let authFailed = http.statusCode == 401 || http.statusCode == 403 || looksLikeLoginHTML

        if authFailed {
            if config.usesToken {
                // A Bearer token was rejected — re-verifying it won't help.
                throw APIError.invalidCredentials
            }
            if !isRetry {
                isLoggedIn = false
                try await login()
                return try await request(path: path, method: method, formBody: formBody,
                                         jsonBody: jsonBody, decode: decode, isRetry: true)
            }
            throw APIError.sessionExpired
        }

        if http.statusCode >= 400 {
            let snippet = String(data: data.prefix(220), encoding: .utf8)?
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespaces) ?? ""
            throw APIError.server("HTTP \(http.statusCode) · \(url.absoluteString) · \(snippet)")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let snippet = String(data: data.prefix(220), encoding: .utf8) ?? ""
            throw APIError.decoding(snippet)
        }
    }

    // MARK: - Token verification

    /// Verify a Bearer token by hitting a lightweight authenticated endpoint.
    /// Tolerant of the list endpoint being GET or POST — only an explicit
    /// 401/403 means the token itself is bad.
    private func verifyToken() async throws {
        guard let url = config.url("panel/api/inbounds/list") else { throw APIError.invalidURL }
        var lastError: APIError = .panelUnreachable
        for method in ["GET", "POST"] {
            var req = URLRequest(url: url)
            req.httpMethod = method
            applyBrowserHeaders(&req)
            do {
                let (data, response) = try await session.data(for: req)
                guard let http = response as? HTTPURLResponse else {
                    lastError = .panelUnreachable; continue
                }
                if http.statusCode == 401 || http.statusCode == 403 {
                    throw APIError.invalidCredentials
                }
                if http.statusCode < 400 { return }   // authenticated successfully
                let snippet = String(data: data.prefix(220), encoding: .utf8)?
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespaces) ?? ""
                lastError = .server("HTTP \(http.statusCode) · \(url.absoluteString) · \(snippet)")
            } catch let e as APIError {
                throw e
            } catch {
                lastError = APIError.from(error)
            }
        }
        throw lastError
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
        // The list endpoint is a GET in 3x-ui; fall back to POST for older panels.
        let env: APIEnvelope<[Inbound]>
        do {
            env = try await request(path: "panel/api/inbounds/list", method: "GET",
                                    decode: APIEnvelope<[Inbound]>.self)
        } catch APIError.server {
            env = try await request(path: "panel/api/inbounds/list", method: "POST",
                                    decode: APIEnvelope<[Inbound]>.self)
        }
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
        // This 3.x panel serves status under /panel/api (Bearer-authorized); classic
        // panels expose POST /server/status. Try the former, then fall back.
        let candidates: [(String, String)] = [
            ("panel/api/server/status", "GET"),
            ("panel/api/server/status", "POST"),
            ("server/status", "POST")
        ]
        var lastError: Error = APIError.server("No server status")
        for (path, method) in candidates {
            do {
                let env = try await request(path: path, method: method,
                                            decode: APIEnvelope<ServerStatus>.self)
                if let status = env.obj { return status }
                lastError = APIError.server(env.msg ?? "No server status")
            } catch {
                lastError = error
            }
        }
        throw lastError
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
