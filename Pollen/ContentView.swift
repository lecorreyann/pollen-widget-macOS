import SwiftUI

struct ContentView: View {
    @StateObject private var loader = LiveDataLoader()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Header()
                LiveSection(loader: loader)
                PollenSection()
                AirSection()
                EyesSection()
                ReliefSection()
                Footer()
            }
            .padding(28)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(BackgroundGradient())
        .frame(minWidth: 580, idealWidth: 800, minHeight: 600, idealHeight: 880)
        .task {
            await loader.load()
        }
    }
}

// MARK: - Symptom level

struct SymptomLevel {
    let label: String
    let range: String
    let color: Color
    let symptoms: String
}

struct SymptomRow: View {
    let level: SymptomLevel

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(level.color)
                .frame(width: 8, height: 8)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(level.label)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(level.color)
                    Text(level.range)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Text(level.symptoms)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.primary.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private let cFaible = Color(red: 0.30, green: 0.78, blue: 0.45)
private let cModere = Color(red: 0.97, green: 0.78, blue: 0.30)
private let cEleve = Color(red: 0.96, green: 0.55, blue: 0.18)
private let cTresEleve = Color(red: 0.93, green: 0.30, blue: 0.30)

// MARK: - Header

private struct Header: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 28))
                .foregroundStyle(.green.gradient)
            VStack(alignment: .leading, spacing: 2) {
                Text("Pollen")
                    .font(.system(size: 32, weight: .light, design: .rounded))
                Text("Tel seuil, telle sensation")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Reusables

private struct SectionTitle: View {
    let icon: String
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 19, weight: .medium, design: .rounded))
                if let subtitle {
                    Text(subtitle.uppercased())
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct InfoCard<Content: View>: View {
    let title: String
    let unit: String?
    let subtitle: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Spacer()
                if let unit {
                    Text(unit)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            content()
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

private struct LevelsList: View {
    let levels: [SymptomLevel]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(levels.indices, id: \.self) { i in
                SymptomRow(level: levels[i])
                if i < levels.count - 1 {
                    Divider()
                }
            }
        }
    }
}

// MARK: - Live section

private struct LiveSection: View {
    @ObservedObject var loader: LiveDataLoader

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text("En direct")
                        .font(.system(size: 19, weight: .medium, design: .rounded))
                    if !loader.resolvedCityName.isEmpty {
                        Text("\(loader.resolvedCityName.uppercased()) · \(loader.resolvedCountry.uppercased())")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if loader.loading {
                    ProgressView().controlSize(.small)
                }
            }

            CitySearchBar(loader: loader)

            if let error = loader.errorMessage {
                ErrorBanner(message: error)
            } else if loader.windows.isEmpty && !loader.loading {
                Text("Recherche en cours…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(loader.windows) { window in
                        WindowCard(window: window)
                    }
                }
            }
        }
    }
}

private struct CitySearchBar: View {
    @ObservedObject var loader: LiveDataLoader

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            TextField("Ville (ex. Valencia, ES)", text: $loader.cityQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .onSubmit {
                    Task { await loader.load() }
                }
            Button("Charger") {
                Task { await loader.load() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(loader.loading)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
        )
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
    }
}

private struct WindowCard: View {
    let window: LiveWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(window.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text(window.timeRange)
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                RiskPill(risk: window.risk)
            }

            Text(window.summary)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.primary.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)

            if !window.highlights.isEmpty {
                HStack(spacing: 8) {
                    ForEach(window.highlights) { h in
                        HStack(spacing: 4) {
                            Image(systemName: h.icon)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(h.color)
                            Text("\(h.label) · \(h.value)")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.85))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(h.color.opacity(0.10))
                        )
                    }
                    Spacer()
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(window.risk.color.opacity(0.18), lineWidth: 0.5)
        )
    }
}

private struct RiskPill: View {
    let risk: PollenRisk

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(risk.color).frame(width: 7, height: 7)
            Text(risk.label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(risk.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(risk.color.opacity(0.14)))
    }
}

// MARK: - Pollens

