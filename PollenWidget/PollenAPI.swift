import Foundation

enum PollenAPIError: LocalizedError {
    case cityNotFound(String)
    case invalidURL
    case noData

    var errorDescription: String? {
        switch self {
        case .cityNotFound(let city): return "Ville introuvable : \(city)"
        case .invalidURL: return "URL invalide"
        case .noData: return "Pas de données pollen"
        }
    }
}

struct PollenAPI {
    static func parseCityQuery(_ raw: String) -> (name: String, countryCode: String?) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return (trimmed, nil) }

        let nameSide = parts[0].trimmingCharacters(in: .whitespaces)
        let codeSide = parts[1].trimmingCharacters(in: .whitespaces)

        if codeSide.count == 2, codeSide.allSatisfy({ $0.isLetter }) {
            return (nameSide, codeSide.uppercased())
        }
        return (trimmed, nil)
    }

    static func geocodeCandidates(for query: String, count: Int = 8) async throws -> [GeocodingResponse.Result] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let (name, countryCode) = parseCityQuery(trimmed)

        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        var items: [URLQueryItem] = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "count", value: String(count)),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "format", value: "json"),
        ]
        if let countryCode {
            items.append(URLQueryItem(name: "countryCode", value: countryCode))
        }
        components?.queryItems = items
        guard let url = components?.url else { throw PollenAPIError.invalidURL }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(GeocodingResponse.self, from: data)
        return response.results ?? []
    }

    // MARK: - Ambee

    private final class BundleToken {}

    static var ambeeAPIKey: String? {
        let raw = Bundle(for: BundleToken.self).object(forInfoDictionaryKey: "AmbeeAPIKey") as? String
        guard let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }

    static func ambeeForecast(latitude: Double, longitude: Double) async throws -> AmbeeForecastResponse? {
        guard let apiKey = ambeeAPIKey else { return nil }

        var components = URLComponents(string: "https://api.ambeedata.com/forecast/pollen/by-lat-lng")
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lng", value: String(longitude)),
        ]
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 8

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return nil
        }
        return try? JSONDecoder().decode(AmbeeForecastResponse.self, from: data)
    }

    /// Map Ambee species names → PollenKind. Returns samples per kind.
    static func samplesByKindFromAmbee(_ response: AmbeeForecastResponse, period: PollenPeriod, referenceDate: Date = Date()) -> [PollenKind: [PollenSample]] {
        let mapping: [(String, PollenKind, KeyPath<AmbeeSpecies, [String: Double]?>)] = [
            ("Alder", .alder, \.Tree),
            ("Birch", .birch, \.Tree),
            ("Cypress", .cypress, \.Tree),
            ("Cypress / Pine", .cypress, \.Tree),
            ("Hazel", .hazel, \.Tree),
            ("Oak", .oak, \.Tree),
            ("Pine", .pine, \.Tree),
            ("Plane", .plane, \.Tree),
            ("Ash", .ash, \.Tree),
            ("Olive", .olive, \.Tree),
            ("Mugwort", .mugwort, \.Weed),
            ("Nettle", .nettle, \.Weed),
            ("Pellitory", .nettle, \.Weed),
            ("Ragweed", .ragweed, \.Weed),
            ("Plantain", .plantain, \.Weed),
            ("Grass / Poaceae", .grass, \.Grass),
            ("Grass", .grass, \.Grass),
            ("Poaceae", .grass, \.Grass),
        ]

        var raw: [PollenKind: [PollenSample]] = [:]
        for entry in response.data {
            let date = Date(timeIntervalSince1970: entry.time)
            guard let species = entry.Species else { continue }
            for (label, kind, keyPath) in mapping {
                if let dict = species[keyPath: keyPath], let value = dict[label] {
                    raw[kind, default: []].append(PollenSample(date: date, value: max(0, value)))
                }
            }
        }

        var reduced: [PollenKind: [PollenSample]] = [:]
        for (kind, samples) in raw {
            reduced[kind] = reduce(samples: samples.sorted { $0.date < $1.date }, period: period, referenceDate: referenceDate)
        }
        return reduced
    }

    static func airQuality(latitude: Double, longitude: Double, days: Int) async throws -> AirQualityResponse {
        var components = URLComponents(string: "https://air-quality-api.open-meteo.com/v1/air-quality")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "hourly", value: "alder_pollen,birch_pollen,grass_pollen,mugwort_pollen,olive_pollen,ragweed_pollen,pm2_5,pm10,ozone,nitrogen_dioxide"),
            URLQueryItem(name: "forecast_days", value: String(days)),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        guard let url = components?.url else { throw PollenAPIError.invalidURL }

        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(AirQualityResponse.self, from: data)
    }

    /// Échantillons sur aujourd'hui ET demain combinés (sans doublons sur la frontière).
    /// Utile pour les fenêtres temporelles qui chevauchent les deux jours.
    static func todayAndTomorrowSamples(
        for response: AirQualityResponse,
        kind: PollenKind,
        referenceDate: Date = Date()
    ) -> [PollenSample] {
        let t1 = samples(for: response, kind: kind, period: .today, referenceDate: referenceDate)
        let t2 = samples(for: response, kind: kind, period: .tomorrow, referenceDate: referenceDate)
        var seen = Set<Date>()
        return (t1 + t2)
            .filter { seen.insert($0.date).inserted }
            .sorted { $0.date < $1.date }
    }

    static func samplesByKind(for response: AirQualityResponse, period: PollenPeriod, referenceDate: Date = Date()) -> [PollenKind: [PollenSample]] {
        var result: [PollenKind: [PollenSample]] = [:]
        for kind in PollenKind.concreteKinds {
            result[kind] = samples(for: response, kind: kind, period: period, referenceDate: referenceDate)
        }
        for kind in PollenKind.airKinds {
            result[kind] = samples(for: response, kind: kind, period: period, referenceDate: referenceDate)
        }
        return result
    }

    static func maxSamples(from byKind: [PollenKind: [PollenSample]]) -> [PollenSample] {
        var byDate: [Date: Double] = [:]
        for (_, list) in byKind {
            for sample in list {
                byDate[sample.date] = max(byDate[sample.date] ?? 0, sample.value)
            }
        }
        return byDate.map { PollenSample(date: $0.key, value: $0.value) }.sorted { $0.date < $1.date }
    }

    static func samples(for response: AirQualityResponse, kind: PollenKind, period: PollenPeriod, referenceDate: Date = Date()) -> [PollenSample] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current

        let times = response.hourly.time.compactMap { formatter.date(from: $0) }
        let count = min(times.count, response.hourly.time.count)

        let values: [Double?] = (0..<count).map { i in
            switch kind {
            case .all, .max:
                let candidates: [Double?] = [
                    response.hourly.alder_pollen?[safe: i] ?? nil,
                    response.hourly.birch_pollen?[safe: i] ?? nil,
                    response.hourly.grass_pollen?[safe: i] ?? nil,
                    response.hourly.mugwort_pollen?[safe: i] ?? nil,
                    response.hourly.olive_pollen?[safe: i] ?? nil,
                    response.hourly.ragweed_pollen?[safe: i] ?? nil,
                ]
                return candidates.compactMap { $0 }.max()
            case .alder: return response.hourly.alder_pollen?[safe: i] ?? nil
            case .birch: return response.hourly.birch_pollen?[safe: i] ?? nil
            case .grass: return response.hourly.grass_pollen?[safe: i] ?? nil
            case .mugwort: return response.hourly.mugwort_pollen?[safe: i] ?? nil
            case .olive: return response.hourly.olive_pollen?[safe: i] ?? nil
            case .ragweed: return response.hourly.ragweed_pollen?[safe: i] ?? nil
            case .cypress, .plane, .hazel, .plantain, .nettle, .oak, .ash, .pine, .air:
                return nil // Espèces fournies par Ambee uniquement (ou mode air)
            case .pm25: return response.hourly.pm2_5?[safe: i] ?? nil
            case .pm10: return response.hourly.pm10?[safe: i] ?? nil
            case .ozone: return response.hourly.ozone?[safe: i] ?? nil
            case .no2: return response.hourly.nitrogen_dioxide?[safe: i] ?? nil
            }
        }

        let raw = zip(times, values).compactMap { (date, val) -> PollenSample? in
            guard let v = val else { return nil }
            return PollenSample(date: date, value: max(0, v))
        }

        return reduce(samples: raw, period: period, referenceDate: referenceDate)
    }

    static func reduce(samples raw: [PollenSample], period: PollenPeriod, referenceDate: Date = Date()) -> [PollenSample] {
        let calendar = Calendar.current
        let now = referenceDate

        switch period {
        case .today:
            let mainDay = raw.filter { calendar.isDate($0.date, inSameDayAs: now) }
            // Inclure le 00:00 du lendemain comme point frontière pour que la courbe
            // couvre toute la journée jusqu'à 24h (= 00h du jour suivant).
            let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            if let target = startOfTomorrow,
               let boundary = raw.first(where: {
                   calendar.isDate($0.date, equalTo: target, toGranularity: .hour) && $0.date >= target
               }) {
                return mainDay + [boundary]
            }
            return mainDay
        case .tomorrow:
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return [] }
            let mainDay = raw.filter { calendar.isDate($0.date, inSameDayAs: tomorrow) }
            let startOfDayAfter = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: now))
            if let target = startOfDayAfter,
               let boundary = raw.first(where: {
                   calendar.isDate($0.date, equalTo: target, toGranularity: .hour) && $0.date >= target
               }) {
                return mainDay + [boundary]
            }
            return mainDay
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
