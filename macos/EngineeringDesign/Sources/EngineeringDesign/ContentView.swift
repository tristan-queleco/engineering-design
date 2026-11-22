import SwiftUI
import EDModele

struct ContentView: View {
    @EnvironmentObject var etat: EtatApp

    var body: some View {
        NavigationSplitView {
            List(selection: $etat.section) {
                Section("Pièces paramétrées") {
                    ForEach(etat.projet.pieces) { p in
                        Label {
                            VStack(alignment: .leading) {
                                Text(p.id).font(.headline)
                                Text(p.nom).font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "cylinder.split.1x2")
                        }
                        .tag(Rubrique.piece(p.id))
                    }
                }
                Section("Enrouleur") {
                    Label("Assemblage", systemImage: "square.stack.3d.up").tag(Rubrique.assemblage)
                    Label("Simulation", systemImage: "waveform.path.ecg").tag(Rubrique.simulation)
                }
                Section("Claude") {
                    Label("Connexion MCP", systemImage: "link").tag(Rubrique.connexion)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 230)
            .navigationTitle(etat.projet.nom)
        } detail: {
            VStack(spacing: 0) {
                detail
                if let m = etat.message {
                    HStack {
                        Image(systemName: "info.circle")
                        Text(m).lineLimit(2)
                        Spacer()
                        Button("OK") { etat.message = nil }
                    }
                    .padding(10)
                    .background(.thinMaterial)
                }
            }
        }
    }

    @ViewBuilder private var detail: some View {
        switch etat.section {
        case .piece(let id):
            if let p = etat.projet.piece(id) { VuePiece(piece: p) } else { ContentUnavailableView("Pièce introuvable", systemImage: "questionmark") }
        case .assemblage: VueAssemblage()
        case .simulation: VueSimulation()
        case .connexion: VueConnexion()
        case nil: ContentUnavailableView("Choisis une pièce", systemImage: "cylinder")
        }
    }
}
