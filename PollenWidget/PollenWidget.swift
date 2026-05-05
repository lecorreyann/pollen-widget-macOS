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
                    BackgroundView(entry: entry)
                }
        }
        .configurationDisplayName("Pollen")
        .description("Suivez le taux de pollen dans votre ville.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct BackgroundView: View {
    let entry: PollenEntry

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            if let h = entry.headline {
                let risk = PollenRisk.from(h.value)
                LinearGradient(
                    stops: [
                        .init(color: risk.color.opacity(0.22), location: 0.0),
                        .init(color: risk.color.opacity(0.06), location: 0.55),
                        .init(color: Color.clear, location: 1.0),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color.primary.opacity(0.04)
            }
        }
    }
}
