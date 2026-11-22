import SwiftUI
import SceneKit
import EDModele

/// Une pièce paramétrée : cotes à gauche, aperçu 3D à droite, vérification et sorties en bas.
struct VuePiece: View {
    @EnvironmentObject var etat: EtatApp
    let piece: Piece

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 0) {
                entete
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(piece.parametres) { p in
                            LigneParametre(parametre: p) { v in etat.changer(piece: piece.id, p.cle, v) }
                        }
                    }
                    .padding(14)
                }
                Divider()
                actions
            }
            .frame(minWidth: 340, idealWidth: 380, maxWidth: 460)

            VStack(spacing: 0) {
                ApercuPiece(piece: piece)
                Divider()
                VueVerification(constats: piece.verifier())
            }
            .frame(minWidth: 480)
        }
    }

    private var entete: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(piece.id)  \(piece.nom)").font(.title2.bold())
            Text("\(piece.fichier).SLDPRT · \(piece.materiau) · rév. \(piece.revision)")
                .font(.callout).foregroundStyle(.secondary)
        }
        .padding(14)
    }

    private var actions: some View {
        HStack {
            Button { etat.genererMacro(piece) } label: { Label("Macro SolidWorks", systemImage: "doc.text") }
                .buttonStyle(.borderedProminent)
                .help("Écrit le .bas et le copie : à coller dans l'éditeur VBA du PTV")
            Button { etat.exporterSTL(piece) } label: { Label("STL", systemImage: "cube") }
            Spacer()
            Button("Valeurs d'origine") { etat.reinitialiser(piece: piece.id) }
        }
        .padding(14)
    }
}

/// Une cote : nom, champ numérique (Entrée pour appliquer) et petites flèches ±0,1.
struct LigneParametre: View {
    let parametre: Parametre
    let appliquer: (Double) -> Void
    @State private var valeur: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(parametre.nom)
                Spacer()
                TextField("", value: $valeur, format: .number.precision(.fractionLength(0...3)))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .onSubmit { appliquer(valeur) }
                Stepper("", value: $valeur, in: parametre.min...parametre.max, step: 0.1) { modifie in
                    if !modifie { appliquer(valeur) }
                }
                .labelsHidden()
                Text(parametre.unite).foregroundStyle(.secondary).frame(width: 28, alignment: .leading)
            }
            HStack(spacing: 6) {
                Text(parametre.cle).font(.caption.monospaced()).foregroundStyle(.tertiary)
                if let n = parametre.note { Text(n).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .onAppear { valeur = parametre.valeur }
        .onChange(of: parametre.valeur) { _, v in valeur = v }
    }
}

struct VueVerification: View {
    let constats: [Constat]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if constats.isEmpty {
                Label("Pièce cohérente : aucune erreur trouvée", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            ForEach(Array(constats.enumerated()), id: \.offset) { _, c in
                Label(c.message, systemImage: c.gravite == .erreur ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(c.gravite == .erreur ? .red : .orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }
}

/// Aperçu 3D local de la pièce (le même maillage que le STL). Souris : tourner, molette : zoom.
struct ApercuPiece: View {
    let piece: Piece

    var body: some View {
        SceneView(scene: ApercuPiece.scene(piece), options: [.allowsCameraControl, .autoenablesDefaultLighting])
            .id(piece.parametres.map { "\($0.cle)=\($0.valeur)" }.joined(separator: ";"))
            .background(Color(nsColor: .underPageBackgroundColor))
    }

    static func scene(_ piece: Piece) -> SCNScene {
        let scene = SCNScene()
        let noeud = SCNNode(geometry: geometrie(piece.maillage()))
        noeud.geometry?.firstMaterial = materiau(piece.materiau)
        scene.rootNode.addChildNode(noeud)

        // caméra placée selon la taille de la pièce, regard sur son centre
        let (mn, mx) = noeud.boundingBox
        let centre = SCNVector3((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, (mn.z + mx.z) / 2)
        let taille = max(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z)
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.zNear = 0.1
        camera.camera?.zFar = Double(taille) * 20
        camera.position = SCNVector3(centre.x + taille * 0.45, centre.y + taille * 0.45, centre.z + taille * 0.9)
        camera.look(at: centre)
        scene.rootNode.addChildNode(camera)
        return scene
    }

    static func geometrie(_ m: Maillage) -> SCNGeometry {
        let sommets = m.positions.map { SCNVector3(CGFloat($0.x), CGFloat($0.y), CGFloat($0.z)) }
        let normales = m.normales.map { SCNVector3(CGFloat($0.x), CGFloat($0.y), CGFloat($0.z)) }
        let indices = (0..<UInt32(sommets.count)).map { $0 }
        return SCNGeometry(sources: [SCNGeometrySource(vertices: sommets), SCNGeometrySource(normals: normales)],
                           elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
    }

    static func materiau(_ nom: String) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.isDoubleSided = true
        if nom.contains("AISI") || nom.lowercased().contains("acier") {
            m.diffuse.contents = NSColor(calibratedRed: 0.72, green: 0.74, blue: 0.77, alpha: 1)
            m.metalness.contents = 0.85
            m.roughness.contents = 0.35
        } else {
            m.diffuse.contents = NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.20, alpha: 1)
            m.metalness.contents = 0.0
            m.roughness.contents = 0.6
        }
        return m
    }
}
