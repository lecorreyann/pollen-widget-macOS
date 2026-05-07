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
        case .week: "Sur 7 jours"
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
    case air
    case alder
    case birch
    case grass
    case mugwort
    case olive
    case ragweed
    case cypress
    case plane
    case hazel
    case plantain
    case nettle
    case oak
    case ash
    case pine
    case pm25
    case pm10
    case ozone
    case no2

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Type de pollen")
    }

    static var caseDisplayRepresentations: [PollenKind: DisplayRepresentation] {
        [
            .all: DisplayRepresentation(title: "Tous (superposés)"),
            .max: DisplayRepresentation(title: "Maximum global"),
            .air: DisplayRepresentation(title: "Qualité de l'air"),
            .alder: DisplayRepresentation(title: "Aulne"),
            .birch: DisplayRepresentation(title: "Bouleau"),
            .grass: DisplayRepresentation(title: "Graminées"),
            .mugwort: DisplayRepresentation(title: "Armoise"),
            .olive: DisplayRepresentation(title: "Olivier"),
            .ragweed: DisplayRepresentation(title: "Ambroisie"),
            .cypress: DisplayRepresentation(title: "Cyprès"),
            .plane: DisplayRepresentation(title: "Platane"),
            .hazel: DisplayRepresentation(title: "Noisetier"),
            .plantain: DisplayRepresentation(title: "Plantain"),
            .nettle: DisplayRepresentation(title: "Pariétaire / Ortie"),
            .oak: DisplayRepresentation(title: "Chêne"),
            .ash: DisplayRepresentation(title: "Frêne"),
            .pine: DisplayRepresentation(title: "Pin"),
            .pm25: DisplayRepresentation(title: "PM2.5"),
            .pm10: DisplayRepresentation(title: "PM10"),
            .ozone: DisplayRepresentation(title: "Ozone"),
            .no2: DisplayRepresentation(title: "Dioxyde d'azote"),
        ]
    }

    var label: String {
        switch self {
        case .all: "Tous"
        case .max: "Max global"
        case .air: "Qualité de l'air"
        case .alder: "Aulne"
        case .birch: "Bouleau"
        case .grass: "Graminées"
        case .mugwort: "Armoise"
        case .olive: "Olivier"
        case .ragweed: "Ambroisie"
        case .cypress: "Cyprès"
        case .plane: "Platane"
        case .hazel: "Noisetier"
        case .plantain: "Plantain"
        case .nettle: "Pariétaire"
        case .oak: "Chêne"
        case .ash: "Frêne"
        case .pine: "Pin"
        case .pm25: "PM2.5"
        case .pm10: "PM10"
        case .ozone: "Ozone"
        case .no2: "NO₂"
        }
    }

    var shortLabel: String {
        switch self {
        case .all: "Tous"
        case .max: "Max"
        case .air: "Air"
        case .alder: "Aul"
        case .birch: "Bou"
        case .grass: "Gra"
        case .mugwort: "Arm"
        case .olive: "Oli"
        case .ragweed: "Amb"
        case .cypress: "Cyp"
        case .plane: "Pla"
        case .hazel: "Noi"
        case .plantain: "Pln"
        case .nettle: "Par"
        case .oak: "Chê"
        case .ash: "Frê"
        case .pine: "Pin"
        case .pm25: "PM2.5"
        case .pm10: "PM10"
        case .ozone: "O₃"
        case .no2: "NO₂"
        }
    }

    var color: Color {
        switch self {
        case .all: Color(red: 0.40, green: 0.40, blue: 0.45)
        case .max: Color(red: 0.40, green: 0.40, blue: 0.45)
        case .air: Color(red: 0.40, green: 0.40, blue: 0.45)
        case .alder: Color(red: 0.55, green: 0.42, blue: 0.30)
        case .birch: Color(red: 0.40, green: 0.65, blue: 0.85)
        case .grass: Color(red: 0.45, green: 0.75, blue: 0.45)
        case .mugwort: Color(red: 0.65, green: 0.50, blue: 0.85)
        case .olive: Color(red: 0.55, green: 0.65, blue: 0.40)
        case .ragweed: Color(red: 0.92, green: 0.55, blue: 0.20)
        case .cypress: Color(red: 0.30, green: 0.55, blue: 0.55)
        case .plane: Color(red: 0.70, green: 0.55, blue: 0.35)
        case .hazel: Color(red: 0.78, green: 0.55, blue: 0.30)
        case .plantain: Color(red: 0.55, green: 0.70, blue: 0.55)
        case .nettle: Color(red: 0.50, green: 0.60, blue: 0.30)
        case .oak: Color(red: 0.45, green: 0.35, blue: 0.20)
        case .ash: Color(red: 0.55, green: 0.50, blue: 0.45)
        case .pine: Color(red: 0.30, green: 0.45, blue: 0.30)
        case .pm25: Color(red: 0.85, green: 0.30, blue: 0.30)
        case .pm10: Color(red: 0.95, green: 0.50, blue: 0.20)
        case .ozone: Color(red: 0.55, green: 0.30, blue: 0.80)
        case .no2: Color(red: 0.50, green: 0.35, blue: 0.20)
        }
    }

    /// Risk thresholds for this kind (low / moderate / high boundaries).
    /// Pollens use grains/m³ (default), pollutants use µg/m³ from EU AQI guidelines.
    var riskThresholds: (low: Double, moderate: Double, high: Double) {
        switch self {
        case .pm25: return (10, 25, 50)
        case .pm10: return (20, 50, 100)
        case .ozone: return (60, 100, 180)
        case .no2: return (40, 90, 120)
        default: return (20, 50, 100)
        }
    }

    var isPollutant: Bool {
        switch self {
        case .pm25, .pm10, .ozone, .no2: return true
        default: return false
        }
    }

    static let concreteKinds: [PollenKind] = [
        .alder, .birch, .grass, .mugwort, .olive, .ragweed,
        .cypress, .plane, .hazel, .plantain, .nettle, .oak, .ash, .pine,
    ]
    static let airKinds: [PollenKind] = [.pm25, .pm10, .ozone, .no2]
    static let switcherKinds: [PollenKind] = [.all, .max, .air] + concreteKinds + airKinds
}

