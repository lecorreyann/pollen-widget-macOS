import SwiftUI
import Charts

struct PollenChart: View {
    let kind: PollenKind
    let samples: [PollenSample]
    let allKindSamples: [PollenKind: [PollenSample]]
    let period: PollenPeriod
    var compact: Bool = false

    private var isMulti: Bool { kind == .all || kind == .air }

    private var multiKinds: [PollenKind] {
        kind == .air ? PollenKind.airKinds : PollenKind.concreteKinds
    }

    private func multiSamples(for k: PollenKind) -> [PollenSample] {
        allKindSamples[k] ?? []
    }

    private var displayedMaxValue: Double {
        if isMulti {
            return multiKinds.flatMap { multiSamples(for: $0) }.map(\.value).max() ?? 0
        }
        return samples.map(\.value).max() ?? 0
    }

    private var maxY: Double {
        let floor: Double = kind == .air ? 50 : 100
        return max(displayedMaxValue * 1.30, floor)
    }

    private var xStart: Date {
        if isMulti {
            return multiKinds.flatMap { multiSamples(for: $0) }.min(by: { $0.date < $1.date })?.date ?? Date()
        }
        return samples.first?.date ?? Date()
    }

    private var xEnd: Date {
        if isMulti {
            return multiKinds.flatMap { multiSamples(for: $0) }.max(by: { $0.date < $1.date })?.date ?? Date().addingTimeInterval(3600)
        }
        return samples.last?.date ?? Date().addingTimeInterval(3600)
    }

    private var peakSample: (kind: PollenKind, sample: PollenSample)? {
        if isMulti {
            var best: (PollenKind, PollenSample)?
            for k in multiKinds {
                guard let m = multiSamples(for: k).max(by: { $0.value < $1.value }) else { continue }
                if m.value > (best?.1.value ?? 0) {
                    best = (k, m)
                }
            }
            return best
        }
        guard let m = samples.max(by: { $0.value < $1.value }) else { return nil }
        return (kind, m)
    }

    private var nowSample: PollenSample? {
        guard period == .today else { return nil }
        let now = Date()
        guard now >= xStart && now <= xEnd else { return nil }
        return samples.min(by: {
            abs($0.date.timeIntervalSince(now)) < abs($1.date.timeIntervalSince(now))
        })
    }

