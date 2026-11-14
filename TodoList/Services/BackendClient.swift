import Foundation
import SwiftUI
import Security

struct BackendFailure: LocalizedError {
    let code: String
    var errorDescription: String? { code.replacingOccurrences(of: "_", with: " ") }
}

@MainActor
final class BackendClient: ObservableObject {
    static let shared = BackendClient()
    @Published private(set) var userID: String?
    @Published var lastError: String?
    private var tokens: [String: Any] = [:]
    private var refreshing: Task<Void, Error>?
    var baseURL: String { UserDefaults.standard.string(forKey: "backendURL") ?? "http://localhost:8000" }
    var deviceID: String {
        if let id = UserDefaults.standard.string(forKey: "deviceID") { return id }
        let id = UUID().uuidString.lowercased()
        UserDefaults.standard.set(id, forKey: "deviceID")
        return id
    }
    var signedIn: Bool { userID != nil }

    private init() {
        if let data = readSession(), let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            tokens = value
            userID = (value["user"] as? [String: Any])?["id"] as? String
        }
    }

    func signIn(apiKey: String) async throws {
        let value = try await request("POST", "/v1/auth/api-key", ["api_key": apiKey], authenticated: false)
        guard let user = value["user"] as? [String: Any], let id = user["id"] as? String else {
            throw BackendFailure(code: "invalid_auth_response")
        }
        if let previous = UserDefaults.standard.string(forKey: "localOwner"), previous != id {
            throw BackendFailure(code: "sign_out_and_clear_previous_account_first")
        }
        tokens = value
        UserDefaults.standard.set(id, forKey: "localOwner")
        persistSession()
        userID = id
    }

    func signOut() {
        tokens = [:]
        userID = nil
        SecItemDelete(sessionQuery() as CFDictionary)
    }

    #if DEBUG
    func developmentLogin() async throws {
        let result = try await request("POST", "/v1/auth/development", authenticated: false)
        guard let id = (result["user"] as? [String: Any])?["id"] as? String else { throw BackendFailure(code: "invalid_auth_response") }
        if let previous = UserDefaults.standard.string(forKey: "localOwner"), previous != id {
            throw BackendFailure(code: "sign_out_and_clear_previous_account_first")
        }
        tokens = result; persistSession(); userID = id
        UserDefaults.standard.set(id, forKey: "localOwner")
    }
    #endif

    func request(_ method: String, _ path: String, _ body: [String: Any]? = nil,
                 key: String? = nil, authenticated: Bool = true, retry: Bool = true) async throws -> [String: Any] {
        guard let url = URL(string: baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + path),
              ["http", "https"].contains(url.scheme ?? "") else { throw BackendFailure(code: "invalid_backend_url") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authenticated {
            guard let access = tokens["access_token"] as? String else { throw BackendFailure(code: "login_required") }
            request.setValue("Bearer " + access, forHTTPHeaderField: "Authorization")
        }
        if let key { request.setValue(key, forHTTPHeaderField: "Idempotency-Key") }
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]) }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BackendFailure(code: "invalid_response") }
        if http.statusCode == 401 && authenticated && retry {
            if refreshing == nil {
                refreshing = Task {
                    guard let refresh = self.tokens["refresh_token"] as? String else { throw BackendFailure(code: "login_required") }
                    let result = try await self.request("POST", "/v1/auth/refresh", ["refresh_token": refresh], authenticated: false)
                    self.tokens = result
                    self.persistSession()
                }
            }
            do { try await refreshing?.value; refreshing = nil }
            catch { refreshing = nil; throw error }
            return try await self.request(method, path, body, key: key, retry: false)
        }
        let value = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (200..<300).contains(http.statusCode) else {
            throw BackendFailure(code: (value["error"] as? [String: Any])?["code"] as? String ?? "HTTP_\(http.statusCode)")
        }
        return value
    }

    func waitForJob(_ response: [String: Any]) async throws -> [String: Any] {
        guard let id = response["job_id"] as? String else { throw BackendFailure(code: "missing_job") }
        for _ in 0..<180 {
            try Task.checkCancellation()
            let job = try await request("GET", "/v1/jobs/" + id)
            if job["status"] as? String == "succeeded" { return job["result"] as? [String: Any] ?? [:] }
            if job["status"] as? String == "failed" { throw BackendFailure(code: job["error"] as? String ?? "job_failed") }
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        throw BackendFailure(code: "job_still_running_reopen_to_resume")
    }

    func decode<T: Decodable>(_ type: T.Type, _ json: [String: Any]) throws -> T {
        try JSONDecoder().decode(type, from: JSONSerialization.data(withJSONObject: json))
    }

    private func sessionQuery() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "etsgo.backend.session",
         kSecAttrAccount as String: "session"]
    }
    private func readSession() -> Data? {
        var query = sessionQuery()
        query[kSecReturnData as String] = true
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }
    private func persistSession() {
        guard let data = try? JSONSerialization.data(withJSONObject: tokens) else { return }
        var query = sessionQuery()
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }
}
