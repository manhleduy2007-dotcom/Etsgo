import Foundation

enum AIError: LocalizedError {
    case missingKey
    case refused
    case badResponse
    case api(String)

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return L("Chưa có khoá API. Hãy nhập khoá trong tab Cài đặt.", "No API key yet. Add one in the Settings tab.")
        case .refused: return L("AI từ chối xử lý yêu cầu này.", "The AI declined this request.")
        case .badResponse: return L("Không đọc được phản hồi từ AI.", "Could not read the AI's response.")
        case .api(let message): return L("Lỗi từ AI: ", "AI error: ") + message
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

struct ParsedTask: Decodable, Sendable {
    let title: String
    let category: String
    let priority: String
    /// Giờ địa phương dạng yyyy-MM-dd'T'HH:mm, hoặc chuỗi rỗng.
    let due: String
    let estimatedMinutes: Int
    let notes: String

    enum CodingKeys: String, CodingKey {
        case title, category, priority, due, notes
        case estimatedMinutes = "estimated_minutes"
    }
}

struct PrioritySuggestion: Decodable, Sendable {
    let id: String
    let priority: String
    let reason: String
}

struct PlanStep: Decodable, Sendable {
    let title: String
    let estimatedMinutes: Int
    let focusMinutes: Int
    let breakMinutes: Int

    enum CodingKeys: String, CodingKey {
        case title
        case estimatedMinutes = "estimated_minutes"
        case focusMinutes = "focus_minutes"
        case breakMinutes = "break_minutes"
    }
}

/// Một lượt của AI trong hội thoại lập kế hoạch: hoặc một câu hỏi ngắn, hoặc một kế hoạch đề xuất.
struct PlanTurn: Decodable, Sendable {
    let type: String
    let message: String
    let quickReplies: [String]
    let title: String
    let steps: [PlanStep]
    let later: [String]
    let basedOn: [String]
    let assumptions: [String]

    enum CodingKeys: String, CodingKey {
        case type, message, title, steps, later, assumptions
        case quickReplies = "quick_replies"
        case basedOn = "based_on"
    }
}

struct ContextDraft: Decodable, Sendable {
    let text: String
    /// true: người dùng đã nói rõ; false: AI kia suy đoán.
    let stated: Bool
}

struct Guidance: Decodable, Sendable {
    let tip: String
    let resourceTitle: String
    let searchQuery: String

    enum CodingKeys: String, CodingKey {
        case tip
        case resourceTitle = "resource_title"
        case searchQuery = "search_query"
    }
}

struct UnblockAdvice: Decodable, Sendable {
    let message: String
    let steps: [SubtaskSuggestion]
}

struct ChatMessage: Sendable {
    let role: String
    let content: String
}

/// Backend owns provider credentials, durable jobs and personal context.
@MainActor
struct AIService {
    static let model = "Server configured"
    private var api: BackendClient { BackendClient.shared }
    static func localDateString(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return f.string(from: date)
    }
    static func parseLocalDate(_ value: String) -> Date? {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return f.date(from: String(value.prefix(16)))
    }
    private func run(_ path: String, _ body: [String: Any]) async throws -> [String: Any] {
        let response = try await api.request("POST", path, body, key: UUID().uuidString.lowercased())
        return try await api.waitForJob(response)
    }
    func parseTasks(text: String) async throws -> [ParsedTask] {
        struct Output: Decodable { let tasks: [ParsedTask] }
        return try api.decode(Output.self, await run("/v1/ai/parse", ["text": text])).tasks
    }
    func breakdown(title: String, notes: String) async throws -> [SubtaskSuggestion] {
        struct Output: Decodable { let subtasks: [SubtaskSuggestion] }
        return try api.decode(Output.self, await run("/v1/ai/breakdown", ["title": title, "notes": notes])).subtasks
    }
    func prioritize(tasksJSON: String) async throws -> [PrioritySuggestion] {
        struct Output: Decodable { let items: [PrioritySuggestion] }
        return try api.decode(Output.self, await run("/v1/ai/prioritize", ["tasks": tasksJSON])).items
    }
    func planTurn(history: [ChatMessage], context: String, forcePlan: Bool) async throws -> (turn: PlanTurn, raw: String) {
        let defaults = UserDefaults.standard
        var id = defaults.string(forKey: "plannerConversationID")
        if id == nil {
            id = try await api.request("POST", "/v1/conversations", key: UUID().uuidString.lowercased())["id"] as? String
            defaults.set(id, forKey: "plannerConversationID")
        }
        guard let id else { throw BackendFailure(code: "missing_conversation") }
        let result = try await run("/v1/conversations/"+id+"/messages", ["text": history.last?.content ?? "", "force_proposal": forcePlan])
        defaults.set(result["proposal_id"] as? String, forKey: "plannerProposalID")
        defaults.set(result["proposal_version"] as? Int ?? 0, forKey: "plannerProposalVersion")
        return (try api.decode(PlanTurn.self, result), SyncCoordinator.shared.json(result))
    }
    func acceptPlan(_ turn: [String: Any]) async throws {
        let defaults = UserDefaults.standard
        guard let id = defaults.string(forKey: "plannerProposalID") else { throw BackendFailure(code: "missing_proposal") }
        let current = try await api.request("GET", "/v1/proposals/"+id)
        if current["status"] as? String == "accepted" {
            defaults.removeObject(forKey: "plannerConversationID")
            defaults.removeObject(forKey: "plannerProposalID")
            return
        }
        let edited = try await api.request("PATCH", "/v1/proposals/"+id,
            ["expected_version": defaults.integer(forKey: "plannerProposalVersion"), "turn": turn])
        defaults.set(edited["version"], forKey: "plannerProposalVersion")
        _ = try await api.request("POST", "/v1/proposals/"+id+"/accept",
            ["expected_version": edited["version"] as? Int ?? 0], key: "accept-"+id)
        defaults.removeObject(forKey: "plannerConversationID")
        defaults.removeObject(forKey: "plannerProposalID")
    }
    func summarizeHandoff(text: String) async throws -> [ContextDraft] {
        struct Output: Decodable { let items: [ContextDraft] }
        return try api.decode(Output.self, await run("/v1/context/imports", ["text": text])).items
    }
    func guidance(task: String, goal: String, context: String, excluding: String, taskID: String) async throws -> Guidance {
        try api.decode(Guidance.self, await run("/v1/tasks/"+taskID+"/guidance", ["excluding": excluding]))
    }
    func unblock(task: String, goal: String, problem: String, context: String, taskID: String) async throws -> UnblockAdvice {
        try api.decode(UnblockAdvice.self, await run("/v1/tasks/"+taskID+"/unblock", ["problem": problem]))
    }
}

@MainActor
func buildPromptContext(_ items: [ContextItem]) -> String {
    // Compatibility for existing Views: context is constructed on the server.
    ""
}
