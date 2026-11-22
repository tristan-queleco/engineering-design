import Foundation

/// Un projet Engineering Design : ses pièces paramétrées et le dossier de l'assemblage (simulateur).
public struct Projet: Codable, Equatable, Sendable {
    public var nom: String
    public var pieces: [Piece]
    /// Dossier qui contient assemblage.json et les pièces .obj (Ressources du simulateur).
    public var dossierAssemblage: String?

    public init(nom: String, pieces: [Piece], dossierAssemblage: String? = nil) {
        self.nom = nom; self.pieces = pieces; self.dossierAssemblage = dossierAssemblage
    }

    public static func enrouleur() -> Projet {
        Projet(nom: "Enrouleur GMC-2024 (équipe 15)", pieces: [.arbreE07()],
               dossierAssemblage: NSString(string: "~/Developer/simulateur-v2-xwxdda/cours/GMC-2024/equipe15/simulateur/app-macos/Sources/SimulateurEnrouleur/Ressources").expandingTildeInPath)
    }

    public func piece(_ id: String) -> Piece? {
        pieces.first { $0.id.caseInsensitiveCompare(id) == .orderedSame }
    }

    public mutating func changer(piece id: String, _ cle: String, _ v: Double) throws {
        guard let i = pieces.firstIndex(where: { $0.id.caseInsensitiveCompare(id) == .orderedSame }) else {
            throw ErreurModele.pieceInconnue(id)
        }
        try pieces[i].changer(cle, v)
    }
}

/// Emplacements sur le Mac. Tout reste local : ~/Documents/Engineering Design/.
public enum Emplacements {
    public static var racine: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/Engineering Design", isDirectory: true)
    }
    public static var projet: URL { racine.appendingPathComponent("enrouleur.edprojet.json") }
    public static var macros: URL { racine.appendingPathComponent("macros", isDirectory: true) }
    public static var stl: URL { racine.appendingPathComponent("stl", isDirectory: true) }

    public static func preparer() {
        for d in [racine, macros, stl] {
            try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        }
    }

    /// Charge le projet, ou crée le projet de l'enrouleur au premier lancement.
    public static func chargerProjet() -> Projet {
        preparer()
        if let d = try? Data(contentsOf: projet), let p = try? JSONDecoder().decode(Projet.self, from: d) { return p }
        let p = Projet.enrouleur()
        try? enregistrer(p)
        return p
    }

    public static func enregistrer(_ p: Projet) throws {
        preparer()
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]
        try e.encode(p).write(to: projet, options: .atomic)
    }

    public static func dateProjet() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: projet.path))?[.modificationDate] as? Date
    }

    @discardableResult
    public static func exporterSTL(_ piece: Piece) throws -> URL {
        preparer()
        let url = stl.appendingPathComponent("\(piece.fichier).stl")
        try piece.maillage().stl(nom: piece.fichier).write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
