import Foundation

enum AppConfig {
    /// Firebase Hosting のベース URL（GoogleService-Info.plist の PROJECT_ID から自動）
    static var hostingBaseURL: String {
        AppFirebaseConfig.defaultHostingURL
    }

    static func sessionURL(sessionId: String) -> URL? {
        URL(string: "\(hostingBaseURL)/session/\(sessionId)")
    }

    /// 翌日 4:00 JST（Cloud Functions の自動削除時刻と一致）
    static func defaultExpiresAt(from date: Date = .now) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!

        let startOfToday = calendar.startOfDay(for: date)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday),
              let expires = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: tomorrow)
        else {
            return date.addingTimeInterval(86400)
        }
        return expires
    }
}
