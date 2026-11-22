import Foundation

/// Une cote pilotante d'une pièce (mm sauf indication). Même rôle qu'une cote double-cliquable dans SolidWorks.
public struct Parametre: Codable, Identifiable, Equatable, Sendable {
    public var cle: String          // identifiant court, stable (utilisé par le MCP)
    public var nom: String          // libellé affiché
    public var valeur: Double
    public var unite: String
    public var min: Double
    public var max: Double
    public var note: String?
    public var id: String { cle }

    public init(_ cle: String, _ nom: String, _ valeur: Double, unite: String = "mm",
                min: Double, max: Double, note: String? = nil) {
        self.cle = cle; self.nom = nom; self.valeur = valeur; self.unite = unite
        self.min = min; self.max = max; self.note = note
    }
}

public enum TypePiece: String, Codable, Sendable {
    case arbre      // arbre de révolution avec gorges d'anneaux et méplats
}

/// Un constat de la vérification d'une pièce.
public struct Constat: Codable, Equatable, Sendable {
    public enum Gravite: String, Codable, Sendable { case erreur, attention }
    public var gravite: Gravite
    public var message: String
    public init(_ g: Gravite, _ m: String) { gravite = g; message = m }
}

public enum ErreurModele: Error, LocalizedError, Equatable {
    case parametreInconnu(String)
    case horsLimites(String, Double, Double, Double)
    case pieceInconnue(String)

    public var errorDescription: String? {
        switch self {
        case .parametreInconnu(let c): return "Paramètre inconnu : \(c)"
        case .horsLimites(let c, let v, let a, let b): return "\(c) = \(v) hors des limites [\(a) ; \(b)]"
        case .pieceInconnue(let p): return "Pièce inconnue : \(p)"
        }
    }
}

/// Pièce paramétrée. La géométrie se déduit des paramètres (recette selon le type) ;
/// la même recette sert à l'aperçu 3D, au fichier STL et à la macro SolidWorks.
public struct Piece: Codable, Identifiable, Equatable, Sendable {
    public var id: String           // repère BOM, ex. « E-07 »
    public var nom: String
    public var fichier: String      // nom du .SLDPRT créé par la macro
    public var type: TypePiece
    public var materiau: String
    public var revision: String
    public var parametres: [Parametre]

    public init(id: String, nom: String, fichier: String, type: TypePiece, materiau: String,
                revision: String, parametres: [Parametre]) {
        self.id = id; self.nom = nom; self.fichier = fichier; self.type = type
        self.materiau = materiau; self.revision = revision; self.parametres = parametres
    }

    public func valeur(_ cle: String) -> Double {
        parametres.first { $0.cle == cle }?.valeur ?? 0
    }

    public mutating func changer(_ cle: String, _ v: Double) throws {
        guard let i = parametres.firstIndex(where: { $0.cle == cle }) else { throw ErreurModele.parametreInconnu(cle) }
        let p = parametres[i]
        guard v >= p.min, v <= p.max else { throw ErreurModele.horsLimites(cle, v, p.min, p.max) }
        parametres[i].valeur = v
    }

    public func verifier() -> [Constat] {
        switch type {
        case .arbre: return GeometrieArbre(self).verifier()
        }
    }
}

// MARK: - Arbre E-07

public extension Piece {
    /// Arbre principal E-07 de l'enrouleur (équipe 15), d'après Eq15_pieces_Tristan.bas (révision 26-27 oct. 2026).
    /// X = 0 bout moteur. Roulement 608 fixe entre 2 anneaux DIN 471, méplats contre le glissement.
    static func arbreE07() -> Piece {
        Piece(id: "E-07", nom: "Arbre principal", fichier: "Eq15_E-07_arbre", type: .arbre,
              materiau: "AISI 303", revision: "E (paramétrée)", parametres: [
            Parametre("d", "Diamètre de l'arbre", 8, min: 3, max: 30, note: "Barre étirée Ø8 du cours"),
            Parametre("L", "Longueur", 150, min: 20, max: 500),
            Parametre("m", "Méplat : distance axe-plat", 3.5, min: 0.5, max: 15, note: "7,5 entre le plat et le côté opposé"),
            Parametre("dg", "Diamètre au fond des gorges", 7.6, min: 2, max: 30, note: "Anneau DIN 471 de 8"),
            Parametre("wg", "Largeur des gorges", 0.9, min: 0.3, max: 5),
            Parametre("g1", "Gorge 1 : début", 14.15, min: 0, max: 500, note: "Roulement 608 fixe"),
            Parametre("g2", "Gorge 2 : début", 21.95, min: 0, max: 500),
            Parametre("me1a", "Méplat embout : début", 0, min: 0, max: 500),
            Parametre("me1b", "Méplat embout : fin", 12, min: 0, max: 500, note: "Embout E-04"),
            Parametre("me2a", "Méplat central : début", 26, min: 0, max: 500),
            Parametre("me2b", "Méplat central : fin", 150, min: 0, max: 500,
                      note: "Va jusqu'au bout : les pièces en D entrent par le bout manivelle"),
        ])
    }
}

