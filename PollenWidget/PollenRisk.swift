import SwiftUI

enum PollenRisk: CaseIterable {
    case low
    case moderate
    case high
    case veryHigh

    static func from(_ value: Double) -> PollenRisk {
        switch value {
        case ..<20: return .low
        case ..<50: return .moderate
        case ..<100: return .high
        default: return .veryHigh
        }
    }

    var color: Color {
        switch self {
        case .low: Color(red: 0.30, green: 0.78, blue: 0.45)
        case .moderate: Color(red: 0.97, green: 0.78, blue: 0.30)
        case .high: Color(red: 0.96, green: 0.55, blue: 0.18)
        case .veryHigh: Color(red: 0.93, green: 0.30, blue: 0.30)
        }
    }

    var label: String {
        switch self {
        case .low: "Faible"
        case .moderate: "Modéré"
        case .high: "Élevé"
        case .veryHigh: "Très élevé"
        }
    }
}
