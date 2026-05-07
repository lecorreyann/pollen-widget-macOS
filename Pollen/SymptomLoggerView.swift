import SwiftUI

// MARK: - Section principale dans ContentView

struct JournalSection: View {
    @ObservedObject var journal: SymptomJournal
    @ObservedObject var loader: LiveDataLoader
    @State private var sheetOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "list.clipboard.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Journal")
                        .font(.system(size: 19, weight: .medium, design: .rounded))
                    Text("\(journal.logs.count) note\(journal.logs.count == 1 ? "" : "s") · suivi des symptômes")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
                Spacer()
                Button {
                    sheetOpen = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Noter")
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(loader.currentSnapshot == nil)
            }

            if !journal.logs.isEmpty {
                AnalysisCard(journal: journal)
                LogsList(journal: journal)
            } else {
                EmptyJournalCard()
            }
        }
        .sheet(isPresented: $sheetOpen) {
            SymptomSheet(journal: journal, loader: loader, isPresented: $sheetOpen)
        }
    }
}

private struct EmptyJournalCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pas encore de note")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            Text("Quand tu sens un symptôme, clique sur « Noter ». Au fil des notes, le journal te dira à quels pollens / polluants tu réagis statistiquement.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
        )
    }
}

// MARK: - Sheet de saisie

struct SymptomSheet: View {
    @ObservedObject var journal: SymptomJournal
    @ObservedObject var loader: LiveDataLoader
    @Binding var isPresented: Bool

    @State private var selected: Set<Symptom> = []
    @State private var notes: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Que ressens-tu ?")
                    .font(.system(size: 22, weight: .light, design: .rounded))
                if !loader.resolvedCityName.isEmpty {
                    Text("À \(loader.resolvedCityName) · maintenant")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(Symptom.allCases) { symptom in
                    SymptomToggle(
                        symptom: symptom,
                        isOn: selected.contains(symptom)
                    ) {
                        if selected.contains(symptom) {
                            selected.remove(symptom)
                        } else {
                            selected.insert(symptom)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Notes (optionnel)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                TextEditor(text: $notes)
                    .font(.system(size: 12))
                    .frame(minHeight: 50, maxHeight: 70)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.regularMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
                    )
            }

            HStack {
                Button("Annuler") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Enregistrer") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(selected.isEmpty || loader.currentSnapshot == nil)
            }
        }
        .padding(24)
        .frame(width: 460, height: 540)
    }

    private func save() {
        guard let snapshot = loader.currentSnapshot else { return }
        let log = SymptomLog(
            cityName: loader.resolvedCityName,
            citySubtitle: loader.resolvedCountry,
            symptoms: selected,
            notes: notes,
            snapshot: snapshot
        )
        journal.add(log)
        isPresented = false
    }
}

private struct SymptomToggle: View {
    let symptom: Symptom
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symptom.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isOn ? .white : symptom.color)
                    .frame(width: 22)
                Text(symptom.label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(isOn ? .white : .primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isOn ? symptom.color : Color.primary.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Analyse

private struct AnalysisCard: View {
    @ObservedObject var journal: SymptomJournal

    private var symptomsWithLogs: [Symptom] {
        var counts: [Symptom: Int] = [:]
        for log in journal.logs {
            for s in log.symptoms { counts[s, default: 0] += 1 }
        }
        return Symptom.allCases.filter { (counts[$0] ?? 0) > 0 }
    }

    @State private var selected: Symptom = .eyesItchy

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Tu réagis probablement à…")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
                Text("\(journal.logs.count) note\(journal.logs.count == 1 ? "" : "s")")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }

            if symptomsWithLogs.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(symptomsWithLogs) { s in
                            Button {
                                selected = s
                            } label: {
                                Text(s.label)
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(selected == s ? Color.white : Color.primary.opacity(0.75))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule().fill(selected == s ? s.color : Color.primary.opacity(0.05))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            let candidates = SymptomAnalyser.candidates(for: selected, in: journal.logs)
            if candidates.isEmpty {
                Text("Pas assez de données pour ce symptôme. Continue à noter.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(candidates.prefix(5)) { c in
                    CandidateRow(candidate: c, symptom: selected)
                }
                if candidates.count > 5 {
                    Text("+ \(candidates.count - 5) autres")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            Text("Suspect = élevé ou très élevé au moment où tu as noté ce symptôme. Plus tu notes, plus le score est fiable.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
        )
    }
}

private struct CandidateRow: View {
    let candidate: AllergenCandidate
    let symptom: Symptom

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(candidate.kind.color).frame(width: 8, height: 8)
            Text(candidate.kind.label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .frame(width: 110, alignment: .leading)
            // Bar
            GeometryReader { geo in
                let pct = max(0.05, candidate.percentage / 100)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.06))
                        .frame(height: 6)
                    Capsule().fill(candidate.kind.color)
                        .frame(width: geo.size.width * pct, height: 6)
                }
            }
            .frame(height: 6)
            Text("\(Int(candidate.percentage.rounded())) %")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(candidate.kind.color)
                .frame(width: 40, alignment: .trailing)
            Text("\(candidate.occurrencesHigh)/\(candidate.totalLogs)")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(width: 32, alignment: .trailing)
        }
    }
}

// MARK: - Liste des notes

private struct LogsList: View {
    @ObservedObject var journal: SymptomJournal
    @State private var expanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Historique")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Spacer()
                Button(expanded ? "Réduire" : "Afficher tout") {
                    expanded.toggle()
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }

            let visible = expanded ? journal.logs : Array(journal.logs.prefix(3))
            ForEach(visible) { log in
                LogRow(log: log) {
                    journal.delete(log)
                }
            }
            if !expanded && journal.logs.count > 3 {
                Text("+ \(journal.logs.count - 3) note\(journal.logs.count - 3 == 1 ? "" : "s") plus anciennes")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct LogRow: View {
    let log: SymptomLog
    let onDelete: () -> Void

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter.string(from: log.timestamp)
    }

    private var dominantValue: (kind: PollenKind, value: Double, risk: PollenRisk)? {
        var best: (PollenKind, Double, PollenRisk, Int)?
        let order: [PollenRisk] = [.low, .moderate, .high, .veryHigh]
        for (rawKind, value) in log.snapshot.values {
            guard let kind = PollenKind(rawValue: rawKind) else { continue }
            let risk = kind.isPollutant
                ? PollenRisk.from(value, kind: kind)
                : PollenRisk.from(value)
            let idx = order.firstIndex(of: risk) ?? 0
            if best == nil || idx > best!.3 || (idx == best!.3 && value > best!.1) {
                best = (kind, value, risk, idx)
            }
        }
        return best.map { ($0.0, $0.1, $0.2) }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(formattedDate)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                    if !log.cityName.isEmpty {
                        Text("· \(log.cityName)")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 4) {
                    ForEach(Array(log.symptoms).sorted(by: { $0.rawValue < $1.rawValue })) { s in
                        HStack(spacing: 3) {
                            Image(systemName: s.icon)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(s.color)
                            Text(s.label)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.85))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(s.color.opacity(0.10)))
                    }
                }
                if let d = dominantValue, d.value > 0 {
                    HStack(spacing: 4) {
                        Circle().fill(d.risk.color).frame(width: 5, height: 5)
                        Text("Dominant : \(d.kind.label) à \(Int(d.value)) (\(d.risk.label.lowercased()))")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                if !log.notes.isEmpty {
                    Text("« \(log.notes) »")
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .italic()
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.regularMaterial.opacity(0.7))
        )
    }
}
