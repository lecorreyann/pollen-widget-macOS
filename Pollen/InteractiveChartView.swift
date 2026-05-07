import SwiftUI
import Charts

/// Vue grande échelle avec chart Swift Charts interactif (hover tooltip + sélecteurs).
struct InteractiveChartView: View {
    @ObservedObject var loader: LiveDataLoader
    @ObservedObject var journal: SymptomJournal

    @State private var period: PollenPeriod = .today
    @State private var mode: PollenKind = .all
    @State private var hoveredDate: Date?
    /// Cache des séries par espèce. Recalculé uniquement quand la période, le mode
    /// ou le payload data changent — pas à chaque mouvement de souris.
    @State private var byKind: [PollenKind: [PollenSample]] = [:]

    private var personalAllergens: Set<PollenKind> {
        Set(journal.personalAllergens.map { $0.kind })
    }

    private func recomputeByKind() {
        guard let response = loader.response else {
            byKind = [:]
            return
        }
        var result: [PollenKind: [PollenSample]] = [:]
        let kinds = mode == .air ? PollenKind.airKinds : PollenKind.concreteKinds
        for kind in kinds {
            result[kind] = PollenAPI.samples(for: response, kind: kind, period: period)
        }
        if mode != .air, let ambee = loader.ambee {
            let ambeeKind = PollenAPI.samplesByKindFromAmbee(ambee, period: period)
            let openMeteoCovered: Set<PollenKind> = [.alder, .birch, .grass, .mugwort, .olive, .ragweed]
            for (kind, samples) in ambeeKind where !samples.isEmpty {
                if openMeteoCovered.contains(kind) { continue }
                result[kind] = samples
            }
        }
        byKind = result
    }

    private var displayedKinds: [PollenKind] {
        let candidates = mode == .air ? PollenKind.airKinds : PollenKind.concreteKinds
        return candidates.filter { (byKind[$0]?.contains { $0.value > 0 }) ?? false }
    }

    private var maxY: Double {
        let observed = byKind.values.flatMap { $0 }.map(\.value).max() ?? 0
        let floor: Double = mode == .air ? 50 : 100
        return max(observed * 1.20, floor)
    }

    private var xRange: (start: Date, end: Date) {
        let all = byKind.values.flatMap { $0 }.map(\.date).sorted()
        return (all.first ?? Date(), all.last ?? Date().addingTimeInterval(3600))
    }

