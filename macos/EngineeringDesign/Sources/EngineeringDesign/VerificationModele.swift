import Foundation

/// Section « verification » de assemblage.json (schéma ed-assemblage/1), écrite par verifier_assemblage.py.
/// Les pièces sont désignées par leur indice dans `pieces`. Noms de champs stables : ne pas renommer.
struct ConflitVerif: Codable, Hashable {
    var a: Int
    var b: Int
    var volume_mm3: Double       // volume commun : les pièces entrent l'une dans l'autre
    var centre: [Double]         // centre de la zone commune (mm, repère de l'assemblage)
    var attendu: String?         // raison si le recouvrement est voulu (dentures en prise, serrage) ; nil = vrai conflit
}

struct JeuVerif: Codable, Hashable {
    var a: Int
    var b: Int
    var jeu_mm: Double           // distance minimale entre les surfaces
    var centre: [Double]
    var type: String             // "non_coincident" (même corps : faces qui devraient se toucher) | "fonctionnement"
}

struct PoseVerif: Codable {
    var conflits: [ConflitVerif]
    var jeux: [JeuVerif]
    var contacts: [[Int]]        // paires de pièces dont les faces sont coïncidentes (≤ seuil contact)
}

struct FlottanteVerif: Codable, Hashable {
    var piece: Int
    var voisins: [Int]           // pièces touchées, sans chaîne de contacts jusqu'à la base
}

struct VerificationAssemblage: Codable {
    var seuils: [String: Double] // conflit_mm3, contact_mm, pres_mm
    var poses: [String: PoseVerif]   // "moteur" (tige à 0) et "manivelle" (tige poussée)
    var flottantes: [FlottanteVerif]
}
