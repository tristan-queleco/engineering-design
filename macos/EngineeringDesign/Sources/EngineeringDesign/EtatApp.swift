import SwiftUI
import AppKit
import EDModele
import EDMacro

enum Rubrique: Hashable {
    case piece(String)
    case assemblage
    case simulation
    case connexion
}

/// État partagé de l'app. Le projet vit dans ~/Documents/Engineering Design/enrouleur.edprojet.json,
/// le même fichier que le serveur MCP : un changement fait par Claude apparaît ici en 1 à 2 s.
@MainActor
final class EtatApp: ObservableObject {
    @Published var projet: Projet
    @Published var section: Rubrique? = .piece("E-07")
    @Published var message: String?
    private var dateConnue: Date?
    private var minuterie: Timer?

    init() {
        projet = Emplacements.chargerProjet()
        dateConnue = Emplacements.dateProjet()
        minuterie = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.surveiller() }
        }
    }

    var pieceSelectionnee: Piece? {
        if case .piece(let id) = section { return projet.piece(id) }
        return nil
    }

    private func surveiller() {
        let d = Emplacements.dateProjet()
        if d != dateConnue { recharger() }
    }

    func recharger() {
        projet = Emplacements.chargerProjet()
        dateConnue = Emplacements.dateProjet()
    }

    private func enregistrer() {
        do {
            try Emplacements.enregistrer(projet)
            dateConnue = Emplacements.dateProjet()
        } catch {
            message = "Enregistrement impossible : \(error.localizedDescription)"
        }
    }

    func changer(piece id: String, _ cle: String, _ v: Double) {
        do {
            try projet.changer(piece: id, cle, v)
            enregistrer()
            message = nil
        } catch {
            message = error.localizedDescription
            objectWillChange.send()     // remet l'ancienne valeur dans le champ
        }
    }

    func reinitialiser(piece id: String) {
        guard let i = projet.pieces.firstIndex(where: { $0.id == id }), id == "E-07" else { return }
        projet.pieces[i] = .arbreE07()
        enregistrer()
    }

    func genererMacroSelection() { if let p = pieceSelectionnee { genererMacro(p) } }
    func exporterSTLSelection() { if let p = pieceSelectionnee { exporterSTL(p) } }

    /// Écrit le .bas, copie son texte dans le presse-papiers (à coller dans l'éditeur VBA du PTV)
    /// et montre le fichier dans le Finder.
    func genererMacro(_ p: Piece) {
        do {
            let url = try GenerateurMacro.ecrire(p, dans: Emplacements.macros)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(GenerateurMacro.macro(p), forType: .string)
            NSWorkspace.shared.activateFileViewerSelecting([url])
            message = "Macro écrite et copiée : \(url.lastPathComponent). Colle-la dans l'éditeur VBA du PTV."
        } catch {
            message = "Macro impossible : \(error.localizedDescription)"
        }
    }

    func exporterSTL(_ p: Piece) {
        do {
            let url = try Emplacements.exporterSTL(p)
            NSWorkspace.shared.activateFileViewerSelecting([url])
            message = "STL exporté : \(url.lastPathComponent)"
        } catch {
            message = "STL impossible : \(error.localizedDescription)"
        }
    }

    func choisirDossierAssemblage() {
        let panneau = NSOpenPanel()
        panneau.canChooseDirectories = true
        panneau.canChooseFiles = false
        panneau.message = "Choisis le dossier qui contient assemblage.json (Ressources du simulateur)"
        if panneau.runModal() == .OK, let url = panneau.url {
            projet.dossierAssemblage = url.path
            enregistrer()
        }
    }
}