// MARK: - City Entity

struct CityEntity: AppEntity, Identifiable, Hashable {
    let id: String
    let name: String
    let country: String
    let countryCode: String?
    let admin1: String?
    let latitude: Double
    let longitude: Double

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Ville")
    }

    static var defaultQuery = CityQuery()

    var localizedCountry: String {
        if let countryCode {
            let frenchLocale = Locale(identifier: "fr_FR")
            if let localized = frenchLocale.localizedString(forRegionCode: countryCode), !localized.isEmpty {
                return localized
            }
        }
        return country
    }

    var displayRepresentation: DisplayRepresentation {
        var subtitleParts: [String] = []
        if let admin1, !admin1.isEmpty, admin1 != name {
            subtitleParts.append(admin1)
        }
        let cn = localizedCountry
        if !cn.isEmpty {
            subtitleParts.append(cn)
        }
        let subtitle = subtitleParts.joined(separator: ", ")

        return DisplayRepresentation(
            title: "\(name)",
            subtitle: subtitle.isEmpty ? nil : "\(subtitle)"
        )
    }

    static func encodeID(name: String, countryCode: String?, country: String, admin1: String?, latitude: Double, longitude: Double) -> String {
        let safe: (String) -> String = { $0.replacingOccurrences(of: "|", with: " ") }
        let parts = [
            safe(name),
            countryCode ?? "",
            safe(country),
            safe(admin1 ?? ""),
            String(latitude),
            String(longitude),
        ]
        return parts.joined(separator: "|")
    }

    static func decodeID(_ id: String) -> CityEntity? {
        let parts = id.components(separatedBy: "|")
        guard parts.count >= 6,
              let lat = Double(parts[4]),
              let lon = Double(parts[5]) else { return nil }
        return CityEntity(
            id: id,
            name: parts[0],
            country: parts[2],
            countryCode: parts[1].isEmpty ? nil : parts[1],
            admin1: parts[3].isEmpty ? nil : parts[3],
            latitude: lat,
            longitude: lon
        )
    }

    static let paris = CityEntity(
        id: encodeID(
            name: "Paris",
            countryCode: "FR",
            country: "France",
            admin1: "Île-de-France",
            latitude: 48.8566,
            longitude: 2.3522
        ),
        name: "Paris",
        country: "France",
        countryCode: "FR",
        admin1: "Île-de-France",
        latitude: 48.8566,
        longitude: 2.3522
    )

    static let suggested: [CityEntity] = [
        .paris,
        CityEntity(
            id: encodeID(name: "Lyon", countryCode: "FR", country: "France", admin1: "Auvergne-Rhône-Alpes", latitude: 45.7485, longitude: 4.8467),
            name: "Lyon", country: "France", countryCode: "FR", admin1: "Auvergne-Rhône-Alpes", latitude: 45.7485, longitude: 4.8467
        ),
        CityEntity(
            id: encodeID(name: "Marseille", countryCode: "FR", country: "France", admin1: "Provence-Alpes-Côte d'Azur", latitude: 43.2964, longitude: 5.3700),
            name: "Marseille", country: "France", countryCode: "FR", admin1: "Provence-Alpes-Côte d'Azur", latitude: 43.2964, longitude: 5.3700
        ),
        CityEntity(
            id: encodeID(name: "Toulouse", countryCode: "FR", country: "France", admin1: "Occitanie", latitude: 43.6043, longitude: 1.4437),
            name: "Toulouse", country: "France", countryCode: "FR", admin1: "Occitanie", latitude: 43.6043, longitude: 1.4437
        ),
        CityEntity(
            id: encodeID(name: "Nice", countryCode: "FR", country: "France", admin1: "Provence-Alpes-Côte d'Azur", latitude: 43.7102, longitude: 7.2620),
            name: "Nice", country: "France", countryCode: "FR", admin1: "Provence-Alpes-Côte d'Azur", latitude: 43.7102, longitude: 7.2620
        ),
    ]
}

