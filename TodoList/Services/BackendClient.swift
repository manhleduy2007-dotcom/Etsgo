import Foundation
import SwiftUI
import Security

struct BackendFailure: LocalizedError {
    let code: String
    var errorDescription: String? {
        switch code {
        case "ai_not_configured":
            return L("AI chưa được cấu hình trên backend (thiếu khóa API hoặc AI_MODEL trong .env).",
                     "AI is not configured on the backend (missing API key or AI_MODEL in .env).")
        case "ai_auth_failed":
            return L("Khóa API của AI trên backend không hợp lệ hoặc đã hết hạn. Cập nhật khóa trong .env rồi chạy lại docker compose.",
                     "The backend's AI API key is invalid or expired. Update it in .env and restart docker compose.")
        case "ai_model_unavailable":
            return L("Model AI trong AI_MODEL không tồn tại hoặc tài khoản chưa có quyền dùng.",
                     "The AI_MODEL is unknown or this account has no access to it.")
        case "ai_provider_quota_exhausted":
            return L("Tài khoản nhà cung cấp AI đã hết hạn mức thanh toán.", "The AI provider account has run out of credit.")
        case "ai_rate_limited", "provider_failed":
            return L("Dịch vụ AI tạm thời không phản hồi. Thử lại sau ít phút.", "The AI service is temporarily unavailable. Try again shortly.")
        case "ai_invalid_output", "ai_incomplete", "ai_request_rejected":
            return L("AI trả kết quả không dùng được. Hãy thử lại.", "The AI returned an unusable answer. Please try again.")
        case "ai_refused":
            return L("AI từ chối xử lý yêu cầu này.", "The AI declined this request.")
        case "quota_exceeded":
            return L("Đã hết lượt AI hôm nay.", "You've used today's AI allowance.")
        case "conversation_busy":
            return L("AI vẫn đang trả lời tin trước.", "AI is still answering the previous message.")
        case "proposal_stale":
            return L("Đề xuất đã cũ vì dữ liệu vừa thay đổi. Hãy đề xuất lại.", "This proposal is out of date because your data changed. Please propose again.")
        case "schedule_invalid":
            return L("Lịch đề xuất không còn hợp lệ (trùng giờ bận hoặc vượt cam kết). Hãy đề xuất lại.",
                     "The proposed schedule is no longer valid (busy time or commitment changed). Please propose again.")
        case "calendar_stale":
            return L("Dữ liệu lịch ngoài đã cũ. Hãy đề xuất lại để làm mới.", "External calendar data is out of date. Propose again to refresh it.")
        case "sync_conflict_review_in_settings":
            return L("Có xung đột đồng bộ. Xem ở Cài đặt → Tài khoản và đồng bộ.", "There is a sync conflict. Review it in Settings → Account and sync.")
        case "sync_required_before_server_action":
            return L("Chưa đồng bộ được với backend. Kiểm tra backend đang chạy rồi thử lại.",
                     "Could not sync with the backend. Check that it is running, then try again.")
        case "login_required", "invalid_token", "authentication_required":
            return L("Phiên đăng nhập đã hết hạn. Vào Cài đặt → Tài khoản và đồng bộ → Đăng nhập lại.",
                     "Your session expired. Go to Settings → Account and sync → Renew sign-in.")
        case "google_not_connected":
            return L("Chưa kết nối Google Calendar.", "Google Calendar is not connected.")
        case "google_not_configured":
            return L("Backend chưa cấu hình Google OAuth (GOOGLE_CLIENT_ID).", "The backend has no Google OAuth client (GOOGLE_CLIENT_ID).")
        case "calendar_permission_required":
            return L("Ứng dụng chưa có quyền truy cập Lịch.", "The app has no Calendar access.")
        case "job_still_running_reopen_to_resume":
            return L("AI vẫn đang xử lý. Mở lại màn hình sau để xem kết quả.", "AI is still working. Reopen this screen later to see the result.")
        default:
            return code.replacingOccurrences(of: "_", with: " ")
        }
    }
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

    func sendCode(email: String) async throws {
        _ = try await request("POST", "/v1/auth/otp", ["email": email], authenticated: false)
    }

    func verify(email: String, code: String) async throws {
        let value = try await request("POST", "/v1/auth/verify", ["email": email, "code": code], authenticated: false)
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
            if job["status"] as? String == "cancelled" { throw BackendFailure(code: "job_cancelled") }
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
