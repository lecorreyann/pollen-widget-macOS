import SwiftUI
import Charts

struct PollenChart: View {
    let kind: PollenKind
    let samples: [PollenSample]
    let allKindSamples: [PollenKind: [PollenSample]]
    let period: PollenPeriod
    var compact: Bool = false

    private var displayedMaxValue: Double {
        if kind == .all {
            return allKindSamples.values.flatMap { $0 }.map(\.value).max() ?? 0
        }
        return samples.map(\.value).max() ?? 0
    }

    private var maxY: Double {
        max(displayedMaxValue * 1.20, 120)
    }

    private var xStart: Date {
        if kind == .all {
            return allKindSamples.values.flatMap { $0 }.min(by: { $0.date < $1.date })?.date ?? Date()
        }
        return samples.first?.date ?? Date()
    }

    private var xEnd: Date {
        if kind == .all {
            return allKindSamples.values.flatMap { $0 }.max(by: { $0.date < $1.date })?.date ?? Date().addingTimeInterval(3600)
        }
        return samples.last?.date ?? Date().addingTimeInterval(3600)
    }

    private var peakSample: (kind: PollenKind, sample: PollenSample)? {
        if kind == .all {
            var best: (PollenKind, PollenSample)?
            for (k, list) in allKindSamples {
                if let m = list.max(by: { $0.value < $1.value }),
                   m.value > (best?.1.value ?? 0) {
                    best = (k, m)
                }
            }
            return best
        }
        guard let m = samples.max(by: { $0.value < $1.value }) else { return nil }
        return (kind, m)
    }

    private func locationStops(for value: Double) -> Double {
        max(0, min(1, value / maxY))
    }

    private var lineGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: PollenRisk.low.color, location: 0.0),
                .init(color: PollenRisk.low.color, location: locationStops(for: 18)),
                .init(color: PollenRisk.moderate.color, location: locationStops(for: 35)),
                .init(color: PollenRisk.high.color, location: locationStops(for: 75)),
                .init(color: PollenRisk.veryHigh.color, location: locationStops(for: 130)),
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
                .init(color: PollenRisk.low.color.opacity(0.20), location: locationStops(for: 20)),
                .init(color: PollenRisk.moderate.color.opacity(0.25), location: locationStops(for: 50)),
                .init(color: PollenRisk.high.color.opacity(0.30), location: locationStops(for: 100)),
                .init(color: PollenRisk.veryHigh.color.opacity(0.35), location: 1.0),
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private var yGridValues: [Double] {
        var values: [Double] = [0, 20, 50, 100]
        if maxY > 150 { values.append(150) }
        if maxY > 200 { values.append(200) }
        return values.filter { $0 <= maxY }
    }

    var body: some View {
        Chart {
            if kind == .all {
                ForEach(PollenKind.concreteKinds, id: \.self) { k in
                    if let list = allKindSamples[k] {
                        ForEach(list) { sample in
                            LineMark(
                                x: .value("Date", sample.date),
                                y: .value("Pollen", sample.value),
                                series: .value("Pollen", k.label)
                            )
                            .foregroundStyle(k.color)
                            .lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                }
            } else {
                // Area
                ForEach(samples) { sample in
                    AreaMark(
                        x: .value("Date", sample.date),
                        y: .value("Pollen", sample.value)
                    )
                    .foregroundStyle(areaGradient)
                    .interpolationMethod(.catmullRom)
                }

                // Line with risk gradient
                ForEach(samples) { sample in
                    LineMark(
                        x: .value("Date", sample.date),
                        y: .value("Pollen", sample.value)
                    )
                    .foregroundStyle(lineGradient)
                    .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }

                // Points on week view
                if period == .week {
                    ForEach(samples) { sample in
                        PointMark(
                            x: .value("Date", sample.date),
                            y: .value("Pollen", sample.value)
                        )
                        .foregroundStyle(PollenRisk.from(sample.value).color)
                        .symbolSize(38)
                    }
                }
            }

            // Peak annotation
            if let peak = peakSample, peak.sample.value > 5 {
                PointMark(
                    x: .value("Date", peak.sample.date),
                    y: .value("Pollen", peak.sample.value)
                )
                .foregroundStyle(kind == .all ? peak.kind.color : PollenRisk.from(peak.sample.value).color)
                .symbolSize(compact ? 30 : 50)
                .annotation(position: .top, alignment: .center, spacing: 2) {
                    Text("\(Int(peak.sample.value.rounded()))")
                        .font(.system(size: compact ? 8 : 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.regularMaterial, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(
                                    (kind == .all ? peak.kind.color : PollenRisk.from(peak.sample.value).color).opacity(0.35),
                                    lineWidth: 0.5
                                )
                        )
                }
            }

            // Now indicator (today only)
            if period == .today {
                let now = Date()
                if now >= xStart && now <= xEnd {
                    RuleMark(x: .value("Maintenant", now))
                        .foregroundStyle(Color.primary.opacity(0.30))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
            }
        }
        .chartYScale(domain: 0...maxY)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: period == .week ? 7 : 4)) { value in
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
                        .font(.system(size: compact ? 8 : 9, weight: .medium))
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: yGridValues) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.secondary.opacity(0.18))
                AxisValueLabel(anchor: .trailing) {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))")
                            .font(.system(size: compact ? 8 : 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartLegend(.hidden)
    }
}
