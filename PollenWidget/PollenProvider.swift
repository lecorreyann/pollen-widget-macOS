import WidgetKit
import SwiftUI

struct PollenEntry: TimelineEntry {
    let date: Date
    let configuration: PollenConfigurationIntent
    let currentPeriod: PollenPeriod
    let currentKind: PollenKind
    let cityName: String
    let citySubtitle: String
    let samples: [PollenSample]
    let allKindSamples: [PollenKind: [PollenSample]]
    let error: String?
}

struct PollenProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PollenEntry {
        let allSamples = PollenEntry.placeholderAllKindSamples()
        let maxSamples = PollenAPI.maxSamples(from: allSamples)
        return PollenEntry(
            date: Date(),
            configuration: PollenConfigurationIntent(),
            currentPeriod: .today,
            currentKind: .max,
            cityName: CityEntity.paris.name,
            citySubtitle: CityEntity.paris.localizedCountry,
            samples: maxSamples,
            allKindSamples: allSamples,
            error: nil
        )
    }

    func snapshot(for configuration: PollenConfigurationIntent, in context: Context) async -> PollenEntry {
        if context.isPreview {
            return placeholder(in: context)
        }
        return await fetch(configuration: configuration)
    }

    func timeline(for configuration: PollenConfigurationIntent, in context: Context) async -> Timeline<PollenEntry> {
        let period = SelectedPeriodStore.read(default: .today)
        let kind = SelectedKindStore.read(default: .max)
        let city = configuration.resolvedCity

        let calendar = Calendar.current
        let now = Date()

        // Fetch enough days to cover today rolling forward into tomorrow
        let days: Int
        switch period {
        case .today: days = 2
        case .tomorrow: days = 3
        case .week: days = 8
        }

        do {
            let response = try await PollenAPI.airQuality(
                latitude: city.latitude,
                longitude: city.longitude,
                days: days
            )

            // Build display dates: hourly snapshots over the next 24h, plus a forced one
            // just past midnight so the day boundary always triggers a new entry.
            var displayDates: [Date] = []
            for hourOffset in stride(from: 0, through: 24, by: 2) {
                if let d = calendar.date(byAdding: .hour, value: hourOffset, to: now) {
                    displayDates.append(d)
                }
            }
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: now),
               let midnight = calendar.date(bySettingHour: 0, minute: 1, second: 0, of: nextDay),
               midnight > now {
                if !displayDates.contains(where: { abs($0.timeIntervalSince(midnight)) < 30 * 60 }) {
                    displayDates.append(midnight)
                }
            }
            displayDates.sort()

            let entries = displayDates.map { date in
                makeEntry(
                    at: date,
                    configuration: configuration,
                    period: period,
                    kind: kind,
                    city: city,
                    response: response
                )
            }

            let lastDate = entries.last?.date ?? now.addingTimeInterval(3600)
            return Timeline(entries: entries, policy: .after(lastDate))
        } catch {
            let errorEntry = PollenEntry(
                date: now,
                configuration: configuration,
                currentPeriod: period,
                currentKind: kind,
                cityName: city.name,
                citySubtitle: city.localizedCountry,
                samples: [],
                allKindSamples: [:],
                error: error.localizedDescription
            )
            return Timeline(entries: [errorEntry], policy: .after(now.addingTimeInterval(15 * 60)))
        }
    }

    private func fetch(configuration: PollenConfigurationIntent) async -> PollenEntry {
        let period = SelectedPeriodStore.read(default: .today)
        let kind = SelectedKindStore.read(default: .max)
        let city = configuration.resolvedCity
        do {
            let days: Int
            switch period {
            case .today: days = 2
            case .tomorrow: days = 3
            case .week: days = 8
            }
            let response = try await PollenAPI.airQuality(latitude: city.latitude, longitude: city.longitude, days: days)
            return makeEntry(at: Date(), configuration: configuration, period: period, kind: kind, city: city, response: response)
        } catch {
            return PollenEntry(
                date: Date(),
                configuration: configuration,
                currentPeriod: period,
                currentKind: kind,
                cityName: city.name,
                citySubtitle: city.localizedCountry,
                samples: [],
                allKindSamples: [:],
                error: error.localizedDescription
            )
        }
    }

    private func makeEntry(
        at displayDate: Date,
        configuration: PollenConfigurationIntent,
        period: PollenPeriod,
        kind: PollenKind,
        city: CityEntity,
        response: AirQualityResponse
    ) -> PollenEntry {
        let allKind = PollenAPI.samplesByKind(for: response, period: period, referenceDate: displayDate)
        let displayed: [PollenSample]
        if kind == .max || kind == .all {
            displayed = PollenAPI.maxSamples(from: allKind)
        } else {
            displayed = allKind[kind] ?? []
        }
        return PollenEntry(
            date: displayDate,
            configuration: configuration,
            currentPeriod: period,
            currentKind: kind,
            cityName: city.name,
            citySubtitle: city.localizedCountry,
            samples: displayed,
            allKindSamples: allKind,
            error: nil
        )
    }
}

