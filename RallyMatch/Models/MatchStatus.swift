import Foundation

enum MatchStatus: String, Codable, CaseIterable {
    case scheduled
    case done
    case cancelled
}
