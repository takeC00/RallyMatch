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
    private(set) var joinedCircles: [CloudCircle] = []
    private(set) var currentCircleId: String?
    private(set) var isLoadingCircles = false
    var lastError: String?

    private var authListener: AuthStateDidChangeListenerHandle?
    private var suppressAuthListener = false

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
        Task {
            do {
                try await signUp(email: email, password: password, name: name)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func signUp(email: String, password: String, name: String) async throws {
        guard configureIfNeeded() else {
            throw Self.configurationError
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw NSError(
                domain: "",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "表示名を入力してください"]
            )
        }

        suppressAuthListener = true
        defer { suppressAuthListener = false }

        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let user = result.user

        do {
            _ = try await user.getIDToken(forcingRefresh: true)
            let now = Timestamp()
            try await db.collection("users").document(user.uid).setData([
                "userId": user.uid,
                "name": trimmedName,
                "email": email,
                "currentCircleId": NSNull(),
                "createdAt": now,
                "updatedAt": now,
                "fcmTokens": []
            ])

            currentUserName = trimmedName
            applyAuthUser(user)
            await refreshCircles()
        } catch {
            try? await user.delete()
            uid = nil
            currentUserEmail = nil
            currentUserName = ""
            isReady = false
            throw error
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

    func createCircle(
        name: String,
        sportName: String,
        description: String,
        location: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard configureIfNeeded() else {
            completion(.failure(Self.configurationError))
            return
        }
        guard let uid else {
            completion(.failure(Self.configurationError))
            return
        }

        let document = db.collection("circles").document()
        let circleId = document.documentID
        let circleCode = String(circleId.prefix(6)).uppercased()
        let now = Timestamp()

        let circleData: [String: Any] = [
            "name": name,
            "description": description,
            "sportName": sportName,
            "location": location,
            "ownerId": uid,
            "memberIds": [uid],
            "circleCode": circleCode,
            "createdAt": now
        ]

        let memberId = "\(circleId)_\(uid)"
        let memberData: [String: Any] = [
            "circleId": circleId,
            "userId": uid,
            "userName": currentUserName.isEmpty ? name : currentUserName,
            "rating": 1500,
            "role": "admin",
            "joinedAt": now
        ]

        document.setData(circleData) { [weak self] error in
            if let error {
                completion(.failure(error))
                return
            }

            self?.db.collection("circleMembers").document(memberId).setData(memberData) { error in
                if let error {
                    completion(.failure(error))
                    return
                }

                self?.db.collection("users").document(uid).updateData([
                    "currentCircleId": circleId
                ]) { error in
                    if let error {
                        completion(.failure(error))
                        return
                    }
                    Task { @MainActor in
                        self?.currentCircleId = circleId
                        await self?.refreshCircles()
                        completion(.success(circleId))
                    }
                }
            }
        }
    }

    func refreshCircles() async {
        guard configureIfNeeded(), let uid else {
            joinedCircles = []
            currentCircleId = nil
            return
        }

        isLoadingCircles = true
        defer { isLoadingCircles = false }

        do {
            let userDoc = try await db.collection("users").document(uid).getDocument()
            currentCircleId = userDoc.data()?["currentCircleId"] as? String

            let snapshot = try await db.collection("circles")
                .whereField("memberIds", arrayContains: uid)
                .getDocuments()

            joinedCircles = snapshot.documents
                .compactMap { CloudCircle.from($0) }
                .sorted { $0.createdAt > $1.createdAt }

            if currentCircleId == nil {
                currentCircleId = joinedCircles.first?.id
            } else if let currentCircleId,
                      !joinedCircles.contains(where: { $0.id == currentCircleId }) {
                self.currentCircleId = joinedCircles.first?.id
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func setCurrentCircle(_ circleId: String) async throws {
        guard configureIfNeeded(), let uid else {
            throw Self.configurationError
        }

        try await db.collection("users").document(uid).updateData([
            "currentCircleId": circleId
        ])
        currentCircleId = circleId
    }

    func joinCircle(
        code: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard configureIfNeeded() else {
            completion(.failure(Self.configurationError))
            return
        }
        guard let uid else {
            completion(.failure(Self.configurationError))
            return
        }

        let normalizedCode = code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard !normalizedCode.isEmpty else {
            completion(
                .failure(
                    NSError(
                        domain: "",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "招待コードを入力してください"]
                    )
                )
            )
            return
        }

        db.collection("circles")
            .whereField("circleCode", isEqualTo: normalizedCode)
            .limit(to: 1)
            .getDocuments { [weak self] snapshot, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                guard let doc = snapshot?.documents.first else {
                    completion(
                        .failure(
                            NSError(
                                domain: "",
                                code: -3,
                                userInfo: [NSLocalizedDescriptionKey: "該当するサークルが見つかりません"]
                            )
                        )
                    )
                    return
                }

                let circleId = doc.documentID

                self?.db.collection("circles")
                    .document(circleId)
                    .updateData([
                        "memberIds": FieldValue.arrayUnion([uid])
                    ]) { error in
                        if let error {
                            completion(.failure(error))
                            return
                        }

                        self?.upsertMembership(circleId: circleId, userId: uid, role: "member") { result in
                            switch result {
                            case .failure(let error):
                                completion(.failure(error))
                            case .success:
                                self?.db.collection("users").document(uid).updateData([
                                    "currentCircleId": circleId
                                ]) { error in
                                    if let error {
                                        completion(.failure(error))
                                        return
                                    }
                                    Task { @MainActor in
                                        self?.currentCircleId = circleId
                                        await self?.refreshCircles()
                                        completion(.success(circleId))
                                    }
                                }
                            }
                        }
                    }
            }
    }

    private func upsertMembership(
        circleId: String,
        userId: String,
        role: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            if let error {
                completion(.failure(error))
                return
            }

            let userName = (snapshot?.data()?["name"] as? String)
                ?? (snapshot?.data()?["nickname"] as? String)
                ?? (self?.currentUserName ?? "")
            let displayName = userName.isEmpty ? "Unknown" : userName
            let docId = "\(circleId)_\(userId)"
            let data: [String: Any] = [
                "circleId": circleId,
                "userId": userId,
                "userName": displayName,
                "rating": 1500,
                "role": role,
                "joinedAt": Timestamp()
            ]

            self?.db.collection("circleMembers").document(docId).setData(data, merge: true) { error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }

    private func applyAuthUser(_ user: User?) {
        if suppressAuthListener { return }

        if let user, !user.isAnonymous {
            uid = user.uid
            currentUserEmail = user.email
            isReady = true
            lastError = nil
            fetchUserProfile()
            Task { await refreshCircles() }
        } else {
            uid = nil
            currentUserEmail = nil
            currentUserName = ""
            joinedCircles = []
            currentCircleId = nil
            isReady = false
        }
    }

    private func fetchUserProfile() {
        guard let uid else { return }

        db.collection("users").document(uid).getDocument { [weak self] snapshot, _ in
            Task { @MainActor in
                guard let self, self.uid == uid else { return }
                let name = (snapshot?.data()?["name"] as? String)
                    ?? (snapshot?.data()?["nickname"] as? String)
                    ?? ""
                if !name.isEmpty {
                    self.currentUserName = name
                }
            }
        }
    }

    static func signUpErrorMessage(for error: Error) -> String {
        if let message = authFormErrorMessage(for: error, fallback: nil) {
            return message
        }

        let nsError = error as NSError
        if nsError.domain == FirestoreErrorDomain,
           nsError.code == FirestoreErrorCode.permissionDenied.rawValue {
            return "プロフィールの保存に失敗しました。通信環境を確認して再度お試しください"
        }

        let description = nsError.localizedDescription
        if !description.isEmpty {
            return description
        }
        return "アカウント作成に失敗しました"
    }

    private static func authFormErrorMessage(for error: Error, fallback: String?) -> String? {
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

    static func loginErrorMessage(for error: Error) -> String {
        authFormErrorMessage(for: error, fallback: nil)
            ?? "ログインに失敗しました"
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
