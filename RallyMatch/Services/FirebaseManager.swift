import Foundation
import FirebaseAuth
import FirebaseCore
import Observation

@MainActor
@Observable
final class FirebaseManager {
    static let shared = FirebaseManager()

    private(set) var uid: String?
    private(set) var isReady = false
    var lastError: String?

    var isPlistConfigured: Bool {
        Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
            && Self.loadPlistValues() != nil
    }

    private init() {}

    func configureIfNeeded() -> Bool {
        guard Self.loadPlistValues() != nil else {
            lastError = """
            GoogleService-Info.plist が見つかりません。
            Firebase Console からダウンロードし RallyMatch/ に配置して再ビルドしてください。
            """
            isReady = false
            return false
        }

        if FirebaseApp.app() == nil {
            // plist から全設定を読み込む（authDomain 等も自動。手動 Options だと Auth が失敗しやすい）
            FirebaseApp.configure()
        }
        return true
    }

    func signInAnonymouslyIfNeeded() async {
        guard configureIfNeeded() else { return }

        if let user = Auth.auth().currentUser {
            uid = user.uid
            isReady = true
            lastError = nil
            return
        }

        do {
            let result = try await Auth.auth().signInAnonymously()
            uid = result.user.uid
            isReady = true
            lastError = nil
        } catch {
            let nsError = error as NSError
            lastError = Self.authErrorMessage(nsError)
            isReady = false
            #if DEBUG
            print("[Firebase Auth]", nsError)
            if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                print("[Firebase Auth underlying]", underlying)
            }
            #endif
        }
    }

      private static func authErrorMessage(_ error: NSError) -> String {
        if error.domain == AuthErrorDomain {
            switch AuthErrorCode(rawValue: error.code) {
            case .some(.operationNotAllowed):
                return "匿名ログインが無効です。Firebase Console → Authentication → Sign-in method →「匿名」を有効にしてください。"
            case .some(.networkError):
                return "ネットワークに接続できません。通信環境を確認してください。"
            case .some(.appNotVerified):
                return "アプリの検証に失敗しました。Bundle ID が Firebase の iOS アプリ設定と一致しているか確認してください。"
            case .some(.internalError):
                return """
                Firebase 内部エラーです。次を確認してください:
                ・Authentication で「匿名」が有効
                ・Google Cloud で Identity Toolkit API が有効
                ・API キーに iOS アプリ制限がある場合は正しいバンドル ID
                """
            default:
                break
            }
        }

        var message = error.localizedDescription
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            message += "\n詳細: \(underlying.localizedDescription)"
        }
        return message
    }

    private struct PlistValues {
        let googleAppID: String
        let gcmSenderID: String
        let apiKey: String
        let projectID: String
    }

    private static func loadPlistValues() -> PlistValues? {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let googleAppID = dict["GOOGLE_APP_ID"] as? String,
              let gcmSenderID = dict["GCM_SENDER_ID"] as? String,
              let apiKey = dict["API_KEY"] as? String,
              let projectID = dict["PROJECT_ID"] as? String,
              !googleAppID.contains("YOUR_"),
              !apiKey.contains("YOUR_"),
              !projectID.contains("YOUR_")
        else {
            return nil
        }

        return PlistValues(
            googleAppID: googleAppID,
            gcmSenderID: gcmSenderID,
            apiKey: apiKey,
            projectID: projectID
        )
    }
}
