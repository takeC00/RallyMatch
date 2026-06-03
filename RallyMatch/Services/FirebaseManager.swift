import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Observation

@MainActor
@Observable
final class FirebaseManager {
    static let shared = FirebaseManager()

    private(set) var uid: String?
    private(set) var isReady = false
    private(set) var currentUserEmail: String?
    private(set) var currentUserName: String = ""
    var lastError: String?

    private var authListener: AuthStateDidChangeListenerHandle?

    private var db: Firestore {
        Firestore.firestore()
    }

    var isPlistConfigured: Bool {
        Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
            && Self.loadPlistValues() != nil
    }

    /// SwiftUI の @Observable が追跡できるよう、Auth 直読みではなく `uid` を参照する。
    var isLoggedIn: Bool {
        uid != nil
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
            FirebaseApp.configure()
        }
        return true
    }

    func startAuthListener() {
        guard configureIfNeeded() else { return }
        guard authListener == nil else { return }

        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.applyAuthUser(user)
            }
        }
    }

    func bootstrapSession() {
        guard configureIfNeeded() else { return }

        if let user = Auth.auth().currentUser, user.isAnonymous {
            try? Auth.auth().signOut()
            applyAuthUser(nil)
            return
        }

        applyAuthUser(Auth.auth().currentUser)
    }

    func login(
        email: String,
        password: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard configureIfNeeded() else {
            completion(.failure(Self.configurationError))
            return
        }

        Auth.auth().signIn(withEmail: email, password: password) { [weak self] _, error in
            if let error {
                Task { @MainActor in
                    completion(.failure(error))
                }
                return
            }

            Task { @MainActor in
                self?.applyAuthUser(Auth.auth().currentUser)
                self?.fetchUserProfile()
                completion(.success(()))
            }
        }
    }

    func signUp(
        email: String,
        password: String,
        name: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard configureIfNeeded() else {
            completion(.failure(Self.configurationError))
            return
        }

        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            if let error {
                Task { @MainActor in
                    completion(.failure(error))
                }
                return
            }

            guard let user = result?.user else {
                Task { @MainActor in
                    completion(
                        .failure(
                            NSError(
                                domain: "",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "アカウント作成に失敗しました"]
                            )
                        )
                    )
                }
                return
            }

            self?.db.collection("users").document(user.uid).setData([
                "userId": user.uid,
                "name": name,
                "email": email,
                "currentCircleId": NSNull(),
                "createdAt": Timestamp()
            ]) { error in
                if let error {
                    Task { @MainActor in
                        completion(.failure(error))
                    }
                    return
                }

                Task { @MainActor in
                    self?.currentUserName = name
                    self?.applyAuthUser(user)
                    completion(.success(()))
                }
            }
        }
    }

    func logout() {
        do {
            try Auth.auth().signOut()
            applyAuthUser(nil)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func applyAuthUser(_ user: User?) {
        if let user, !user.isAnonymous {
            uid = user.uid
            currentUserEmail = user.email
            isReady = true
            lastError = nil
            fetchUserProfile()
        } else {
            uid = nil
            currentUserEmail = nil
            currentUserName = ""
            isReady = false
        }
    }

    private func fetchUserProfile() {
        guard let uid else { return }

        db.collection("users").document(uid).getDocument { [weak self] snapshot, _ in
            Task { @MainActor in
                guard let self, self.uid == uid else { return }
                let name = snapshot?.data()?["name"] as? String ?? ""
                if !name.isEmpty {
                    self.currentUserName = name
                }
            }
        }
    }

    static func loginErrorMessage(for error: Error) -> String {
        authFormErrorMessage(for: error, fallback: "ログインに失敗しました")
    }

    static func signUpErrorMessage(for error: Error) -> String {
        authFormErrorMessage(for: error, fallback: "アカウント作成に失敗しました")
    }

    private static func authFormErrorMessage(for error: Error, fallback: String) -> String {
        guard let errorCode = AuthErrorCode(rawValue: (error as NSError).code) else {
            return fallback
        }

        switch errorCode.code {
        case .invalidEmail:
            return "メールアドレスの形式が正しくありません"
        case .wrongPassword:
            return "パスワードが違います"
        case .userNotFound:
            return "アカウントが存在しません"
        case .emailAlreadyInUse:
            return "このメールアドレスは既に使用されています"
        case .weakPassword:
            return "パスワードは6文字以上で入力してください"
        case .networkError:
            return "通信エラーが発生しました"
        case .tooManyRequests:
            return "試行回数が多すぎます。少し待ってください"
        default:
            return fallback
        }
    }

    private static var configurationError: NSError {
        NSError(
            domain: "",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Firebase が設定されていません"]
        )
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
