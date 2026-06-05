import Foundation
import FirebaseFirestore
import Observation

struct SessionPlayer: Identifiable, Hashable {
    let id: UUID
    var name: String
    var level: PlayerLevel

    init(id: UUID = UUID(), name: String, level: PlayerLevel) {
        self.id = id
        self.name = name
        self.level = level
    }

    init(from player: RosterPlayer) {
        self.id = player.playerId
        self.name = player.name
        self.level = player.level
    }
}

private struct StoredDayParticipant: Codable {
    let id: UUID
    let name: String
    let level: String

    init(from player: SessionPlayer) {
        id = player.id
        name = player.name
        level = player.level.rawValue
    }

    func toSessionPlayer() -> SessionPlayer? {
        guard let level = PlayerLevel(rawValue: level) else { return nil }
        return SessionPlayer(id: id, name: name, level: level)
    }
}

/// その日だけ参加する人（試合設定専用・永続しない）
@MainActor
@Observable
final class DayParticipantStore {
    static let shared = DayParticipantStore()

    private(set) var revision = 0
    private var cache: [String: [SessionPlayer]] = [:]
    private let defaults = UserDefaults.standard
    private let storageKey = "rallymatch.dayParticipants"

    private init() {
        purgeExpired()
        syncAllCachedToFirestore()
    }

    func participants(for circleId: String) -> [SessionPlayer] {
        purgeExpired()
        if let cached = cache[circleId] {
            return cached
        }
        let loaded = loadAll()[dayKey(for: circleId)] ?? []
        let players = loaded.compactMap { $0.toSessionPlayer() }
        cache[circleId] = players
        return players
    }

    func add(_ player: SessionPlayer, circleId: String) {
        purgeExpired()
        var list = participants(for: circleId)
        let trimmed = player.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !list.contains(where: { $0.name == trimmed }) else { return }

        list.append(SessionPlayer(id: player.id, name: trimmed, level: player.level))
        save(list, circleId: circleId)
    }

    func remove(id: UUID, circleId: String) {
        var list = participants(for: circleId)
        list.removeAll { $0.id == id }
        save(list, circleId: circleId)
    }

    func update(_ player: SessionPlayer, circleId: String) throws {
        purgeExpired()
        var list = participants(for: circleId)
        guard let index = list.firstIndex(where: { $0.id == player.id }) else {
            throw DayParticipantError.notFound
        }

        let trimmed = player.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DayParticipantError.invalidName
        }

        if list.contains(where: { $0.name == trimmed && $0.id != player.id }) {
            throw DayParticipantError.duplicateName
        }

        list[index] = SessionPlayer(id: player.id, name: trimmed, level: player.level)
        save(list, circleId: circleId)
    }

    private func save(_ players: [SessionPlayer], circleId: String) {
        var all = loadAll()
        all[dayKey(for: circleId)] = players.map(StoredDayParticipant.init(from:))
        persist(all)
        cache[circleId] = players
        revision &+= 1
        syncFirestore(circleId: circleId, players: players)
    }

    private func syncFirestore(circleId: String, players: [SessionPlayer]) {
        Task {
            await Self.syncDayParticipantsToFirestore(circleId: circleId, players: players)
        }
    }

    private func syncAllCachedToFirestore() {
        Task {
            let all = loadAll()
            let todaySuffix = VisitorExpiry.todayKeyInJST()
            for (key, stored) in all where key.hasSuffix(todaySuffix) {
                guard let circleId = Self.circleId(fromStorageKey: key) else { continue }
                let players = stored.compactMap { $0.toSessionPlayer() }
                await Self.syncDayParticipantsToFirestore(circleId: circleId, players: players)
            }
        }
    }

    private static func syncDayParticipantsToFirestore(
        circleId: String,
        players: [SessionPlayer]
    ) async {
        let db = Firestore.firestore()
        let dateKey = VisitorExpiry.todayKeyInJST()
        let collection = db.collection("circleDayParticipants")

        do {
            let snapshot = try await collection
                .whereField("circleId", isEqualTo: circleId)
                .getDocuments()

            let batch = db.batch()
            for document in snapshot.documents {
                let storedDateKey = document.data()["dateKey"] as? String
                if storedDateKey == dateKey {
                    batch.deleteDocument(document.reference)
                }
            }

            let now = Timestamp(date: .now)
            for player in players {
                let ref = collection.document(firestoreDocumentId(circleId: circleId, participantId: player.id))
                batch.setData([
                    "circleId": circleId,
                    "participantId": player.id.uuidString.lowercased(),
                    "name": player.name,
                    "level": player.level.rawValue,
                    "dateKey": dateKey,
                    "updatedAt": now,
                ], forDocument: ref)
            }

            try await batch.commit()
        } catch {
            // Mate 連携用の同期失敗はローカル利用を妨げない
        }
    }

    private static func deleteFirestoreDayParticipants(circleId: String, dateKey: String) async {
        let db = Firestore.firestore()
        do {
            let snapshot = try await db.collection("circleDayParticipants")
                .whereField("circleId", isEqualTo: circleId)
                .getDocuments()

            let batch = db.batch()
            for document in snapshot.documents where document.data()["dateKey"] as? String == dateKey {
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()
        } catch {
            // 期限切れ削除の失敗は無視
        }
    }

    private static func firestoreDocumentId(circleId: String, participantId: UUID) -> String {
        "\(circleId)_\(participantId.uuidString.lowercased())"
    }

    private static func circleId(fromStorageKey key: String) -> String? {
        guard key.count > 11 else { return nil }
        let dateSuffix = String(key.suffix(10))
        guard dateSuffix.contains("/") else { return nil }
        return String(key.dropLast(11))
    }

    private static func dateKey(fromStorageKey key: String) -> String? {
        guard key.count > 11 else { return nil }
        let dateSuffix = String(key.suffix(10))
        return dateSuffix.contains("/") ? dateSuffix : nil
    }

    private func dayKey(for circleId: String) -> String {
        "\(circleId)_\(VisitorExpiry.todayKeyInJST())"
    }

    private func loadAll() -> [String: [StoredDayParticipant]] {
        guard
            let data = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([String: [StoredDayParticipant]].self, from: data)
        else {
            return [:]
        }
        return decoded
    }

    private func persist(_ all: [String: [StoredDayParticipant]]) {
        guard let data = try? JSONEncoder().encode(all) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func purgeExpired() {
        let todaySuffix = VisitorExpiry.todayKeyInJST()
        var all = loadAll()
        let staleKeys = all.keys.filter { !$0.hasSuffix(todaySuffix) }
        guard !staleKeys.isEmpty else { return }
        for key in staleKeys {
            if let circleId = Self.circleId(fromStorageKey: key),
               let dateKey = Self.dateKey(fromStorageKey: key) {
                Task {
                    await Self.deleteFirestoreDayParticipants(circleId: circleId, dateKey: dateKey)
                }
            }
            all.removeValue(forKey: key)
        }
        persist(all)
        cache.removeAll()
        revision &+= 1
    }
}

enum DayParticipantError: LocalizedError {
    case invalidName
    case duplicateName
    case notFound

    var errorDescription: String? {
        switch self {
        case .invalidName: "表示名を入力してください"
        case .duplicateName: "同じ名前の参加者が既にいます"
        case .notFound: "参加者が見つかりません"
        }
    }
}
