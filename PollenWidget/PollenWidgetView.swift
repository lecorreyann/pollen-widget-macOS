import WidgetKit
import SwiftUI

struct PollenWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: PollenEntry

    var body: some View {
        switch family {
        case .systemSmall: SmallView(entry: entry)
        case .systemMedium: MediumView(entry: entry)
        case .systemLarge: LargeView(entry: entry)
        default: MediumView(entry: entry)
        }
    }
}

// MARK: - Empty / error placeholder for chart area

struct ChartFallback: View {
    let message: String
    var compact: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: compact ? 16 : 22))
                .foregroundStyle(.orange.opacity(0.75))
            Text(message)
                .font(.system(size: compact ? 9 : 11, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension PollenEntry {
    var fallbackMessage: String? {
        if let error { return error }
        if samples.isEmpty && allKindSamples.isEmpty {
            return "Pas de données disponibles pour cette période"
        }
        return nil
    }
}

// MARK: - Period switcher

struct PeriodSwitcher: View {
    let current: PollenPeriod
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            ForEach([PollenPeriod.today, .tomorrow, .week], id: \.self) { period in
                periodButton(period)
            }
        }
    }

    @ViewBuilder
    private func periodButton(_ period: PollenPeriod) -> some View {
        let active = period == current
        Button(intent: NavigatePeriodIntent(period)) {
            Text(period.shortLabel)
                .font(.system(size: compact ? 10 : 11, weight: active ? .semibold : .medium, design: .rounded))
                .foregroundStyle(active ? Color.primary : Color.secondary.opacity(0.85))
                .padding(.horizontal, active ? (compact ? 8 : 10) : (compact ? 4 : 5))
                .padding(.vertical, active ? (compact ? 3 : 5) : 0)
                .background {
                    if active {
                        Capsule(style: .continuous)
                            .fill(.regularMaterial)
                            .shadow(color: Color.black.opacity(0.10), radius: 4, x: 0, y: 1)
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                            )
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mode switcher (Simple / Détaillé)

struct ModeSwitcher: View {
    let current: PollenKind
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            modeButton(target: .max, label: "Simple")
            modeButton(target: .all, label: "Détaillé")
        }
    }

    @ViewBuilder
    private func modeButton(target: PollenKind, label: String) -> some View {
        let active = current == target
        Button(intent: NavigateKindIntent(target)) {
            Text(label)
                .font(.system(size: compact ? 10 : 11, weight: active ? .semibold : .medium, design: .rounded))
                .foregroundStyle(active ? Color.primary : Color.secondary.opacity(0.85))
                .padding(.horizontal, active ? (compact ? 10 : 12) : (compact ? 4 : 6))
                .padding(.vertical, active ? (compact ? 3 : 5) : 0)
                .background {
                    if active {
                        Capsule(style: .continuous)
                            .fill(.regularMaterial)
                            .shadow(color: Color.black.opacity(0.10), radius: 4, x: 0, y: 1)
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                            )
                    }
                }
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
                .frame(width: compact ? 5 : 6, height: compact ? 5 : 6)
            Text(risk.label)
                .font(.system(size: compact ? 9 : 10, weight: .medium, design: .rounded))
                .foregroundStyle(risk.color)
        }
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
                .font(.system(size: size.labelSize, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(Int(value.rounded()))")
                    .font(.system(size: size.fontSize, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                RiskBadge(risk: risk, compact: size == .small)
            }
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
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .lineLimit(1)
                if !entry.citySubtitle.isEmpty {
                    Text(entry.citySubtitle.uppercased())
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if let fallback = entry.fallbackMessage {
                ChartFallback(message: fallback, compact: true)
                    .invalidatableContent()
            } else if let h = entry.headline {
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
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.cityName)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .lineLimit(1)
                    if !entry.citySubtitle.isEmpty {
                        Text(entry.citySubtitle.uppercased())
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .tracking(0.9)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                PeriodSwitcher(current: entry.currentPeriod)
            }

            Group {
                if let fallback = entry.fallbackMessage {
                    ChartFallback(message: fallback, compact: true)
                } else {
                    PollenChart(
                        kind: entry.currentKind,
                        samples: entry.samples,
                        allKindSamples: entry.allKindSamples,
                        period: entry.currentPeriod,
                        compact: true
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .invalidatableContent()

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


// MARK: - Large

private struct LargeView: View {
    let entry: PollenEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.cityName)
                        .font(.system(size: 26, weight: .medium, design: .rounded))
                    if !entry.citySubtitle.isEmpty {
                        Text(entry.citySubtitle.uppercased())
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .tracking(1.0)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let h = entry.headline {
                    LargeHeadline(label: h.label, value: h.value)
                        .invalidatableContent()
                }
            }

            HStack(alignment: .center) {
                Spacer()
                PeriodSwitcher(current: entry.currentPeriod)
            }

            Group {
                if let fallback = entry.fallbackMessage {
                    ChartFallback(message: fallback)
                } else {
                    PollenChart(
                        kind: entry.currentKind,
                        samples: entry.samples,
                        allKindSamples: entry.allKindSamples,
                        period: entry.currentPeriod
                    )
                }
            }
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
                                .font(.system(size: 9, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

struct LargeHeadline: View {
    let label: String
    let value: Double

    var body: some View {
        let risk = PollenRisk.from(value)
        VStack(alignment: .trailing, spacing: 1) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(0.9)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("\(Int(value.rounded()))")
                .font(.system(size: 56, weight: .ultraLight, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
            HStack(spacing: 4) {
                Circle().fill(risk.color).frame(width: 6, height: 6)
                Text(risk.label)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(risk.color)
            }
        }
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
