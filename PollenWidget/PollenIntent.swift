import AppIntents
import SwiftUI
import WidgetKit

enum PollenPeriod: String, AppEnum {
    case today
    case tomorrow
    case week

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Période")
    }

    static var caseDisplayRepresentations: [PollenPeriod: DisplayRepresentation] {
        [
            .today: DisplayRepresentation(title: "Aujourd'hui"),
            .tomorrow: DisplayRepresentation(title: "Demain"),
            .week: DisplayRepresentation(title: "7 prochains jours"),
        ]
    }

    var label: String {
        switch self {
        case .today: "Aujourd'hui"
        case .tomorrow: "Demain"
        case .week: "7 prochains jours"
        }
    }

    var shortLabel: String {
        switch self {
        case .today: "Auj."
        case .tomorrow: "Demain"
        case .week: "7 j."
        }
    }
}

enum PollenKind: String, AppEnum, CaseIterable {
    case all
    case max
    case alder
    case birch
    case grass
    case mugwort
    case olive
    case ragweed

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Type de pollen")
    }

    static var caseDisplayRepresentations: [PollenKind: DisplayRepresentation] {
        [
            .all: DisplayRepresentation(title: "Tous (superposés)"),
            .max: DisplayRepresentation(title: "Maximum global"),
            .alder: DisplayRepresentation(title: "Aulne"),
            .birch: DisplayRepresentation(title: "Bouleau"),
            .grass: DisplayRepresentation(title: "Graminées"),
            .mugwort: DisplayRepresentation(title: "Armoise"),
            .olive: DisplayRepresentation(title: "Olivier"),
            .ragweed: DisplayRepresentation(title: "Ambroisie"),
        ]
    }

    var label: String {
        switch self {
        case .all: "Tous"
        case .max: "Max global"
        case .alder: "Aulne"
        case .birch: "Bouleau"
        case .grass: "Graminées"
        case .mugwort: "Armoise"
        case .olive: "Olivier"
        case .ragweed: "Ambroisie"
        }
    }

    var shortLabel: String {
        switch self {
        case .all: "Tous"
        case .max: "Max"
        case .alder: "Aul"
        case .birch: "Bou"
        case .grass: "Gra"
        case .mugwort: "Arm"
        case .olive: "Oli"
        case .ragweed: "Amb"
        }
    }

    var color: Color {
        switch self {
        case .all: Color(red: 0.40, green: 0.40, blue: 0.45)
        case .max: Color(red: 0.40, green: 0.40, blue: 0.45)
        case .alder: Color(red: 0.55, green: 0.42, blue: 0.30)
        case .birch: Color(red: 0.40, green: 0.65, blue: 0.85)
        case .grass: Color(red: 0.45, green: 0.75, blue: 0.45)
        case .mugwort: Color(red: 0.65, green: 0.50, blue: 0.85)
        case .olive: Color(red: 0.55, green: 0.65, blue: 0.40)
        case .ragweed: Color(red: 0.92, green: 0.55, blue: 0.20)
        }
    }

    static let concreteKinds: [PollenKind] = [.alder, .birch, .grass, .mugwort, .olive, .ragweed]
    static let switcherKinds: [PollenKind] = [.all, .max, .alder, .birch, .grass, .mugwort, .olive, .ragweed]
}

struct PollenConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration Pollen" }
    static var description: IntentDescription {
        IntentDescription("Affiche le taux de pollen pour une ville donnée.")
    }

    @Parameter(
        title: "Ville",
        description: "Nom de ville. Ajoutez le code pays pour lever l'ambiguïté (ex. Valencia, ES).",
        default: "Paris"
    )
    var city: String

    @Parameter(title: "Période par défaut", default: .today)
    var period: PollenPeriod

    init() {}

    init(city: String, period: PollenPeriod) {
        self.city = city
        self.period = period
    }
}

enum SelectedPeriodStore {
    private static let key = "selectedPeriod"

    static func read(default fallback: PollenPeriod) -> PollenPeriod {
        guard let raw = UserDefaults.standard.string(forKey: key),
              let value = PollenPeriod(rawValue: raw) else {
            return fallback
        }
        return value
    }

    static func write(_ period: PollenPeriod) {
        UserDefaults.standard.set(period.rawValue, forKey: key)
    }
}

enum SelectedKindStore {
    private static let key = "selectedKind"

    static func read(default fallback: PollenKind) -> PollenKind {
        guard let raw = UserDefaults.standard.string(forKey: key),
              let value = PollenKind(rawValue: raw) else {
            return fallback
        }
        return value
    }

    static func write(_ kind: PollenKind) {
        UserDefaults.standard.set(kind.rawValue, forKey: key)
    }
}

struct NavigatePeriodIntent: AppIntent {
    static var title: LocalizedStringResource { "Naviguer la période" }
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Période")
    var period: PollenPeriod

    init() {}

    init(_ period: PollenPeriod) {
        self.period = period
    }

    func perform() async throws -> some IntentResult {
        SelectedPeriodStore.write(period)
        return .result()
    }
}

struct NavigateKindIntent: AppIntent {
    static var title: LocalizedStringResource { "Naviguer le pollen" }
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Type")
    var kind: PollenKind

    init() {}

    init(_ kind: PollenKind) {
        self.kind = kind
    }

    func perform() async throws -> some IntentResult {
        SelectedKindStore.write(kind)
        return .result()
    }
}
