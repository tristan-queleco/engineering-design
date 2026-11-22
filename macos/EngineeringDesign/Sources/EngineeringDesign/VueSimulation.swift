import SwiftUI
import Charts
import EDModele
import MoteurEnrouleur

/// Banc d'essai de l'enrouleur (moteur 28PG réel, fil maillon par maillon, puis manivelle).
struct VueSimulation: View {
    @State private var p = ParametresEssai()
    @State private var rapport: RapportEssai?
    @State private var enCours = false

    var body: some View {
        HSplitView {
            Form {
                Section("Fil") {
                    Picker("Calibre", selection: $p.awg) { Text("30 AWG").tag(30); Text("16 AWG").tag(16) }
                    LabeledContent("Arrivée du fil") {
                        HStack {
                            Slider(value: $p.arriveeMM, in: 0...18, step: 0.25)
                            Text("\(nombre(p.arriveeMM)) mm").monospacedDigit().frame(width: 70, alignment: .trailing)
                        }
                    }
                    LabeledContent("Longueur visée") {
                        HStack {
                            Slider(value: $p.longueurCibleM, in: 1...12, step: 0.1)
                            Text("\(nombre(p.longueurCibleM)) m").monospacedDigit().frame(width: 70, alignment: .trailing)
                        }
                    }
                }
                Section("Machine") {
                    Picker("Montage de l'axe vertical", selection: $p.montage) {
                        ForEach(Essai.montages.map(\.id), id: \.self) { Text($0).tag($0) }
                    }
                    Toggle("Guide d'enroulement imprimé", isOn: $p.guide)
                    LabeledContent("Tirage aléatoire n° \(p.graine)") { Button("Autre tirage") { p.graine += 1 } }
                }
                Section {
                    Button { lancer() } label: {
                        Label(enCours ? "Essai en cours…" : "Lancer l'essai", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(enCours)
                }
            }
            .formStyle(.grouped)
            .frame(minWidth: 320, idealWidth: 360, maxWidth: 440)

            resultat.frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder private var resultat: some View {
        if let r = rapport {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        tuile("Enroulé", "\(nombre(r.longueurM)) m", ok: !r.deborde)
                        tuile("Marge au flasque", "\(nombre(r.margeFlasqueMM)) mm", ok: r.margeFlasqueMM > 0)
                        tuile("Couple max", "\(nombre(r.coupleMoteurMaxNm)) N·m", ok: true)
                        tuile("Durée", "\(nombre(r.dureeMoteurS)) s", ok: true)
                    }
                    Text("Profil de la pile de fil").font(.headline)
                    Chart(Array(r.profilMM.enumerated()), id: \.offset) { e in
                        BarMark(x: .value("Position", Double(e.offset) * p.largeurMM / Double(max(r.profilMM.count, 1))),
                                y: .value("Hauteur (mm)", e.element))
                    }
                    .chartXAxisLabel("Position sur la bobine (mm)")
                    .frame(height: 180)
                    Text("Vérifications").font(.headline)
                    ForEach(Array(r.verifications.enumerated()), id: \.offset) { _, v in
                        VStack(alignment: .leading, spacing: 2) {
                            Label("\(v.nom) : \(v.valeur) (limite \(v.limite))",
                                  systemImage: v.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(v.ok ? .green : .orange)
                            if !v.ok && !v.correctif.isEmpty { Text(v.correctif).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
                .padding(16)
            }
        } else {
            ContentUnavailableView("Aucun essai", systemImage: "waveform.path.ecg",
                                   description: Text("Règle le fil et la machine, puis lance l'essai."))
        }
    }

    private func tuile(_ titre: String, _ valeur: String, ok: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titre).font(.caption).foregroundStyle(.secondary)
            Text(valeur).font(.title3.bold()).monospacedDigit()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) { Rectangle().fill(ok ? Color.green : Color.red).frame(width: 4) }
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private func lancer() {
        enCours = true
        let params = p
        Task.detached(priority: .userInitiated) {
            let (r, _) = Essai.lancer(params)
            await MainActor.run { rapport = r; enCours = false }
        }
    }
}