extension PollenEntry {
    struct Headline {
        let label: String
        let value: Double
        let kind: PollenKind?
    }

    var headline: Headline? {
        switch currentKind {
        case .all:
            return allHeadline()
        case .max:
            return singleHeadline(samples: samples, kindLabel: nil)
        default:
            return singleHeadline(samples: samples, kindLabel: currentKind.label)
        }
    }

    private func singleHeadline(samples: [PollenSample], kindLabel: String?) -> Headline? {
        guard !samples.isEmpty else { return nil }
        switch currentPeriod {
        case .today:
            let now = Date()
            guard let s = samples.min(by: {
                abs($0.date.timeIntervalSince(now)) < abs($1.date.timeIntervalSince(now))
            }) else { return nil }
            let label = kindLabel.map { "Maintenant · \($0)" } ?? "Maintenant"
            return Headline(label: label, value: s.value, kind: nil)
        case .tomorrow:
            guard let s = samples.max(by: { $0.value < $1.value }) else { return nil }
            let label = kindLabel.map { "Demain · \($0)" } ?? "Demain"
            return Headline(label: label, value: s.value, kind: nil)
        case .week:
            guard let s = samples.max(by: { $0.value < $1.value }) else { return nil }
            let label = kindLabel.map { "Sur 7 jours · \($0)" } ?? "Sur 7 jours"
            return Headline(label: label, value: s.value, kind: nil)
        }
    }

    private func allHeadline() -> Headline? {
        switch currentPeriod {
        case .today:
            let now = Date()
            var best: (kind: PollenKind, value: Double)?
            for kind in PollenKind.concreteKinds {
                guard let list = allKindSamples[kind],
                      let s = list.min(by: {
                          abs($0.date.timeIntervalSince(now)) < abs($1.date.timeIntervalSince(now))
                      }) else { continue }
                if s.value > (best?.value ?? -1) {
                    best = (kind, s.value)
                }
            }
            guard let best else { return nil }
            return Headline(label: "Maintenant · \(best.kind.label)", value: best.value, kind: best.kind)
        case .tomorrow, .week:
            var best: (kind: PollenKind, value: Double)?
            for kind in PollenKind.concreteKinds {
                guard let list = allKindSamples[kind],
                      let m = list.max(by: { $0.value < $1.value }) else { continue }
                if m.value > (best?.value ?? -1) {
                    best = (kind, m.value)
                }
            }
            guard let best else { return nil }
            let prefix = currentPeriod == .tomorrow ? "Demain" : "Sur 7 jours"
            return Headline(label: "\(prefix) · \(best.kind.label)", value: best.value, kind: best.kind)
        }
    }
}

extension PollenEntry {
    static func placeholderAllKindSamples() -> [PollenKind: [PollenSample]] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let patterns: [PollenKind: [Double]] = [
            .alder:    [3, 5, 8, 10, 14, 18, 22, 26, 30, 32, 30, 26, 22, 18, 14, 12, 10, 8, 6, 5, 4, 3, 3, 2],
            .birch:    [10, 14, 22, 32, 45, 58, 70, 82, 90, 95, 92, 85, 75, 62, 50, 40, 32, 25, 20, 16, 13, 11, 10, 8],
            .grass:    [5, 6, 8, 12, 18, 25, 32, 40, 50, 60, 70, 75, 78, 75, 68, 58, 45, 35, 25, 18, 13, 10, 8, 7],
            .mugwort:  [2, 3, 4, 5, 6, 8, 10, 13, 16, 18, 20, 19, 17, 15, 13, 11, 9, 7, 6, 5, 4, 3, 3, 2],
            .olive:    [4, 6, 9, 13, 18, 24, 30, 35, 40, 42, 40, 36, 30, 24, 18, 14, 11, 9, 7, 6, 5, 5, 4, 4],
            .ragweed:  [1, 1, 2, 3, 4, 6, 8, 10, 13, 16, 18, 18, 17, 15, 12, 9, 7, 5, 4, 3, 3, 2, 2, 1],
        ]
        var result: [PollenKind: [PollenSample]] = [:]
        for (kind, values) in patterns {
            result[kind] = values.enumerated().compactMap { (i, v) in
                guard let d = calendar.date(byAdding: .hour, value: i, to: start) else { return nil }
                return PollenSample(date: d, value: v)
            }
        }
        return result
    }
}
