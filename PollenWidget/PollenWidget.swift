import WidgetKit
import SwiftUI

struct PollenWidget: Widget {
    let kind: String = "PollenWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: PollenConfigurationIntent.self,
            provider: PollenProvider()
        ) { entry in
            PollenWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    AtmosphericBackground(entry: entry)
                }
        }
        .configurationDisplayName("Pollen")
        .description("Suivez le taux de pollen dans votre ville.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct AtmosphericBackground: View {
    let entry: PollenEntry

    var body: some View {
        let risk = entry.headline.map { PollenRisk.from($0.value) } ?? .low
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    SIMD2<Float>(0.0, 0.0),  SIMD2<Float>(0.5, 0.0),  SIMD2<Float>(1.0, 0.0),
                    SIMD2<Float>(0.0, 0.45), SIMD2<Float>(0.55, 0.4), SIMD2<Float>(1.0, 0.5),
                    SIMD2<Float>(0.0, 1.0),  SIMD2<Float>(0.5, 1.0),  SIMD2<Float>(1.0, 1.0),
                ],
                colors: [
                    risk.color.opacity(0.32), risk.color.opacity(0.20), risk.color.opacity(0.08),
                    risk.color.opacity(0.18), risk.color.opacity(0.10), Color.clear,
                    Color.clear, Color.clear, Color.clear,
                ],
                smoothsColors: true
            )
        }
    }
}