    private var lineGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: PollenRisk.low.color, location: 0.0),
                .init(color: PollenRisk.low.color, location: locStop(18)),
                .init(color: PollenRisk.moderate.color, location: locStop(35)),
                .init(color: PollenRisk.high.color, location: locStop(75)),
                .init(color: PollenRisk.veryHigh.color, location: locStop(130)),
                .init(color: PollenRisk.veryHigh.color, location: 1.0),
            ],
            startPoint: UnitPoint(x: 0.5, y: 1.0),
            endPoint: UnitPoint(x: 0.5, y: 0.0)
        )
    }

    private var areaGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: PollenRisk.low.color.opacity(0.0), location: 0.0),
                .init(color: PollenRisk.low.color.opacity(0.30), location: locStop(20)),
                .init(color: PollenRisk.moderate.color.opacity(0.40), location: locStop(50)),
                .init(color: PollenRisk.high.color.opacity(0.45), location: locStop(100)),
                .init(color: PollenRisk.veryHigh.color.opacity(0.50), location: 1.0),
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private func locStop(_ v: Double) -> Double {
        max(0, min(1, v / maxY))
    }

    private var peakLabelFormat: Date.FormatStyle {
        if period == .week {
            return .dateTime.weekday(.abbreviated).hour(.defaultDigits(amPM: .omitted))
        }
        return .dateTime.hour(.defaultDigits(amPM: .omitted)).minute()
    }

    var body: some View {
        Chart {
            // Subtle threshold reference (only for pollen modes — air mode has mixed units)
            if kind != .air {
                if maxY > 50 {
                    RuleMark(y: .value("Seuil", 50))
                        .foregroundStyle(.secondary.opacity(0.10))
                        .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [3, 4]))
                }
                if maxY > 100 {
                    RuleMark(y: .value("Seuil", 100))
                        .foregroundStyle(.secondary.opacity(0.12))
                        .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [3, 4]))
                }
            }

            if isMulti {
                ForEach(multiKinds, id: \.self) { k in
                    if let list = allKindSamples[k] {
                        ForEach(list) { sample in
                            LineMark(
                                x: .value("Date", sample.date),
                                y: .value("Pollen", sample.value),
                                series: .value("Série", k.label)
                            )
                            .foregroundStyle(k.color)
                            .lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                }
            } else {
                ForEach(samples) { sample in
                    AreaMark(
                        x: .value("Date", sample.date),
                        y: .value("Pollen", sample.value)
                    )
                    .foregroundStyle(areaGradient)
                    .interpolationMethod(.catmullRom)
                }

                ForEach(samples) { sample in
                    LineMark(
                        x: .value("Date", sample.date),
                        y: .value("Pollen", sample.value)
                    )
                    .foregroundStyle(lineGradient)
                    .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }

                if period == .week {
                    ForEach(samples) { sample in
                        PointMark(
                            x: .value("Date", sample.date),
                            y: .value("Pollen", sample.value)
                        )
                        .foregroundStyle(PollenRisk.from(sample.value).color)
                        .symbolSize(35)
                    }
                }
            }

            // Now indicator + ghost pill (today only, single kind)
            if period == .today, !isMulti, let n = nowSample {
                let nowRisk = PollenRisk.from(n.value)
                RuleMark(x: .value("Maintenant", n.date))
                    .foregroundStyle(.primary.opacity(0.20))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [3, 3]))

                PointMark(
                    x: .value("Date", n.date),
                    y: .value("Pollen", n.value)
                )
                .symbol(.circle)
                .symbolSize(60)
                .foregroundStyle(.background)
                .annotation(position: .bottom, alignment: .center, spacing: 2) {
                    Text("maintenant")
                        .font(.system(size: compact ? 8 : 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                PointMark(
                    x: .value("Date", n.date),
                    y: .value("Pollen", n.value)
                )
                .symbol(Circle().strokeBorder(lineWidth: 1.5))
                .symbolSize(60)
                .foregroundStyle(nowRisk.color)
                .annotation(position: .top, alignment: .center, spacing: 4) {
                    NowPill(value: n.value)
                }
            }

            // Peak pill (the one big highlight)
            if let peak = peakSample, peak.sample.value > 0 {
                let peakColor: Color = isMulti ? peak.kind.color : PollenRisk.from(peak.sample.value).color
                let pickedDifferentFromNow: Bool = {
                    guard let n = nowSample else { return true }
                    return abs(n.date.timeIntervalSince(peak.sample.date)) > 1800
                }()

                if pickedDifferentFromNow {
                    // Solid filled marker for peak (more prominent)
                    PointMark(
                        x: .value("Date", peak.sample.date),
                        y: .value("Pollen", peak.sample.value)
                    )
                    .symbol(.circle)
                    .symbolSize(80)
                    .foregroundStyle(peakColor)
                    .annotation(position: .top, alignment: .center, spacing: 4) {
                        PeakPill(value: peak.sample.value, kind: isMulti ? peak.kind : nil, color: peakColor)
                    }
                    .annotation(position: .bottom, alignment: .center, spacing: 2) {
                        Text(peak.sample.date, format: peakLabelFormat)
                            .font(.system(size: compact ? 8 : 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(peakColor)
                    }
                }
            }
        }
        .chartYScale(domain: 0...maxY)
        .chartXAxis {
            let count: Int = period == .week ? 7 : (compact ? 6 : 9)
            AxisMarks(values: .automatic(desiredCount: count)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.secondary.opacity(0.10))
                AxisValueLabel(centered: false) {
                    if let date = value.as(Date.self) {
                        Group {
                            if period == .week {
                                Text(date, format: .dateTime.weekday(.abbreviated))
                            } else {
                                Text(date, format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
                            }
                        }
                        .font(.system(size: compact ? 8 : 9, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }
}

struct PeakPill: View {
    let value: Double
    let kind: PollenKind?
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text("\(Int(value.rounded()))")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            if let kind {
                Text(kind.shortLabel.lowercased())
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(color.gradient)
                .shadow(color: color.opacity(0.35), radius: 5, x: 0, y: 2)
        )
    }
}

struct NowPill: View {
    let value: Double

    var body: some View {
        Text("\(Int(value.rounded()))")
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(.primary.opacity(0.85))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
                Capsule(style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
            )
    }
}
