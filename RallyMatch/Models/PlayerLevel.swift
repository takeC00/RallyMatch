import Foundation

enum PlayerLevel: String, Codable, CaseIterable, Identifiable {
    case beginner
    case experienced

    var id: String { rawValue }

    var label: String {
        switch self {
        case .beginner: "初心者"
        case .experienced: "経験者"
        }
    }
}
