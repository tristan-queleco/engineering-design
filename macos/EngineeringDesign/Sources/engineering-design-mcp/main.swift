import Foundation
import EDModele
import EDMacro
import MoteurEnrouleur

// Serveur MCP local d'Engineering Design (stdio, JSON-RPC 2.0, un message par ligne).
// Claude Desktop ou Claude Code le lancent sur le Mac : c'est le compte Claude de l'usager
// qui travaille, aucune clé API n'est demandée ni stockée.
//   claude mcp add engineering-design -- "$HOME/Applications/Engineering Design.app/Contents/MacOS/engineering-design-mcp"
// L'app et ce serveur partagent le même fichier projet (~/Documents/Engineering Design/enrouleur.edprojet.json) :
// une cote changée ici apparaît dans l'app, et l'inverse.

let idPiece: [String: Any] = ["type": "string", "description": "Repère de la pièce, ex. E-07"]

let outils: [[String: Any]] = [
    ["name": "lister_pieces",
     "description": "Liste les pièces paramétrées du projet (repère, nom, révision, matériau) avec leurs paramètres et la vérification de chaque pièce.",
     "inputSchema": ["type": "object", "properties": [:] as [String: Any]] as [String: Any]],
    ["name": "changer_parametre",
     "description": "Change une cote pilotante d'une pièce (mm), vérifie la pièce et enregistre le projet. L'app se met à jour toute seule.",
     "inputSchema": ["type": "object", "required": ["piece", "cle", "valeur"],
                     "properties": ["piece": idPiece,
                                    "cle": ["type": "string", "description": "Clé du paramètre (voir lister_pieces), ex. L, d, m, g1"],
                                    "valeur": ["type": "number"]] as [String: Any]] as [String: Any]],
    ["name": "generer_macro",
     "description": "Écrit la macro VBA SolidWorks de la pièce (.bas, cp1252) dans ~/Documents/Engineering Design/macros et renvoie son texte. À importer dans l'éditeur VBA du PTV FSG.",
     "inputSchema": ["type": "object", "required": ["piece"], "properties": ["piece": idPiece]] as [String: Any]],
    ["name": "exporter_stl",
     "description": "Exporte la pièce en STL (mm) dans ~/Documents/Engineering Design/stl, pour l'impression 3D ou un autre logiciel.",
     "inputSchema": ["type": "object", "required": ["piece"], "properties": ["piece": idPiece]] as [String: Any]],
    ["name": "essai_enroulement",
     "description": "Lance un essai complet de l'enrouleur (moteur 28PG, fil maillon par maillon, manivelle) et renvoie le rapport et les vérifications.",
     "inputSchema": ["type": "object", "properties": [
        "arrivee_mm": ["type": "number", "description": "Position axiale du fil à l'arrivée, 0 à 18 mm (centre : 9)"],
        "awg": ["type": "integer", "enum": [30, 16]] as [String: Any],
        "longueur_m": ["type": "number"],
        "graine": ["type": "integer"],
        "montage": ["type": "string", "enum": Essai.montages.map(\.id)] as [String: Any],
     ] as [String: Any]] as [String: Any]],
]

func texte(_ s: String, erreur: Bool = false) -> [String: Any] {
    var r: [String: Any] = ["content": [["type": "text", "text": s]]]
    if erreur { r["isError"] = true }
    return r
}

func json<T: Encodable>(_ v: T) -> String {
    let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]
    return String(data: (try? e.encode(v)) ?? Data(), encoding: .utf8) ?? "{}"
}

struct FichePiece: Encodable {
    var piece: Piece
    var verification: [Constat]
}

func nombreDe(_ x: Any?) -> Double? {
    if let d = x as? Double { return d }
    if let i = x as? Int { return Double(i) }
    if let s = x as? String { return Double(s.replacingOccurrences(of: ",", with: ".")) }
    return nil
}

func appeler(_ nom: String, _ a: [String: Any]) -> [String: Any] {
    var projet = Emplacements.chargerProjet()
    let id = (a["piece"] as? String) ?? ""
    switch nom {
    case "lister_pieces":
        return texte(json(projet.pieces.map { FichePiece(piece: $0, verification: $0.verifier()) }))
    case "changer_parametre":
        guard let cle = a["cle"] as? String, let v = nombreDe(a["valeur"]) else { return texte("Il faut piece, cle et valeur.", erreur: true) }
        do {
            try projet.changer(piece: id, cle, v)
            try Emplacements.enregistrer(projet)
            let p = projet.piece(id)!
            return texte(json(FichePiece(piece: p, verification: p.verifier())))
        } catch {
            return texte(error.localizedDescription, erreur: true)
        }
    case "generer_macro":
        guard let p = projet.piece(id) else { return texte(ErreurModele.pieceInconnue(id).localizedDescription, erreur: true) }
        do {
            let url = try GenerateurMacro.ecrire(p, dans: Emplacements.macros)
            return ["content": [["type": "text", "text": "Macro écrite : \(url.path)"],
                                ["type": "text", "text": GenerateurMacro.macro(p)]]]
        } catch { return texte(error.localizedDescription, erreur: true) }
    case "exporter_stl":
        guard let p = projet.piece(id) else { return texte(ErreurModele.pieceInconnue(id).localizedDescription, erreur: true) }
        do {
            let url = try Emplacements.exporterSTL(p)
            return texte("STL écrit : \(url.path) (\(p.maillage().nombreTriangles) triangles)")
        } catch { return texte(error.localizedDescription, erreur: true) }
    case "essai_enroulement":
        var p = ParametresEssai()
        if let x = nombreDe(a["arrivee_mm"]) { p.arriveeMM = x }
        if let x = a["awg"] as? Int { p.awg = x }
        if let x = nombreDe(a["longueur_m"]) { p.longueurCibleM = x }
        if let x = a["graine"] as? Int { p.graine = UInt64(max(1, x)) }
        if let x = a["montage"] as? String { p.montage = x }
        let (r, _) = Essai.lancer(p)
        return texte(json(r))
    default:
        return texte("Outil inconnu : \(nom)", erreur: true)
    }
}

func envoyer(_ o: [String: Any]) {
    guard var d = try? JSONSerialization.data(withJSONObject: o, options: []) else { return }
    d.append(0x0A)
    FileHandle.standardOutput.write(d)
}

while let ligne = readLine(strippingNewline: true) {
    guard let data = ligne.data(using: .utf8),
          let msg = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let methode = msg["method"] as? String else { continue }
    let id = msg["id"]
    let params = msg["params"] as? [String: Any] ?? [:]
    var resultat: [String: Any]?
    switch methode {
    case "initialize":
        resultat = ["protocolVersion": (params["protocolVersion"] as? String) ?? "2025-06-18",
                    "capabilities": ["tools": [:] as [String: Any]],
                    "serverInfo": ["name": "engineering-design", "version": "0.1"]]
    case "tools/list":
        resultat = ["tools": outils]
    case "tools/call":
        resultat = appeler(params["name"] as? String ?? "", params["arguments"] as? [String: Any] ?? [:])
    case "ping":
        resultat = [:]
    default:
        if let id { envoyer(["jsonrpc": "2.0", "id": id, "error": ["code": -32601, "message": "Méthode inconnue"]]) }
    }
    if let r = resultat, let id { envoyer(["jsonrpc": "2.0", "id": id, "result": r]) }
}
