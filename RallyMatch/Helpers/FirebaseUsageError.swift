import Foundation
import FirebaseFirestore

/// Firestore / Auth の利用上限超過を検知し、利用者向けメッセージに変換する。
enum FirebaseUsageError {
    static let quotaExceededMessage = """
    Firebase の利用上限に達したため、クラウド連携を一時的に利用できません。\
    しばらく時間をおくか、翌日になってから再度お試しください。\
    主催者は Firebase Console の「使用状況」で残量を確認できます。
    """

    static func isQuotaExceeded(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == FirestoreErrorDomain,
           ns.code == FirestoreErrorCode.resourceExhausted.rawValue {
            return true
        }
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error,
           isQuotaExceeded(underlying) {
            return true
        }
        let text = [
            ns.localizedDescription,
            ns.localizedFailureReason,
            ns.localizedRecoverySuggestion,
        ]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        return text.contains("quota")
            || text.contains("resource exhausted")
            || text.contains("resource-exhausted")
    }

    static func userFacingMessage(for error: Error, context: String? = nil) -> String {
        if isQuotaExceeded(error) {
            return quotaExceededMessage
        }
        if let context {
            return "\(context): \(error.localizedDescription)"
        }
        return error.localizedDescription
    }
}
