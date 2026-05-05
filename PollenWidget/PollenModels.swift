import Foundation

struct GeocodingResponse: Decodable {
    let results: [Result]?

    struct Result: Decodable {
        let latitude: Double
        let longitude: Double
        let name: String
        let country: String?
        let country_code: String?
        let admin1: String?
    }
}

struct AirQualityResponse: Decodable {
    let hourly: Hourly

    struct Hourly: Decodable {
        let time: [String]
        let alder_pollen: [Double?]?
        let birch_pollen: [Double?]?
        let grass_pollen: [Double?]?
        let mugwort_pollen: [Double?]?
        let olive_pollen: [Double?]?
        let ragweed_pollen: [Double?]?
    }
}

struct PollenSample: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let value: Double

    static func == (lhs: PollenSample, rhs: PollenSample) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
