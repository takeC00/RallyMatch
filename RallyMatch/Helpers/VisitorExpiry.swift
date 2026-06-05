import Foundation

/// Visitor（アカウント未連携）の有効期限判定（日本時間の日付基準）
enum VisitorExpiry {
    private static var jstCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    /// 登録日（JST）が今日より前なら期限切れ
    static func isExpired(createdAt: Date, now: Date = .now) -> Bool {
        let createdDay = jstCalendar.startOfDay(for: createdAt)
        let today = jstCalendar.startOfDay(for: now)
        return createdDay < today
    }

    static func registrationDayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }

    /// UserDefaults 等の日付キー用（JST）
    static func todayKeyInJST(now: Date = .now) -> String {
        registrationDayLabel(for: now)
    }
}