private struct PollenSection: View {
    let levels: [SymptomLevel] = [
        SymptomLevel(
            label: "Faible", range: "0 – 20 grains/m³", color: cFaible,
            symptoms: "Aucun symptôme. Tu te promènes tranquille."
        ),
        SymptomLevel(
            label: "Modéré", range: "20 – 50", color: cModere,
            symptoms: "Si tu es très sensible : nez qui chatouille, un éternuement de temps en temps. Sinon rien."
        ),
        SymptomLevel(
            label: "Élevé", range: "50 – 100", color: cEleve,
            symptoms: "Nez qui coule, yeux qui piquent, éternuements en série, gorge qui gratte. C'est là que ça commence à gêner."
        ),
        SymptomLevel(
            label: "Très élevé", range: "> 100", color: cTresEleve,
            symptoms: "Yeux rouges et larmoyants, nez bouché, fatigue dans la journée, parfois maux de tête. Asthmatique : risque de crise."
        ),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(icon: "tree.fill", title: "Pollens", subtitle: "Pour TON allergène")
            InfoCard(
                title: "Échelle universelle",
                unit: "grains/m³",
                subtitle: "Vrai pour bouleau, cyprès, graminées, olivier, etc. Tu lis la valeur de ton allergène et tu sais à quoi t'attendre."
            ) {
                LevelsList(levels: levels)
            }
        }
    }
}

// MARK: - Air

private struct AirSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(icon: "wind", title: "Qualité de l'air", subtitle: "Microgrammes par mètre cube · µg/m³")

            // Ozone
            InfoCard(
                title: "Ozone (O₃)",
                unit: "µg/m³",
                subtitle: "Le gaz qui irrite le plus les yeux. Pic 14h-18h par temps chaud sec."
            ) {
                LevelsList(levels: [
                    SymptomLevel(label: "Faible", range: "< 60", color: cFaible,
                                 symptoms: "Rien. Air respirable."),
                    SymptomLevel(label: "Modéré", range: "60 – 100", color: cModere,
                                 symptoms: "Les sensibles sentent une légère gêne en fin de journée. Nez qui chatouille."),
                    SymptomLevel(label: "Élevé", range: "100 – 180", color: cEleve,
                                 symptoms: "Yeux qui piquent et brûlent légèrement, mal de tête en fin d'après-midi, toux sèche. Effet retardé : tu sens 4-8h après l'exposition."),
                    SymptomLevel(label: "Très élevé", range: "> 180", color: cTresEleve,
                                 symptoms: "Yeux très rouges, larmoiement, gorge brûlée, essoufflement à l'effort. Reste à l'intérieur, ferme les volets."),
                ])
            }

            // PM2.5
            InfoCard(
                title: "PM2.5",
                unit: "µg/m³",
                subtitle: "Particules fines (< 2,5 µm). Vont jusqu'aux poumons. Pire en hiver."
            ) {
                LevelsList(levels: [
                    SymptomLevel(label: "Faible", range: "< 10", color: cFaible,
                                 symptoms: "Rien. C'est ce qu'on respire en montagne."),
                    SymptomLevel(label: "Modéré", range: "10 – 25", color: cModere,
                                 symptoms: "Imperceptible pour la plupart. Asthmatiques : peut-être une légère gêne."),
                    SymptomLevel(label: "Élevé", range: "25 – 50", color: cEleve,
                                 symptoms: "Gorge qui gratte, légère gêne respiratoire, yeux secs. Tu te sens « lourd »."),
                    SymptomLevel(label: "Très élevé", range: "> 50", color: cTresEleve,
                                 symptoms: "Yeux qui piquent, toux, mal de tête, fatigue. Évite le sport en extérieur."),
                ])
            }

            // PM10
            InfoCard(
                title: "PM10",
                unit: "µg/m³",
                subtitle: "Poussières plus grosses. Restent dans nez et gorge. Souvent calima saharienne en mars-avril."
            ) {
                LevelsList(levels: [
                    SymptomLevel(label: "Faible", range: "< 20", color: cFaible,
                                 symptoms: "Rien."),
                    SymptomLevel(label: "Modéré", range: "20 – 50", color: cModere,
                                 symptoms: "Gorge sèche. Quelques éternuements pour rincer le nez."),
                    SymptomLevel(label: "Élevé", range: "50 – 100", color: cEleve,
                                 symptoms: "Sensation de gravier dans l'œil, gorge qui gratte, nez sec. Ferme les fenêtres."),
                    SymptomLevel(label: "Très élevé", range: "> 100", color: cTresEleve,
                                 symptoms: "Yeux rouges, toux. Voiles orangés visibles dans le ciel (calima). Reste dedans."),
                ])
            }

            // NO2
            InfoCard(
                title: "NO₂",
                unit: "µg/m³",
                subtitle: "Dioxyde d'azote, du trafic. Pic aux heures de pointe (8-9h, 18-20h)."
            ) {
                LevelsList(levels: [
                    SymptomLevel(label: "Faible", range: "< 40", color: cFaible,
                                 symptoms: "Rien."),
                    SymptomLevel(label: "Modéré", range: "40 – 90", color: cModere,
                                 symptoms: "Gorge qui gratte si tu es dehors longtemps. Nez qui coule possible."),
                    SymptomLevel(label: "Élevé", range: "90 – 120", color: cEleve,
                                 symptoms: "Irritation gorge et nez nettes, toux. Yeux peu touchés."),
                    SymptomLevel(label: "Très élevé", range: "> 120", color: cTresEleve,
                                 symptoms: "Toux marquée, oppression. Asthmatiques : risque de spasme. Sportifs : évite l'effort dehors."),
                ])
            }
        }
    }
}

