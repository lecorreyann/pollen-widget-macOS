import Foundation
import SwiftUI

// MARK: - Models

enum Symptom: String, Codable, CaseIterable, Identifiable {
    case eyesItchy
    case eyesRed
    case runnyNose
    case stuffyNose
    case sneezing
    case soreThroat
    case cough
    case headache
    case fatigue
    case skinItchy

    var id: String { rawValue }

    var label: String {
        switch self {
        case .eyesItchy: "Yeux qui grattent"
        case .eyesRed: "Yeux rouges"
        case .runnyNose: "Nez qui coule"
        case .stuffyNose: "Nez bouché"
        case .sneezing: "Éternuements"
        case .soreThroat: "Gorge qui gratte"
        case .cough: "Toux"
        case .headache: "Mal de tête"
        case .fatigue: "Fatigue"
        case .skinItchy: "Peau qui démange"
        }
    }

    var icon: String {
        switch self {
        case .eyesItchy: "eye"
        case .eyesRed: "eye.fill"
        case .runnyNose: "drop"
        case .stuffyNose: "nose"
        case .sneezing: "wind"
        case .soreThroat: "mic.slash"
        case .cough: "lungs.fill"
        case .headache: "brain.head.profile"
        case .fatigue: "moon.zzz.fill"
        case .skinItchy: "hand.point.up.fill"
        }
    }

    var color: Color {
        switch self {
        case .eyesItchy, .eyesRed: Color(red: 0.93, green: 0.30, blue: 0.30)
        case .runnyNose, .stuffyNose, .sneezing: Color(red: 0.40, green: 0.65, blue: 0.85)
        case .soreThroat, .cough: Color(red: 0.96, green: 0.55, blue: 0.18)
        case .headache: Color(red: 0.65, green: 0.50, blue: 0.85)
        case .fatigue: Color(red: 0.55, green: 0.55, blue: 0.55)
        case .skinItchy: Color(red: 0.97, green: 0.78, blue: 0.30)
        }
    }
}

/// Snapshot des valeurs pollen + polluants au moment du log.
struct DataSnapshot: Codable, Hashable {
    /// Clé = PollenKind.rawValue, valeur = grains/m³ ou µg/m³
    var values: [String: Double]

    func value(for kind: PollenKind) -> Double? {
        values[kind.rawValue]
    }
}

struct SymptomLog: Codable, Identifiable, Hashable {
    let id: UUID
    let timestamp: Date
    let cityName: String
    let citySubtitle: String
    let symptoms: Set<Symptom>
    let notes: String
    let snapshot: DataSnapshot

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        cityName: String,
        citySubtitle: String,
        symptoms: Set<Symptom>,
        notes: String = "",
        snapshot: DataSnapshot
    ) {
        self.id = id
        self.timestamp = timestamp
        self.cityName = cityName
        self.citySubtitle = citySubtitle
        self.symptoms = symptoms
        self.notes = notes
        self.snapshot = snapshot
    }
}

// MARK: - Storage

@MainActor
final class SymptomJournal: ObservableObject {
    @Published private(set) var logs: [SymptomLog] = []

    private let key = "symptomLogs.v1"

    init() {
        load()
    }

    func add(_ log: SymptomLog) {
        logs.insert(log, at: 0)
        save()
    }

    func delete(_ log: SymptomLog) {
        logs.removeAll { $0.id == log.id }
        save()
    }

    func clear() {
        logs.removeAll()
        save()
    }

    /// Allergènes identifiés par croisement journal × données.
    /// Critère : ≥ 50 % des logs avec un symptôme allergique typique avaient ce
    /// pollen/polluant en niveau « élevé » ou plus, et au moins 3 logs au total.
    var personalAllergens: [(kind: PollenKind, percentage: Double)] {
        guard logs.count >= 3 else { return [] }
        let allergyRelevant: [Symptom] = [
            .eyesItchy, .eyesRed, .runnyNose, .stuffyNose,
            .sneezing, .soreThroat, .skinItchy,
        ]
        var bestPctByKind: [PollenKind: Double] = [:]
        for symptom in allergyRelevant {
            let candidates = SymptomAnalyser.candidates(for: symptom, in: logs)
            for c in candidates where c.percentage >= 50 && c.totalLogs >= 3 {
                bestPctByKind[c.kind] = max(bestPctByKind[c.kind] ?? 0, c.percentage)
            }
        }
        return bestPctByKind
            .map { (kind: $0.key, percentage: $0.value) }
            .sorted { $0.percentage > $1.percentage }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([SymptomLog].self, from: data) {
            logs = decoded.sorted { $0.timestamp > $1.timestamp }
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(logs) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Analyse

struct AllergenCandidate: Identifiable {
    let id = UUID()
    let kind: PollenKind
    let occurrencesHigh: Int
    let totalLogs: Int
    var percentage: Double {
        guard totalLogs > 0 else { return 0 }
        return Double(occurrencesHigh) / Double(totalLogs) * 100
    }
}

enum SymptomAnalyser {
    /// Pour chaque pollen / polluant, calcule la fréquence à laquelle il était
    /// au moins « élevé » lors d'un log contenant le symptôme demandé.
    static func candidates(for symptom: Symptom, in logs: [SymptomLog]) -> [AllergenCandidate] {
        let relevant = logs.filter { $0.symptoms.contains(symptom) }
        guard !relevant.isEmpty else { return [] }

        var counts: [PollenKind: Int] = [:]
        for log in relevant {
            for (rawKind, value) in log.snapshot.values {
                guard let kind = PollenKind(rawValue: rawKind) else { continue }
                let risk: PollenRisk
                if kind.isPollutant {
                    risk = PollenRisk.from(value, kind: kind)
                } else {
                    risk = PollenRisk.from(value)
                }
                if risk == .high || risk == .veryHigh {
                    counts[kind, default: 0] += 1
                }
            }
        }

        return counts.map { (kind, count) in
            AllergenCandidate(
                kind: kind,
                occurrencesHigh: count,
                totalLogs: relevant.count
            )
        }
        .filter { $0.percentage > 0 }
        .sorted { $0.percentage > $1.percentage }
    }
}
