import Foundation

enum AppConfig {
    private static let hostingURLKey = "hostingBaseURL"

    /// Firebase Hosting のベース URL（末尾スラッシュなし）
    /// 例: https://your-project.web.app
    static var hostingBaseURL: String {
        get {
            UserDefaults.standard.string(forKey: hostingURLKey)
                ?? "https://YOUR_PROJECT.web.app"
        }
        set {
            var trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            while trimmed.hasSuffix("/") { trimmed.removeLast() }
            UserDefaults.standard.set(trimmed, forKey: hostingURLKey)
        }
    }

    static func sessionURL(sessionId: String) -> URL? {
        URL(string: "\(hostingBaseURL)/session/\(sessionId)")
    }

    /// 翌日 5:00 JST
    static func defaultExpiresAt(from date: Date = .now) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!

        let startOfToday = calendar.startOfDay(for: date)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday),
              let expires = calendar.date(bySettingHour: 5, minute: 0, second: 0, of: tomorrow)
        else {
            return date.addingTimeInterval(86400)
        }
        return expires
    }
}
