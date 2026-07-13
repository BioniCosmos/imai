import Foundation

enum MaimaiDataService {
    private static let baseURL = URL(string: Constants.divingFishBaseURL)!
    private static let updateURL = URL(string: Constants.updateManifestURL)!

    /// A URLSession that accepts and stores cookies. The default shared
    /// session stores them, but `value(forHTTPHeaderField: "Set-Cookie")`
    /// returns nil because URLSession strips that header on the response
    /// object — we need to read it from `allHeaderFields` or the cookie
    /// storage instead.
    private static let cookieSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        return URLSession(configuration: config)
    }()

    static func updateInfo() async throws -> AppUpdate {
        let data = try await MaimaiDataClient.shared.request(url: updateURL)
        return try MaimaiDataClient.shared.decode(AppUpdate.self, from: data)
    }

    static func chartStats() async throws -> ChartsResponse {
        let url = baseURL.appending(path: "/api/maimaidxprober/chart_stats")
        let data = try await MaimaiDataClient.shared.request(url: url)
        return try MaimaiDataClient.shared.decode(ChartsResponse.self, from: data)
    }

    static func login(username: String, password: String) async throws -> String {
        let url = baseURL.appending(path: "/api/maimaidxprober/login")
        let body = ["username": username, "password": password]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        // Use a dedicated session so we can read Set-Cookie either from the
        // response header or from the cookie storage.
        let storage = HTTPCookieStorage.shared
        for cookie in storage.cookies(for: url) ?? [] {
            storage.deleteCookie(cookie)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        request.timeoutInterval = 60

        let (data, response) = try await cookieSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        print("DEBUG login: status=\(httpResponse.statusCode)")
        print("DEBUG login: allHeaderFields=\(httpResponse.allHeaderFields)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("DEBUG login: body=\(responseString.prefix(500))")
        }

        // The Android client only uses the cookie when the response code is
        // 200, so surface a 4xx/5xx as an error.
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpStatus(httpResponse.statusCode)
        }

        // Some deployments of Diving-Fish return the JWT in the response body
        // (`{"jwt_token": "..."}`) instead of (or in addition to) the
        // Set-Cookie header. Build a "jwt_token=..." cookie in that case so
        // downstream code can stay simple.
        if let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let token = body["jwt_token"] as? String, !token.isEmpty {
            print("DEBUG login: got jwt_token from body")
            return "jwt_token=\(token)"
        }

        // 1. Try `Set-Cookie` directly. URLSession sometimes returns it via
        // `allHeaderFields` even when `value(forHTTPHeaderField:)` returns nil.
        if let cookie = httpResponse.value(forHTTPHeaderField: "Set-Cookie"),
           !cookie.isEmpty {
            print("DEBUG login: got cookie from value(forHTTPHeaderField)")
            return cookie
        }
        for (key, value) in httpResponse.allHeaderFields {
            if let keyString = key as? String, keyString.lowercased() == "set-cookie",
               let valueString = value as? String, !valueString.isEmpty {
                print("DEBUG login: got cookie from allHeaderFields")
                return valueString
            }
        }

        // 2. The cookie may have been auto-stored; reconstruct the header
        // from the cookie storage.
        if let cookies = storage.cookies(for: url), !cookies.isEmpty {
            print("DEBUG login: got cookie from storage")
            return cookies
                .map { "\($0.name)=\($0.value)" }
                .joined(separator: "; ")
        }

        print("DEBUG login: NO COOKIE FOUND")
        return ""
    }

    static func records(cookie: String) async throws -> Data {
        guard !cookie.isEmpty else {
            throw NetworkError.httpStatus(401)
        }
        let url = baseURL.appending(path: "/api/maimaidxprober/player/records")

        // URLRequest blocks setting the "Cookie" header directly (it's a
        // protected header in iOS). We must inject cookies through the
        // cookie storage on a dedicated session. We clean up afterwards so
        // the cookie doesn't leak into other requests.
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        let session = URLSession(configuration: config)

        // Clear any prior cookies for this host, then install ours.
        for prior in HTTPCookieStorage.shared.cookies(for: url) ?? [] {
            HTTPCookieStorage.shared.deleteCookie(prior)
        }
        for piece in cookie.split(separator: ";").map({ $0.trimmingCharacters(in: .whitespaces) }) {
            let parts = piece.split(separator: "=", maxSplits: 1)
            guard parts.count == 2, let host = url.host else { continue }
            let newCookie = HTTPCookie(
                properties: [
                    .name: String(parts[0]),
                    .value: String(parts[1]),
                    .domain: host,
                    .path: "/",
                    .secure: "FALSE"
                ]
            )
            if let newCookie {
                HTTPCookieStorage.shared.setCookie(newCookie)
            }
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 60

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            print("DEBUG records: status=\(http.statusCode) bytes=\(data.count)")
            return data
        } catch {
            print("DEBUG records: error=\(error)")
            throw error
        }
    }

    static func downloadSongData(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        return try await MaimaiDataClient.shared.request(url: url)
    }
}