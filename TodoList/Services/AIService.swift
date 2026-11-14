import Foundation

enum AIError: LocalizedError {
    case missingKey
    case refused
    case badResponse
    case api(String)

    var errorDescription: String? {
        switch self {
        case .missingKey: return "Chưa có khoá API. Hãy nhập khoá trong tab Cài đặt."
        case .refused: return "AI từ chối xử lý yêu cầu này."
        case .badResponse: return "Không đọc được phản hồi từ AI."
        case .api(let message): return "Lỗi từ AI: \(message)"
        }
    }
}

struct SubtaskSuggestion: Decodable, Sendable {
    let title: String
    let estimatedMinutes: Int

    enum CodingKeys: String, CodingKey {
        case title
        case estimatedMinutes = "estimated_minutes"
    }
}

struct PrioritySuggestion: Decodable, Sendable {
    let id: String
    let priority: String
    let reason: String
}

/// Gọi Claude Messages API trực tiếp bằng URLSession, trả về JSON theo schema.
struct AIService: Sendable {
    static let model = "claude-opus-5-5"
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    /// Chia một công việc thành các bước nhỏ kèm thời lượng ước tính.
    func breakdown(title: String, notes: String) async throws -> [SubtaskSuggestion] {
        struct Output: Decodable { let subtasks: [SubtaskSuggestion] }
        let schema = """
        {
          "type": "object",
          "properties": {
            "subtasks": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "title": { "type": "string" },
                  "estimated_minutes": { "type": "integer" }
                },
                "required": ["title", "estimated_minutes"],
                "additionalProperties": false
              }
            }
          },
          "required": ["subtasks"],
          "additionalProperties": false
        }
        """
        let system = """
        Bạn là trợ lý lập kế hoạch trong một ứng dụng quản lý công việc. Người dùng đưa một công việc; \
        hãy chia nó thành các bước nhỏ, cụ thể, làm được ngay, theo đúng thứ tự thực hiện. \
        Mỗi bước nên gói trong một lần ngồi làm (khoảng 15 đến 90 phút) và có thời lượng ước tính thực tế tính bằng phút. \
        Số bước tuỳ độ lớn của công việc, thường từ 3 đến 7; việc đã đủ nhỏ thì trả về ít bước. \
        Viết tiêu đề ngắn gọn, bằng ngôn ngữ của công việc gốc.
        """
        let user = "Công việc: \(title)" + (notes.isEmpty ? "" : "\nGhi chú: \(notes)")
        let output: Output = try await complete(system: system, user: user, schema: schema)
        return output.subtasks
    }

    /// Đề xuất mức ưu tiên cho danh sách công việc (đã mã hoá thành JSON).
    func prioritize(tasksJSON: String) async throws -> [PrioritySuggestion] {
        struct Output: Decodable { let items: [PrioritySuggestion] }
        let schema = """
        {
          "type": "object",
          "properties": {
            "items": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "id": { "type": "string" },
                  "priority": { "type": "string", "enum": ["low", "medium", "high"] },
                  "reason": { "type": "string" }
                },
                "required": ["id", "priority", "reason"],
                "additionalProperties": false
              }
            }
          },
          "required": ["items"],
          "additionalProperties": false
        }
        """
        let system = """
        Bạn là trợ lý lập kế hoạch trong một ứng dụng quản lý công việc. Người dùng đưa danh sách công việc chưa xong \
        dưới dạng JSON (id, tiêu đề, ghi chú, hạn chót, thời lượng ước tính, mức ưu tiên hiện tại). \
        Hãy đề xuất mức ưu tiên low, medium hoặc high cho từng việc, dựa trên độ gấp (hạn chót so với thời điểm hiện tại), \
        tầm quan trọng và khối lượng. Người dùng dùng kết quả để quyết định làm gì trước, nên các mức phải phân biệt \
        được với nhau: đừng xếp mọi thứ là high. Trả về đúng một mục cho mỗi id đã nhận, kèm lý do dài một câu \
        bằng ngôn ngữ của công việc.
        """
        let now = ISO8601DateFormatter().string(from: .now)
        let user = "Thời điểm hiện tại: \(now)\nDanh sách công việc:\n\(tasksJSON)"
        let output: Output = try await complete(system: system, user: user, schema: schema)
        return output.items
    }

    private func complete<T: Decodable>(system: String, user: String, schema schemaJSON: String) async throws -> T {
        guard let apiKey = KeychainStore.apiKey else { throw AIError.missingKey }
        let schema = try JSONSerialization.jsonObject(with: Data(schemaJSON.utf8))

        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": 16000,
            "system": system,
            "messages": [["role": "user", "content": user]],
            "output_config": [
                "effort": "medium",
                "format": ["type": "json_schema", "schema": schema] as [String: Any],
            ] as [String: Any],
            // Nếu bộ lọc an toàn từ chối, API tự chạy lại trên mô hình dự phòng.
            "fallbacks": "default",
        ]

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(APIErrorEnvelope.self, from: data))?.error.message
            throw AIError.api(message ?? "HTTP \(http.statusCode)")
        }

        let message = try JSONDecoder().decode(MessageResponse.self, from: data)
        if message.stopReason == "refusal" { throw AIError.refused }
        // Khối thinking có thể đứng trước; lấy khối text đầu tiên.
        guard message.stopReason != "max_tokens",
              let text = message.content.first(where: { $0.type == "text" })?.text,
              let json = text.data(using: .utf8)
        else { throw AIError.badResponse }
        do {
            return try JSONDecoder().decode(T.self, from: json)
        } catch {
            throw AIError.badResponse
        }
    }
}

private struct MessageResponse: Decodable {
    struct Block: Decodable {
        let type: String
        let text: String?
    }

    let content: [Block]
    let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case content
        case stopReason = "stop_reason"
    }
}

private struct APIErrorEnvelope: Decodable {
    struct Detail: Decodable { let message: String }
    let error: Detail
}
