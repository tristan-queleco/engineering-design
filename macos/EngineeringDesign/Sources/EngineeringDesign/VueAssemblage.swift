import SwiftUI
import SceneKit
import ModelIO
import SceneKit.ModelIO
import EDModele

/// Assemblage de l'enrouleur : pièces réelles (.obj exportées de SolidWorks par le simulateur)
/// et résultat de la vérification (conflits, jeux, pièces flottantes) écrite dans assemblage.json.
struct VueAssemblage: View {
    @EnvironmentObject var etat: EtatApp
    @State private var charge: AssemblageCharge?
    @State private var erreur: String?
    @State private var pose = "moteur"

    var body: some View {
        HSplitView {
            Group {
                if let c = charge {
                    SceneView(scene: c.scene, options: [.allowsCameraControl, .autoenablesDefaultLighting])
                } else if let e = erreur {
                    ContentUnavailableView {
                        Label("Assemblage introuvable", systemImage: "folder.badge.questionmark")
                    } description: { Text(e) } actions: {
                        Button("Choisir le dossier…") { etat.choisirDossierAssemblage() }
                    }
                } else {
                    ProgressView("Chargement des pièces…")
                }
            }
            .frame(minWidth: 520, maxWidth: .infinity, maxHeight: .infinity)

            panneau.frame(minWidth: 300, idealWidth: 340, maxWidth: 420)
        }
        .task(id: etat.projet.dossierAssemblage) { await charger() }
    }

    private var panneau: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Vérification").font(.title3.bold())
                if let v = charge?.description.verification {
                    Picker("Pose", selection: $pose) {
                        ForEach(v.poses.keys.sorted(), id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if let p = v.poses[pose] { resume(p, noms: charge!.noms) }
                    if !v.flottantes.isEmpty {
                        Text("Pièces flottantes").font(.headline)
                        ForEach(v.flottantes, id: \.self) { f in
                            Label(charge!.nom(f.piece), systemImage: "questionmark.circle").foregroundStyle(.orange)
                        }
                    }
                } else if charge != nil {
                    Text("Pas encore de vérification dans assemblage.json : lance verifier_assemblage.py dans le simulateur.")
                        .foregroundStyle(.secondary)
                }
                Divider()
                if let c = charge {
                    Text("\(c.description.pieces.count) pièces · \(c.manquantes) fichier(s) manquant(s)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text(etat.projet.dossierAssemblage ?? "Aucun dossier").font(.caption2).foregroundStyle(.tertiary)
                    .textSelection(.enabled)
                Button("Changer de dossier…") { etat.choisirDossierAssemblage() }
            }
            .padding(14)
        }
    }

    @ViewBuilder private func resume(_ p: PoseVerif, noms: [String]) -> some View {
        let vrais = p.conflits.filter { $0.attendu == nil }
        let voulus = p.conflits.filter { $0.attendu != nil }
        Label(vrais.isEmpty ? "Aucun vrai conflit" : "\(vrais.count) vrai(s) conflit(s)",
              systemImage: vrais.isEmpty ? "checkmark.circle.fill" : "xmark.octagon.fill")
            .foregroundStyle(vrais.isEmpty ? .green : .red)
        ForEach(vrais, id: \.self) { c in
            Text("\(charge!.nom(c.a)) ↔ \(charge!.nom(c.b)) : \(nombre(c.volume_mm3)) mm³").font(.callout)
        }
        if !voulus.isEmpty {
            Text("Recouvrements voulus (\(voulus.count))").font(.headline)
            ForEach(voulus, id: \.self) { c in
                Text("\(charge!.nom(c.a)) ↔ \(charge!.nom(c.b)) : \(c.attendu ?? "")").font(.caption).foregroundStyle(.secondary)
            }
        }
        let nc = p.jeux.filter { $0.type == "non_coincident" }
        if !nc.isEmpty {
            Text("Faces qui devraient se toucher (\(nc.count))").font(.headline)
            ForEach(nc, id: \.self) { j in
                Text("\(charge!.nom(j.a)) ↔ \(charge!.nom(j.b)) : jeu \(nombre(j.jeu_mm)) mm").font(.caption).foregroundStyle(.orange)
            }
        }
    }

    private func charger() async {
        charge = nil; erreur = nil
        guard let dossier = etat.projet.dossierAssemblage else { erreur = "Aucun dossier choisi."; return }
        let racine = URL(fileURLWithPath: dossier, isDirectory: true)
        let resultat = await Task.detached(priority: .userInitiated) { () -> Result<AssemblageCharge, Error> in
            Result { try AssemblageCharge(racine: racine) }
        }.value
        switch resultat {
        case .success(let c):
            charge = c
            if let premiere = c.description.verification?.poses.keys.sorted().first,
               c.description.verification?.poses[pose] == nil { pose = premiere }
        case .failure(let e): erreur = "\(racine.path)\n\(e.localizedDescription)"
        }
    }
}

/// assemblage.json + pièces .obj chargées dans une scène SceneKit (mm, Y vers le haut).
final class AssemblageCharge: @unchecked Sendable {
    let description: DescriptionAssemblageED
    let scene = SCNScene()
    var manquantes = 0
    var noms: [String] { description.pieces.map(\.nom) }

