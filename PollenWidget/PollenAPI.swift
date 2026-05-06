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

    static func airQuality(latitude: Double, longitude: Double, days: Int) async throws -> AirQualityResponse {
        var components = URLComponents(string: "https://air-quality-api.open-meteo.com/v1/air-quality")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "hourly", value: "alder_pollen,birch_pollen,grass_pollen,mugwort_pollen,olive_pollen,ragweed_pollen"),
            URLQueryItem(name: "forecast_days", value: String(days)),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        guard let url = components?.url else { throw PollenAPIError.invalidURL }

        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(AirQualityResponse.self, from: data)
    }

    static func samplesByKind(for response: AirQualityResponse, period: PollenPeriod, referenceDate: Date = Date()) -> [PollenKind: [PollenSample]] {
        var result: [PollenKind: [PollenSample]] = [:]
        for kind in PollenKind.concreteKinds {
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
            return raw.filter { calendar.isDate($0.date, inSameDayAs: now) }
        case .tomorrow:
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return [] }
            return raw.filter { calendar.isDate($0.date, inSameDayAs: tomorrow) }
        case .week:
            let startOfToday = calendar.startOfDay(for: now)
            let weekRange = raw.filter { $0.date >= startOfToday }
            let grouped = Dictionary(grouping: weekRange) { calendar.startOfDay(for: $0.date) }
            return grouped.map { (day, items) in
                PollenSample(date: day, value: items.map(\.value).max() ?? 0)
            }
            .sorted { $0.date < $1.date }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
