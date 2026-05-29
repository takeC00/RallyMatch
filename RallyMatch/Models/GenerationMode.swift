import Foundation

enum GenerationMode: String, Codable, CaseIterable, Identifiable {
    case mix = "A"
    case separated = "B"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mix: "モードA（ミックス）"
        case .separated: "モードB（レベル分離）"
        }
    }
}
