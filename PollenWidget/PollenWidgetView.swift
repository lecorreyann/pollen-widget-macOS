import WidgetKit
import SwiftUI

struct PollenWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: PollenEntry

    var body: some View {
        Group {
            if let error = entry.error {
                ErrorView(message: error, city: entry.cityName)
            } else if entry.samples.isEmpty && entry.allKindSamples.isEmpty {
                ErrorView(message: "Pas de données disponibles", city: entry.cityName)
            } else {
                switch family {
                case .systemSmall: SmallView(entry: entry)
                case .systemMedium: MediumView(entry: entry)
                case .systemLarge: LargeView(entry: entry)
                default: MediumView(entry: entry)
                }
            }
        }
    }
}

// MARK: - Period switcher

struct PeriodSwitcher: View {
    let current: PollenPeriod
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 1) {
            ForEach([PollenPeriod.today, .tomorrow, .week], id: \.self) { period in
                Button(intent: NavigatePeriodIntent(period)) {
                    Text(period.shortLabel)
                        .font(.system(size: compact ? 9 : 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(period == current ? Color.primary : Color.secondary)
                        .padding(.horizontal, compact ? 6 : 9)
                        .padding(.vertical, compact ? 3 : 5)
                        .frame(maxWidth: compact ? .infinity : nil)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(period == current ? Color.primary.opacity(0.10) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.regularMaterial.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Mode switcher (Simple / Détaillé)

struct ModeSwitcher: View {
    let current: PollenKind
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 1) {
            modeButton(target: .max, label: "Simple", icon: "chart.line.uptrend.xyaxis")
            modeButton(target: .all, label: "Détaillé", icon: "chart.bar.xaxis")
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.regularMaterial.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
        )
    }

    @ViewBuilder
    private func modeButton(target: PollenKind, label: String, icon: String) -> some View {
        let active = current == target
        Button(intent: NavigateKindIntent(target)) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: compact ? 9 : 10, weight: .semibold))
                Text(label)
                    .font(.system(size: compact ? 10 : 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(active ? Color.primary : Color.secondary)
            .padding(.horizontal, compact ? 8 : 10)
            .padding(.vertical, compact ? 3 : 5)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(active ? Color.primary.opacity(0.10) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Kind legend (shown in détaillé mode)

struct KindLegend: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(PollenKind.concreteKinds, id: \.self) { kind in
                HStack(spacing: 3) {
                    Circle().fill(kind.color).frame(width: 6, height: 6)
                    Text(kind.shortLabel)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Risk badge

struct RiskBadge: View {
    let risk: PollenRisk
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 3 : 5) {
            Circle()
                .fill(risk.color)
                .frame(width: compact ? 6 : 8, height: compact ? 6 : 8)
            Text(risk.label)
                .font(.system(size: compact ? 9 : 11, weight: .semibold, design: .rounded))
                .foregroundStyle(risk.color)
        }
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 2 : 3)
        .background(Capsule().fill(risk.color.opacity(0.14)))
    }
}

// MARK: - Headline

enum HeadlineSize {
    case small, medium, large

    var fontSize: CGFloat {
        switch self {
        case .small: 32
        case .medium: 40
        case .large: 56
        }
    }

    var labelSize: CGFloat {
        switch self {
        case .small: 9
        case .medium: 10
        case .large: 11
        }
    }
}

struct HeadlineView: View {
    let label: String
    let value: Double
    let size: HeadlineSize

    var body: some View {
        let risk = PollenRisk.from(value)
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: size.labelSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(0.6)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(Int(value.rounded()))")
                    .font(.system(size: size.fontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                RiskBadge(risk: risk, compact: size == .small)
            }
        }
    }
}

struct InlineHeadline: View {
    let label: String
    let value: Double

    var body: some View {
        let risk = PollenRisk.from(value)
        HStack(spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(0.6)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(Int(value.rounded()))")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
            HStack(spacing: 3) {
                Circle().fill(risk.color).frame(width: 6, height: 6)
                Text(risk.label)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(risk.color)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Small

private struct SmallView: View {
    let entry: PollenEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.cityName)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                if !entry.citySubtitle.isEmpty {
                    Text(entry.citySubtitle)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if let h = entry.headline {
                HeadlineView(label: h.label, value: h.value, size: .small)
                    .invalidatableContent()
            }
            Spacer(minLength: 0)
            PeriodSwitcher(current: entry.currentPeriod, compact: true)
        }
    }
}

// MARK: - Medium

private struct MediumView: View {
    let entry: PollenEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(entry.cityName)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    if !entry.citySubtitle.isEmpty {
                        Text(entry.citySubtitle)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                PeriodSwitcher(current: entry.currentPeriod)
            }

            PollenChart(
                kind: entry.currentKind,
                samples: entry.samples,
                allKindSamples: entry.allKindSamples,
                period: entry.currentPeriod,
                compact: true
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .invalidatableContent()
            .overlay(alignment: .topTrailing) {
                if let h = entry.headline {
                    FloatingHeadline(label: h.label, value: h.value)
                        .invalidatableContent()
                        .padding(.top, 2)
                        .padding(.trailing, 4)
                }
            }

            HStack(spacing: 8) {
                ModeSwitcher(current: entry.currentKind, compact: true)
                    .frame(width: 150)
                if entry.currentKind == .all {
                    KindLegend()
                        .layoutPriority(1)
                }
            }
        }
    }
}

struct FloatingHeadline: View {
    let label: String
    let value: Double

    var body: some View {
        let risk = PollenRisk.from(value)
        VStack(alignment: .trailing, spacing: 0) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(0.6)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(spacing: 5) {
                Text("\(Int(value.rounded()))")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Circle().fill(risk.color).frame(width: 8, height: 8)
            }
            Text(risk.label)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(risk.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }
}

// MARK: - Large

private struct LargeView: View {
    let entry: PollenEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.cityName)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                    if !entry.citySubtitle.isEmpty {
                        Text(entry.citySubtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                PeriodSwitcher(current: entry.currentPeriod)
            }

            if let h = entry.headline {
                HeadlineView(label: h.label, value: h.value, size: .large)
                    .invalidatableContent()
            }

            PollenChart(
                kind: entry.currentKind,
                samples: entry.samples,
                allKindSamples: entry.allKindSamples,
                period: entry.currentPeriod
            )
            .frame(maxHeight: .infinity)
            .invalidatableContent()

            ModeSwitcher(current: entry.currentKind)

            if entry.currentKind == .all {
                KindLegend()
            } else {
                HStack(spacing: 0) {
                    ForEach(PollenRisk.allCases, id: \.self) { risk in
                        HStack(spacing: 4) {
                            Circle().fill(risk.color).frame(width: 6, height: 6)
                            Text(risk.label)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

// MARK: - Error

private struct ErrorView: View {
    let message: String
    let city: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            Text(city).font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview(as: .systemMedium) {
    PollenWidget()
} timeline: {
    let allSamples = PollenEntry.placeholderAllKindSamples()
    PollenEntry(
        date: Date(),
        configuration: PollenConfigurationIntent(),
        currentPeriod: .today,
        currentKind: .max,
        cityName: "Valence",
        citySubtitle: "Communauté Valencienne · Espagne",
        samples: PollenAPI.maxSamples(from: allSamples),
        allKindSamples: allSamples,
        error: nil
    )
}
