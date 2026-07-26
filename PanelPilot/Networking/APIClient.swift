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
    /// CSRF token this panel requires on unsafe (POST) cookie-session requests.
    private var csrfToken: String?
    /// Ephemeral two-factor / OTP code to include on the next login, if the panel has 2FA on.
    private var twoFactorCode: String?

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
        self.csrfToken = nil
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
        csrfToken = nil
    }

    func setMockMode(_ on: Bool) { mockMode = on }

    /// Provide a two-factor / OTP code to use on the next login (cleared on config change).
    func setTwoFactorCode(_ code: String?) {
        let trimmed = code?.trimmingCharacters(in: .whitespacesAndNewlines)
        twoFactorCode = (trimmed?.isEmpty ?? true) ? nil : trimmed
    }

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
        } else if let csrf = csrfToken, !csrf.isEmpty {
            // Cookie sessions must replay the CSRF token on unsafe requests.
            req.setValue(csrf, forHTTPHeaderField: "X-CSRF-Token")
        }
    }

    // MARK: - CSRF

    /// Fetch a CSRF token the way the panel's SPA does (GET /csrf-token), tolerant
    /// of the token arriving in a header, a JSON field, or as a plain string.
    private func refreshCSRFToken() async {
        guard let url = config.url("csrf-token") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        applyBrowserHeaders(&req)
        guard let (data, response) = try? await session.data(for: req) else { return }
        if let http = response as? HTTPURLResponse {
            for field in ["X-CSRF-Token", "X-Csrf-Token", "x-csrf-token"] {
                if let v = http.value(forHTTPHeaderField: field), !v.isEmpty {
                    csrfToken = v
                    return
                }
            }
        }
        if let token = Self.extractCSRF(from: data) { csrfToken = token; return }
        // Double-submit pattern: token delivered as a cookie to be echoed in the header.
        if let cookies = session.configuration.httpCookieStorage?.cookies(for: url) {
            for cookie in cookies where cookie.name.lowercased().contains("csrf") {
                if !cookie.value.isEmpty { csrfToken = cookie.value; return }
            }
        }
    }

    private static func extractCSRF(from data: Data) -> String? {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["token", "csrfToken", "csrf_token", "csrf", "obj", "data"] {
                if let v = obj[key] as? String, !v.isEmpty { return v }
            }
            // Nested envelope: { obj: { token: ... } }
            if let nested = obj["obj"] as? [String: Any],
               let v = nested["token"] as? String, !v.isEmpty { return v }
            return nil
        }
        // Plain-string body
        if let s = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !s.isEmpty, !s.contains("<"), !s.contains("{"), s.count < 256 {
            return s
        }
        return nil
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

        // This panel protects every unsafe request (including login) with CSRF.
        // Mirror the web UI: GET /csrf-token first to obtain the token + cookie,
        // then submit the login POST carrying it in the X-CSRF-Token header.
        await refreshCSRFToken()

        // Modern 3x-ui (OAS 3.0) expects a JSON login body; classic panels use
        // form-encoding. Try JSON first, then form, so either version works.
        var lastData = Data()
        var lastStatus = 0
        for asJSON in [true, false] {
            let (data, http): (Data, HTTPURLResponse)
            do {
                (data, http) = try await postLogin(url: url, json: asJSON)
            } catch {
                throw APIError.from(error)
            }
            lastData = data; lastStatus = http.statusCode

            if let env = try? JSONDecoder().decode(APIStatusEnvelope.self, from: data), env.success {
                isLoggedIn = true
                await refreshCSRFToken()   // fresh CSRF for the authenticated session
                KeychainStore.saveConfig(config)
                return true
            }
        }

        // Both attempts failed — report the panel's own words.
        if let env = try? JSONDecoder().decode(APIStatusEnvelope.self, from: lastData),
           let msg = env.msg?.trimmingCharacters(in: .whitespacesAndNewlines), !msg.isEmpty {
            throw APIError.server(msg)
        }
        if lastStatus == 401 { throw APIError.invalidCredentials }
        let snippet = String(data: lastData.prefix(300), encoding: .utf8)?
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces) ?? "<binary>"
        throw APIError.server("HTTP \(lastStatus) [csrf:\(csrfToken != nil ? "ok" : "none")] · \(snippet)")
    }

    /// Submit the login POST as either JSON or form-encoded, including an
    /// optional two-factor code under several field names panels use.
    private func postLogin(url: URL, json: Bool) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyBrowserHeaders(&request)
        let code = twoFactorCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            var payload: [String: Any] = ["username": config.username, "password": config.password]
            if !code.isEmpty {
                payload["twoFactorCode"] = code
                payload["loginSecret"] = code
            }
            request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        } else {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            var body = "username=\(config.username.formURLEncoded)&password=\(config.password.formURLEncoded)"
            if !code.isEmpty { body += "&twoFactorCode=\(code.formURLEncoded)&loginSecret=\(code.formURLEncoded)" }
            request.httpBody = body.data(using: .utf8)
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.panelUnreachable }
        return (data, http)
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
        // Panels differ on path (clients/onlines vs inbounds/onlines), method
        // (GET/POST), and payload shape ([String] or [{email|clientEmail|...}]).
        let paths = ["panel/api/clients/onlines", "panel/api/inbounds/onlines"]
        for path in paths {
            for method in ["POST", "GET"] {
                if let env = try? await request(path: path, method: method,
                                                decode: APIEnvelope<[String]>.self),
                   let obj = env.obj, !obj.isEmpty {
                    return obj
                }
                if let env = try? await request(path: path, method: method,
                                                decode: APIEnvelope<[OnlineEntry]>.self),
                   let obj = env.obj {
                    let emails = obj.compactMap { $0.email }.filter { !$0.isEmpty }
                    if !emails.isEmpty { return emails }
                }
            }
        }
        return []
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

    // MARK: - Inbound mutations

    /// Create a new inbound. Body is a JSON object built by the caller (settings/
    /// streamSettings/sniffing sent as nested JSON objects, which this panel prefers).
    func addInbound(jsonBody: Data) async throws {
        if mockMode { return }
        let env = try await request(path: "panel/api/inbounds/add",
                                    jsonBody: jsonBody, decode: APIStatusEnvelope.self)
        guard env.success else { throw APIError.server(env.msg ?? "Add inbound failed") }
    }

    func deleteInbound(id: Int) async throws {
        if mockMode { return }
        do {
            let env = try await request(path: "panel/api/inbounds/del/\(id)",
                                        decode: APIStatusEnvelope.self)
            guard env.success else { throw APIError.server(env.msg ?? "Delete inbound failed") }
        } catch {
            let env = try? await request(path: "panel/api/inbounds/\(id)",
                                         method: "POST", decode: APIStatusEnvelope.self)
            guard env?.success == true else { throw error }
        }
    }

    // MARK: - Client mutations
    //
    // Modern 3x-ui (this panel) manages clients as a top-level resource keyed by
    // EMAIL under /panel/api/clients/*. Classic panels key clients by inbound +
    // UUID under /panel/api/inbounds/*. We try the modern path first and fall
    // back to the classic one so the app works against both.

    func addClient(inboundId: Int, client: Client) async throws {
        if mockMode { return }
        do {
            let payload = ClientAddBody(client: .init(client), inboundIds: [inboundId])
            let body = try JSONEncoder().encode(payload)
            let env = try await request(path: "panel/api/clients/add",
                                        jsonBody: body, decode: APIStatusEnvelope.self)
            guard env.success else { throw APIError.server(env.msg ?? "Add client failed") }
        } catch {
            guard (try? await addClientClassic(inboundId: inboundId, client: client)) != nil
            else { throw error }
        }
    }

    func updateClient(inboundId: Int, client: Client) async throws {
        if mockMode { return }
        do {
            let payload = ClientUpdateBody(client: .init(client), inboundIds: [inboundId])
            let body = try JSONEncoder().encode(payload)
            let env = try await request(path: "panel/api/clients/update/\(client.email.pathEncoded)",
                                        jsonBody: body, decode: APIStatusEnvelope.self)
            guard env.success else { throw APIError.server(env.msg ?? "Update client failed") }
        } catch {
            guard (try? await updateClientClassic(inboundId: inboundId, client: client)) != nil
            else { throw error }
        }
    }

    func deleteClient(inboundId: Int, client: Client) async throws {
        if mockMode { return }
        do {
            let env = try await request(path: "panel/api/clients/del/\(client.email.pathEncoded)",
                                        decode: APIStatusEnvelope.self)
            guard env.success else { throw APIError.server(env.msg ?? "Delete client failed") }
        } catch {
            let classic = "panel/api/inbounds/\(inboundId)/delClient/\(client.id)"
            guard let env = try? await request(path: classic, decode: APIStatusEnvelope.self),
                  env.success else { throw error }
        }
    }

    func resetClientTraffic(inboundId: Int, email: String) async throws {
        if mockMode { return }
        do {
            let env = try await request(path: "panel/api/clients/\(email.pathEncoded)/resetTraffic",
                                        decode: APIStatusEnvelope.self)
            guard env.success else { throw APIError.server(env.msg ?? "Reset traffic failed") }
        } catch {
            let classic = "panel/api/inbounds/\(inboundId)/resetClientTraffic/\(email.pathEncoded)"
            guard let env = try? await request(path: classic, decode: APIStatusEnvelope.self),
                  env.success else { throw error }
        }
    }

    // MARK: - Classic (inbound + UUID) fallbacks

    private func addClientClassic(inboundId: Int, client: Client) async throws {
        let body = try JSONEncoder().encode(
            ClientMutation(id: inboundId, settings: try encodeClientSettings([client])))
        let env = try await request(path: "panel/api/inbounds/addClient",
                                    jsonBody: body, decode: APIStatusEnvelope.self)
        guard env.success else { throw APIError.server(env.msg ?? "Add client failed") }
    }

    private func updateClientClassic(inboundId: Int, client: Client) async throws {
        let body = try JSONEncoder().encode(
            ClientMutation(id: inboundId, settings: try encodeClientSettings([client])))
        let env = try await request(path: "panel/api/inbounds/updateClient/\(client.id)",
                                    jsonBody: body, decode: APIStatusEnvelope.self)
        guard env.success else { throw APIError.server(env.msg ?? "Update client failed") }
    }

    // MARK: - Helpers

    /// The classic panel expects `settings` as a JSON *string* with a `clients` array.
    private func encodeClientSettings(_ clients: [Client]) throws -> String {
        struct Payload: Encodable { let clients: [Client] }
        let data = try JSONEncoder().encode(Payload(clients: clients))
        return String(data: data, encoding: .utf8) ?? "{\"clients\":[]}"
    }

    private struct ClientMutation: Encodable {
        let id: Int
        let settings: String
    }

    /// Client fields the modern /panel/api/clients endpoints accept.
    private struct ModernClient: Encodable {
        let email: String
        let totalGB: Int64
        let expiryTime: Int64
        let tgId: Int
        let limitIp: Int
        let enable: Bool
        let flow: String?
        init(_ c: Client) {
            email = c.email
            totalGB = c.totalGB
            expiryTime = c.expiryTime
            tgId = Int(c.tgId ?? "") ?? 0
            limitIp = c.limitIp ?? 0
            enable = c.enable
            flow = c.flow.isEmpty ? nil : c.flow
        }
    }
    private struct ClientAddBody: Encodable { let client: ModernClient; let inboundIds: [Int] }
    private struct ClientUpdateBody: Encodable { let client: ModernClient; let inboundIds: [Int] }
}

extension String {
    /// Percent-encode for application/x-www-form-urlencoded bodies.
    var formURLEncoded: String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }

    /// Percent-encode a value for use as a single URL path segment (encodes `@`, `/`, …).
    var pathEncoded: String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}
