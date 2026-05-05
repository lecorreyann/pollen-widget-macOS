import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green.gradient)

            Text("Pollen")
                .font(.largeTitle).bold()

            VStack(alignment: .leading, spacing: 10) {
                Label("Clic droit sur le bureau", systemImage: "1.circle.fill")
                Label("« Modifier les widgets… »", systemImage: "2.circle.fill")
                Label("Recherchez « Pollen »", systemImage: "3.circle.fill")
                Label("Configurez la ville et la période", systemImage: "4.circle.fill")
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 32)

            Text("Données : Open-Meteo (gratuit, sans clé)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
        }
        .padding(40)
        .frame(width: 480, height: 380)
    }
}

#Preview {
    ContentView()
}
