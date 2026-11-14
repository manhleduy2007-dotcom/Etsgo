import Foundation

/// Ngôn ngữ người dùng chọn cho giao diện và hội thoại AI (LG-01).
enum AppLanguage: String, CaseIterable, Identifiable {
    case vi, en

    var id: String { rawValue }

    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "language") ?? "vi") ?? .vi
    }

    var name: String { self == .vi ? "Tiếng Việt" : "English" }
    var locale: Locale { Locale(identifier: self == .vi ? "vi_VN" : "en_US") }
    var speechLocale: Locale { Locale(identifier: self == .vi ? "vi-VN" : "en-US") }
    /// Tên ngôn ngữ dùng trong chỉ dẫn gửi cho AI.
    var promptName: String { self == .vi ? "Vietnamese" : "English" }
}

/// Chọn chuỗi theo ngôn ngữ hiện tại.
func L(_ vi: String, _ en: String) -> String {
    AppLanguage.current == .vi ? vi : en
}