struct CityQuery: EntityStringQuery {
    func entities(for identifiers: [CityEntity.ID]) async throws -> [CityEntity] {
        identifiers.compactMap { CityEntity.decodeID($0) }
    }

    func entities(matching string: String) async throws -> [CityEntity] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return CityEntity.suggested }
        let candidates = try await PollenAPI.geocodeCandidates(for: trimmed)
        return candidates.map { result in
            let id = CityEntity.encodeID(
                name: result.name,
                countryCode: result.country_code,
                country: result.country ?? "",
                admin1: result.admin1,
                latitude: result.latitude,
                longitude: result.longitude
            )
            return CityEntity(
                id: id,
                name: result.name,
                country: result.country ?? "",
                countryCode: result.country_code,
                admin1: result.admin1,
                latitude: result.latitude,
                longitude: result.longitude
            )
        }
    }

    func suggestedEntities() async throws -> [CityEntity] {
        CityEntity.suggested
    }
}

// MARK: - Configuration intent

struct PollenConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration Pollen" }
    static var description: IntentDescription {
        IntentDescription("Affiche le taux de pollen pour une ville donnée.")
    }

    @Parameter(title: "Ville")
    var city: CityEntity?

    init() {}

    init(city: CityEntity?) {
        self.city = city
    }

    var resolvedCity: CityEntity {
        city ?? .paris
    }
}

// MARK: - Local navigation state

enum SelectedPeriodStore {
    private static let key = "selectedPeriod"

    static func read(default fallback: PollenPeriod) -> PollenPeriod {
        guard let raw = UserDefaults.standard.string(forKey: key),
              let value = PollenPeriod(rawValue: raw) else {
            return fallback
        }
        // Migration : le mode 7 jours a été retiré (données Ambee limitées à 2 j).
        if value == .week { return .today }
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
