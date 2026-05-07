import Foundation
import SwiftUI

/// Représente une fenêtre temporelle (« cet après-midi », « demain matin »…) avec
/// l'interprétation des données pollens + polluants en langage naturel.
struct LiveWindow: Identifiable {
    let id = UUID()
    let title: String
    let timeRange: String
    let start: Date
    let end: Date
    let risk: PollenRisk
    let summary: String
    let highlights: [Highlight]

    struct Highlight: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
        let value: String
        let color: Color
    }
}

enum LiveInterpreter {
    /// Snapshot des valeurs à l'heure actuelle pour chaque pollen / polluant.
    static func currentSnapshot(
        from response: AirQualityResponse,
        ambee: AmbeeForecastResponse?,
        now: Date = Date()
    ) -> DataSnapshot {
        var values: [String: Double] = [:]
        for kind in PollenKind.concreteKinds + PollenKind.airKinds {
            let samples = PollenAPI.samples(for: response, kind: kind, period: .week, referenceDate: now)
            if let nearest = samples.min(by: {
                abs($0.date.timeIntervalSince(now)) < abs($1.date.timeIntervalSince(now))
            }) {
                values[kind.rawValue] = nearest.value
            }
        }
        if let ambee {
            let ambeeKind = PollenAPI.samplesByKindFromAmbee(ambee, period: .week, referenceDate: now)
            let openMeteoCovered: Set<PollenKind> = [.alder, .birch, .grass, .mugwort, .olive, .ragweed]
            for (kind, samples) in ambeeKind where !samples.isEmpty {
                if openMeteoCovered.contains(kind) { continue }
                if let nearest = samples.min(by: {
                    abs($0.date.timeIntervalSince(now)) < abs($1.date.timeIntervalSince(now))
                }) {
                    values[kind.rawValue] = nearest.value
                }
            }
        }
        return DataSnapshot(values: values)
    }