/// Géométrie d'un arbre : profil (x, r) fermé sur l'axe, et méplats.
public struct GeometrieArbre: Sendable {
    public var rayon: Double
    public var longueur: Double
    public var rayonGorge: Double
    public var largeurGorge: Double
    public var gorges: [Double]              // positions de début, triées
    public var meplats: [ClosedRange<Double>]
    public var distanceMeplat: Double

    public init(_ p: Piece) {
        rayon = p.valeur("d") / 2
        longueur = p.valeur("L")
        rayonGorge = p.valeur("dg") / 2
        largeurGorge = p.valeur("wg")
        gorges = [p.valeur("g1"), p.valeur("g2")].sorted()
        distanceMeplat = p.valeur("m")
        meplats = [(p.valeur("me1a"), p.valeur("me1b")), (p.valeur("me2a"), p.valeur("me2b"))]
            .filter { $0.1 > $0.0 }
            .map { min($0.0, longueur)...min($0.1, longueur) }
    }

    /// Profil de révolution (x, r), du point (0,0) au point (L,0), dans l'ordre de la macro.
    public var profil: [(x: Double, r: Double)] {
        var pts: [(x: Double, r: Double)] = [(0, 0), (0, rayon)]
        for g in gorges where g > 0 && g + largeurGorge < longueur {
            pts += [(g, rayon), (g, rayonGorge), (g + largeurGorge, rayonGorge), (g + largeurGorge, rayon)]
        }
        pts += [(longueur, rayon), (longueur, 0)]
        return pts
    }

    public func dansMeplat(_ x: Double) -> Bool { meplats.contains { $0.contains(x) } }

    public func verifier() -> [Constat] {
        var c: [Constat] = []
        if distanceMeplat >= rayon { c.append(.init(.erreur, "Le méplat (\(nombre(distanceMeplat)) de l'axe) ne coupe rien : il doit être sous le rayon \(nombre(rayon)).")) }
        if rayonGorge >= rayon { c.append(.init(.erreur, "Le fond de gorge Ø\(nombre(2 * rayonGorge)) doit être plus petit que Ø\(nombre(2 * rayon)).")) }
        if distanceMeplat < rayonGorge { c.append(.init(.attention, "Le méplat descend sous le fond des gorges : l'anneau ne tiendra pas du côté plat.")) }
        for g in gorges where g <= 0 || g + largeurGorge >= longueur {
            c.append(.init(.erreur, "La gorge à \(nombre(g)) sort de l'arbre (0 à \(nombre(longueur)))."))
        }
        if gorges.count == 2, gorges[1] < gorges[0] + largeurGorge {
            c.append(.init(.erreur, "Les deux gorges se chevauchent."))
        }
        if let dernier = meplats.last, dernier.upperBound < longueur {
            c.append(.init(.attention, "Le méplat central s'arrête à \(nombre(dernier.upperBound)) : les pièces en D (bobine, moyeu) ne pourront pas entrer par le bout manivelle."))
        }
        for g in gorges where dansMeplat(g) || dansMeplat(g + largeurGorge) {
            c.append(.init(.attention, "La gorge à \(nombre(g)) tombe dans un méplat."))
        }
        if meplats.count == 2, meplats[0].overlaps(meplats[1]) {
            c.append(.init(.attention, "Les deux méplats se chevauchent : ils forment un seul plat."))
        }
        return c
    }
}

/// Nombre court à la française (virgule, 2 décimales au plus).
public func nombre(_ v: Double) -> String {
    var s = String(format: "%.2f", v)
    while s.hasSuffix("0") { s.removeLast() }
    if s.hasSuffix(".") { s.removeLast() }
    return s.replacingOccurrences(of: ".", with: ",")
}
