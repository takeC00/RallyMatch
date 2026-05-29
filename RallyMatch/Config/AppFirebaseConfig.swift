import Foundation

enum AppFirebaseConfig {
    static var projectId: String? {
        plistString(forKey: "PROJECT_ID")
    }

    /// Firebase Hosting のデフォルト URL（QR 用）
    static var defaultHostingURL: String {
        guard let projectId, !projectId.isEmpty else {
            return "https://YOUR_PROJECT.web.app"
        }
        return "https://\(projectId).web.app"
    }

    private static func plistString(forKey key: String) -> String? {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let value = dict[key] as? String,
              !value.isEmpty
        else { return nil }
        return value
    }
}