    /// Construit une série de fenêtres pour aujourd'hui et demain, avec interprétation.
    static func windows(
        from response: AirQualityResponse,
        ambee: AmbeeForecastResponse?,
        cityName: String,
        now: Date = Date()
    ) -> [LiveWindow] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }

        let definitions: [(title: String, hourStart: Int, hourEnd: Int, dayStart: Date)] = [
            ("Maintenant", calendar.component(.hour, from: now), calendar.component(.hour, from: now) + 2, today),
            ("Cet après-midi", 14, 19, today),
            ("Cette nuit", 22, 28, today),  // 22h aujourd'hui → 4h demain
            ("Demain matin", 7, 12, tomorrow),
            ("Demain après-midi", 14, 19, tomorrow),
            ("Demain soir", 19, 23, tomorrow),
        ]

        var byKind: [PollenKind: [PollenSample]] = [:]
        for kind in PollenKind.concreteKinds + PollenKind.airKinds {
            byKind[kind] = PollenAPI.samples(for: response, kind: kind, period: .week, referenceDate: now)
        }
        if let ambee {
            let ambeeKind = PollenAPI.samplesByKindFromAmbee(ambee, period: .week, referenceDate: now)
            let openMeteoCovered: Set<PollenKind> = [.alder, .birch, .grass, .mugwort, .olive, .ragweed]
            for (k, list) in ambeeKind where !list.isEmpty {
                if !openMeteoCovered.contains(k) { byKind[k] = list }
            }
        }

        var results: [LiveWindow] = []
        for def in definitions {
            let startHour = def.hourStart
            let endHour = def.hourEnd
            let dayStart = def.dayStart
            guard let windowStart = calendar.date(byAdding: .hour, value: startHour, to: dayStart),
                  let windowEnd = calendar.date(byAdding: .hour, value: endHour, to: dayStart) else { continue }
            // Skip windows entirely in the past
            if windowEnd <= now { continue }
            results.append(buildWindow(
                title: def.title,
                start: windowStart,
                end: windowEnd,
                byKind: byKind
            ))
        }
        return results
    }

    private static func buildWindow(
        title: String,
        start: Date,
        end: Date,
        byKind: [PollenKind: [PollenSample]]
    ) -> LiveWindow {
        // Find max value for each kind in the window
        var maxByKind: [PollenKind: Double] = [:]
        for (kind, samples) in byKind {
            let inWindow = samples.filter { $0.date >= start && $0.date <= end }
            if let m = inWindow.map(\.value).max() {
                maxByKind[kind] = m
            }
        }

        // Find the dominant pollen
        let dominantPollen: (kind: PollenKind, value: Double)? = {
            var best: (PollenKind, Double)?
            for kind in PollenKind.concreteKinds {
                guard let v = maxByKind[kind], v > (best?.1 ?? 0) else { continue }
                best = (kind, v)
            }
            return best
        }()

        // Find the worst pollutant by its own thresholds
        let worstPollutant: (kind: PollenKind, value: Double, risk: PollenRisk)? = {
            let order: [PollenRisk] = [.low, .moderate, .high, .veryHigh]
            var best: (PollenKind, Double, PollenRisk, Int)?
            for kind in PollenKind.airKinds {
                guard let v = maxByKind[kind] else { continue }
                let risk = PollenRisk.from(v, kind: kind)
                let idx = order.firstIndex(of: risk) ?? 0
                if best == nil || idx > best!.3 {
                    best = (kind, v, risk, idx)
                }
            }
            return best.map { ($0.0, $0.1, $0.2) }
        }()

        // Overall risk = max(pollen risk, pollutant risk)
        let pollenRisk: PollenRisk = dominantPollen.map { PollenRisk.from($0.value) } ?? .low
        let pollutantRisk: PollenRisk = worstPollutant?.risk ?? .low
        let overall = max(pollenRisk, pollutantRisk)

        let timeRange = formatRange(start: start, end: end)
        let summary = composeSummary(
            pollen: dominantPollen,
            pollutant: worstPollutant,
            overall: overall
        )
        let highlights = composeHighlights(
            pollen: dominantPollen,
            pollutant: worstPollutant
        )

        return LiveWindow(
            title: title,
            timeRange: timeRange,
            start: start,
            end: end,
            risk: overall,
            summary: summary,
            highlights: highlights
        )
    }

    private static func formatRange(start: Date, end: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "HH'h'"
        let s = formatter.string(from: start)
        let e = formatter.string(from: end)
        let now = Date()
        let isTomorrow = !calendar.isDate(start, inSameDayAs: now)
        let prefix = isTomorrow ? "demain · " : ""
        return "\(prefix)\(s) – \(e)"
    }

    private static func composeSummary(
        pollen: (kind: PollenKind, value: Double)?,
        pollutant: (kind: PollenKind, value: Double, risk: PollenRisk)?,
        overall: PollenRisk
    ) -> String {
        switch overall {
        case .low:
            return "Tout est sous contrôle. Aucun symptôme attendu."
        case .moderate:
            if let pollen, pollen.value >= 20 {
                return "\(pollen.kind.label) à \(Int(pollen.value)) (modéré). Si tu es sensible : nez qui chatouille, un éternuement de temps en temps."
            }
            if let p = pollutant, p.value >= p.kind.riskThresholds.low {
                return "\(p.kind.label) un peu élevé (\(Int(p.value))). Légère gêne possible si tu es sensible."
            }
            return "Niveau modéré, sans facteur dominant."
        case .high:
            var parts: [String] = []
            if let pollen, pollen.value >= 50 {
                parts.append("\(pollen.kind.label) à \(Int(pollen.value)) (élevé)")
            }
            if let p = pollutant, p.risk == .high || p.risk == .veryHigh {
                parts.append("\(p.kind.label) à \(Int(p.value))")
            }
            let factors = parts.isEmpty ? "Niveau élevé" : parts.joined(separator: ", ")
            return "\(factors). Attendez-vous à : nez qui coule, yeux qui piquent, éternuements en série, gorge qui gratte. Pense à ton collyre."
        case .veryHigh:
            var parts: [String] = []
            if let pollen, pollen.value >= 100 {
                parts.append("\(pollen.kind.label) à \(Int(pollen.value)) (très élevé)")
            }
            if let p = pollutant, p.risk == .veryHigh {
                parts.append("\(p.kind.label) à \(Int(p.value))")
            }
            let factors = parts.isEmpty ? "Niveau très élevé" : parts.joined(separator: " + ")
            return "\(factors). Yeux rouges et larmoyants, nez bouché, fatigue, possibles maux de tête. Reste à l'intérieur si possible, fenêtres fermées. Antihistaminique avant exposition."
        }
    }

    private static func composeHighlights(
        pollen: (kind: PollenKind, value: Double)?,
        pollutant: (kind: PollenKind, value: Double, risk: PollenRisk)?
    ) -> [LiveWindow.Highlight] {
        var hl: [LiveWindow.Highlight] = []
        if let pollen, pollen.value > 0 {
            let risk = PollenRisk.from(pollen.value)
            hl.append(LiveWindow.Highlight(
                icon: "leaf.fill",
                label: pollen.kind.label,
                value: "\(Int(pollen.value))",
                color: risk.color
            ))
        }
        if let p = pollutant, p.value > 0 {
            hl.append(LiveWindow.Highlight(
                icon: "wind",
                label: p.kind.label,
                value: "\(Int(p.value))",
                color: p.risk.color
            ))
        }
        return hl
    }
}

extension PollenRisk: Comparable {
    private var rank: Int {
        switch self {
        case .low: 0
        case .moderate: 1
        case .high: 2
        case .veryHigh: 3
        }
    }

    public static func < (lhs: PollenRisk, rhs: PollenRisk) -> Bool {
        lhs.rank < rhs.rank
    }
}