    func nom(_ i: Int) -> String { i >= 0 && i < description.pieces.count ? description.pieces[i].nom : "pièce \(i)" }

    init(racine: URL) throws {
        let d = try Data(contentsOf: racine.appendingPathComponent("assemblage.json"))
        description = try JSONDecoder().decode(DescriptionAssemblageED.self, from: d)

        // pièces en vrai conflit (pose moteur) teintées en rouge
        var enConflit = Set<Int>()
        for p in description.verification?.poses.values.map({ $0 }) ?? [] {
            for c in p.conflits where c.attendu == nil { enConflit.insert(c.a); enConflit.insert(c.b) }
        }

        let racinePieces = racine.appendingPathComponent("pieces", isDirectory: true)
        for (i, p) in description.pieces.enumerated() where p.option == nil {
            var url = racinePieces.appendingPathComponent(p.fichier)
            if !FileManager.default.fileExists(atPath: url.path) { url = racine.appendingPathComponent(p.fichier) }
            guard FileManager.default.fileExists(atPath: url.path) else { manquantes += 1; continue }
            let asset = MDLAsset(url: url)
            let sous = SCNScene(mdlAsset: asset)
            let noeud = SCNNode()
            for enfant in sous.rootNode.childNodes { noeud.addChildNode(enfant) }
            let mat = SCNMaterial()
            mat.lightingModel = .physicallyBased
            mat.isDoubleSided = true
            mat.roughness.contents = 0.55
            if enConflit.contains(i) {
                mat.diffuse.contents = NSColor.systemRed
            } else if let c = p.couleur, c.count >= 3 {
                mat.diffuse.contents = NSColor(calibratedRed: c[0], green: c[1], blue: c[2], alpha: 1)
            } else {
                mat.diffuse.contents = NSColor.lightGray
            }
            noeud.enumerateHierarchy { n, _ in n.geometry?.materials = [mat] }
            noeud.name = p.nom
            scene.rootNode.addChildNode(noeud)
        }

        // caméra iso sur l'ensemble
        let (mn, mx) = scene.rootNode.boundingBox
        let centre = SCNVector3((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, (mn.z + mx.z) / 2)
        let taille = max(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z, 1)
        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.camera?.zNear = 1
        cam.camera?.zFar = Double(taille) * 20
        cam.position = SCNVector3(centre.x + taille * 0.9, centre.y + taille * 0.7, centre.z + taille * 0.9)
        cam.look(at: centre)
        scene.rootNode.addChildNode(cam)
    }
}

/// Lecture tolérante de assemblage.json (schéma ed-assemblage/1) : seulement ce que l'app affiche.
struct DescriptionAssemblageED: Decodable {
    struct PieceED: Decodable {
        var nom: String
        var fichier: String
        var corps: String
        var couleur: [Double]?
        var option: String?
    }
    var schema: String?
    var pieces: [PieceED]
    var verification: VerificationAssemblage?
}
