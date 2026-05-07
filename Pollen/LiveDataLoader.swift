import Foundation
import SwiftUI

@MainActor
final class LiveDataLoader: ObservableObject {
    @Published var cityQuery: String = "Valencia, ES"
    @Published var resolvedCityName: String = ""
    @Published var resolvedCountry: String = ""
    @Published var windows: [LiveWindow] = []
    @Published var currentSnapshot: DataSnapshot?
    @Published var loading: Bool = false
    @Published var errorMessage: String?

    func load() async {
        loading = true
        errorMessage = nil
        defer { loading = false }

        do {
            let candidates = try await PollenAPI.geocodeCandidates(for: cityQuery, count: 5)
            guard let first = candidates.first else {
                errorMessage = "Ville introuvable : \(cityQuery)"
                return
            }
            resolvedCityName = first.name
            if let countryCode = first.country_code {
                let fr = Locale(identifier: "fr_FR")
                resolvedCountry = fr.localizedString(forRegionCode: countryCode) ?? first.country ?? ""
            } else {
                resolvedCountry = first.country ?? ""
            }

            async let openMeteo = PollenAPI.airQuality(
                latitude: first.latitude,
                longitude: first.longitude,
                days: 2
            )
            async let ambee = PollenAPI.ambeeForecast(
                latitude: first.latitude,
                longitude: first.longitude
            )

            let response = try await openMeteo
            let ambeeResp = (try? await ambee) ?? nil

            windows = LiveInterpreter.windows(
                from: response,
                ambee: ambeeResp,
                cityName: first.name
            )
            currentSnapshot = LiveInterpreter.currentSnapshot(
                from: response,
                ambee: ambeeResp
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