    /// Domaine X complet : du début de la période au début du jour suivant,
    /// pour que le chart couvre 23h-00h sans coupe.
    private var xDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let now = Date()
        switch period {
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now.addingTimeInterval(86400)
            return start...end
        case .tomorrow:
            let today = calendar.startOfDay(for: now)
            let start = calendar.date(byAdding: .day, value: 1, to: today) ?? today
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
            return start...end
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Graphique détaillé")
                        .font(.system(size: 19, weight: .medium, design: .rounded))
                    Text("Survole pour les valeurs précises")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Selectors
            HStack(spacing: 12) {
                PeriodSelector(period: $period)
                ModeSelector(mode: $mode)
            }

            // Chart card
            ZStack(alignment: .topLeading) {
                if loader.response == nil {
                    LoadingPlaceholder()
                        .frame(height: 320)
                } else {
                    chartView
                        .frame(height: 320)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
            )

            // Legend
            if !displayedKinds.isEmpty {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                    alignment: .leading,
                    spacing: 6
                ) {
                    ForEach(displayedKinds, id: \.self) { kind in
                        HStack(spacing: 5) {
                            Circle().fill(kind.color).frame(width: 7, height: 7)
                            Text(kind.label)
                                .font(.system(size: 10, weight: .regular, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            if personalAllergens.contains(kind) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 7))
                                    .foregroundStyle(.yellow)
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }

        }
        .onAppear { recomputeByKind() }
        .onChange(of: period) { _, _ in recomputeByKind() }
        .onChange(of: mode) { _, _ in recomputeByKind() }
        .onChange(of: loader.dataVersion) { _, _ in recomputeByKind() }
    }

    @ViewBuilder
    private var chartView: some View {
        Chart {
            ForEach(displayedKinds, id: \.self) { kind in
                if let list = byKind[kind] {
                    ForEach(list) { sample in
                        LineMark(
                            x: .value("Date", sample.date),
                            y: .value("Valeur", sample.value),
                            series: .value("Type", kind.label)
                        )
                        .foregroundStyle(kind.color)
                        .lineStyle(StrokeStyle(
                            lineWidth: personalAllergens.contains(kind) ? 2.4 : 1.6,
                            lineCap: .round,
                            lineJoin: .round
                        ))
                        .interpolationMethod(.catmullRom)
                        .opacity(personalAllergens.isEmpty || personalAllergens.contains(kind) ? 1.0 : 0.45)
                    }
                }
            }

            if let hoveredDate {
                RuleMark(x: .value("Heure", hoveredDate))
                    .foregroundStyle(.primary.opacity(0.30))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .chartYScale(domain: 0...maxY)
        .chartXScale(domain: xDomain)
        .chartXSelection(value: $hoveredDate)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 9)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.secondary.opacity(0.10))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
                            .font(.system(size: 10, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.secondary.opacity(0.15))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .chartOverlay { proxy in
            if let hoveredDate {
                GeometryReader { geo in
                    if let xPos = proxy.position(forX: hoveredDate) {
                        let plotFrame = geo[proxy.plotAreaFrame]
                        TooltipCard(
                            date: hoveredDate,
                            samples: nearestSamples(at: hoveredDate),
                            personalAllergens: personalAllergens
                        )
                        .fixedSize()
                        .offset(
                            x: min(max(xPos + plotFrame.minX + 12, plotFrame.minX), plotFrame.maxX - 200),
                            y: plotFrame.minY + 4
                        )
                    }
                }
            }
        }
    }

    private func nearestSamples(at date: Date) -> [(kind: PollenKind, value: Double)] {
        // Seuil de proximité : si l'échantillon le plus proche est trop loin,
        // on n'affiche pas (sinon on ment, on renvoie la dernière donnée connue).
        let threshold: TimeInterval = 1.5 * 3600
        var results: [(kind: PollenKind, value: Double)] = []
        for kind in displayedKinds {
            guard let list = byKind[kind], !list.isEmpty else { continue }
            guard let nearest = list.min(by: {
                abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
            }) else { continue }
            if abs(nearest.date.timeIntervalSince(date)) <= threshold {
                results.append((kind, nearest.value))
            }
        }
        return results.sorted { $0.value > $1.value }
    }

}

// MARK: - Selectors

private struct PeriodSelector: View {
    @Binding var period: PollenPeriod

    var body: some View {
        HStack(spacing: 4) {
            ForEach([PollenPeriod.today, .tomorrow], id: \.self) { p in
                Button {
                    period = p
                } label: {
                    Text(p.shortLabel)
                        .font(.system(size: 11, weight: period == p ? .semibold : .medium, design: .rounded))
                        .foregroundStyle(period == p ? Color.primary : Color.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background {
                            if period == p {
                                Capsule().fill(.regularMaterial)
                                    .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ModeSelector: View {
    @Binding var mode: PollenKind

    var body: some View {
        HStack(spacing: 4) {
            modeButton(target: .all, label: "Pollens")
            modeButton(target: .air, label: "Air")
        }
    }

    @ViewBuilder
    private func modeButton(target: PollenKind, label: String) -> some View {
        let active = mode == target
        Button {
            mode = target
        } label: {
            Text(label)
                .font(.system(size: 11, weight: active ? .semibold : .medium, design: .rounded))
                .foregroundStyle(active ? Color.primary : Color.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background {
                    if active {
                        Capsule().fill(.regularMaterial)
                            .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tooltip

private struct TooltipCard: View {
    let date: Date
    let samples: [(kind: PollenKind, value: Double)]
    let personalAllergens: Set<PollenKind>

    private var dateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE HH:mm"
        return f.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(dateString.capitalized)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            if samples.isEmpty {
                Text("Aucune donnée disponible")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("Prévisions Ambee limitées à 2 jours en plan gratuit")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(samples.prefix(8), id: \.kind) { entry in
                    HStack(spacing: 5) {
                        Circle().fill(entry.kind.color).frame(width: 6, height: 6)
                        Text(entry.kind.label)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(personalAllergens.contains(entry.kind) ? Color.primary : Color.primary.opacity(0.8))
                        if personalAllergens.contains(entry.kind) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(.yellow)
                        }
                        Spacer(minLength: 8)
                        Text("\(Int(entry.value.rounded()))")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(entry.kind.color)
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }
}

// MARK: - Loading

private struct LoadingPlaceholder: View {
    var body: some View {
        VStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("Chargement…")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