// MARK: - Eye decision tree

private struct EyesSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(icon: "eye.fill", title: "Yeux qui piquent : que vérifier ?", subtitle: "Diagnostic rapide")

            InfoCard(title: "Ouvre le widget et regarde, dans l'ordre :", unit: nil, subtitle: nil) {
                VStack(alignment: .leading, spacing: 12) {
                    StepRow(number: "1", color: cTresEleve,
                            title: "Mode Détaillé : ton allergène > 50 ?",
                            text: "Si une courbe pollen domine et dépasse 50, c'est probablement ça. Note quel pollen pour suivre les jours d'après.")
                    StepRow(number: "2", color: cEleve,
                            title: "Mode Air : ozone > 100 entre 14h-18h ?",
                            text: "Si oui, l'ozone amplifie l'irritation. Typique des journées chaudes ensoleillées.")
                    StepRow(number: "3", color: cModere,
                            title: "Mode Air : PM10 > 50 ?",
                            text: "Suspecte une calima saharienne ou pollution localisée (chantier, trafic dense).")
                    StepRow(number: "4", color: cFaible,
                            title: "Tout est bas → cherche en intérieur",
                            text: "Acariens, moisissures, climatisation sèche, exposition écran prolongée, animaux. Aucune API ne mesure ça.")
                }
            }
        }
    }
}

private struct StepRow: View {
    let number: String
    let color: Color
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(color))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(text)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Relief

private struct ReliefSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(icon: "cross.case.fill", title: "Soulagement immédiat", subtitle: "Ce qui marche, ce qui empire")

            InfoCard(title: "Gestes simples", unit: nil, subtitle: nil) {
                Bullet(icon: "sunglasses.fill", text: "Lunettes de soleil dehors — barrière physique efficace contre pollens et vent.")
                Bullet(icon: "drop.fill", text: "Larmes artificielles sans conservateur (Hylo-Comod, Vismed) plusieurs fois par jour pour rincer.")
                Bullet(icon: "hand.raised.slash.fill", text: "Ne pas frotter — frotter libère plus d'histamine, ça empire vite.")
                Bullet(icon: "shower.fill", text: "Rincer visage et cheveux en rentrant — les cheveux capturent le pollen.")
                Bullet(icon: "pill.fill", text: "Antihistaminique en collyre OTC : Azelastine ou Olopatadine (sans ordonnance en Espagne).")
                Bullet(icon: "pills.fill", text: "Antihistaminique oral si ça déborde sur le nez : Cétirizine, Loratadine.")
            }

            InfoCard(title: "Pour un diagnostic définitif", unit: nil, subtitle: nil) {
                Bullet(icon: "stethoscope", text: "Test cutané (prick test) chez un allergologue : 30 min, ~50 € en consultation privée. Tu sais exactement à quoi tu réagis.")
                Bullet(icon: "doc.text", text: "Test sanguin IgE spécifique : alternatif si peau sensible. Plus cher, ~80-150 €.")
            }
        }
    }
}

private struct Bullet: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.primary.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}

// MARK: - Footer

private struct Footer: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack(spacing: 8) {
                Text("Données :")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                Text("Open-Meteo (pollen + air) · Ambee (espèces étendues)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Text("Seuils : EAACI / RNSA pour les pollens, EU AQI pour les polluants.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Text("Les symptômes décrits sont indicatifs : la sensibilité varie selon les personnes.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 8)
    }
}

// MARK: - Background

private struct BackgroundGradient: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [
                    Color.green.opacity(0.05),
                    Color.clear,
                    Color.blue.opacity(0.04),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
