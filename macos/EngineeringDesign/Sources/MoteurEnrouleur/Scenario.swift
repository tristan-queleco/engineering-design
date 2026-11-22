import Foundation

/// Paramètres d'un essai (unités de l'atelier : mm, AWG, m).
public struct ParametresEssai: Codable, Sendable {
    public var arriveeMM = 17.31          // position axiale du fil à l'arrivée (0 = flasque côté moteur, 18 = flasque extérieur)
    public var distanceArriveeMM = 99.0   // pince patin du tensionneur / bosse de Base_v3 (y 32,75, z 1160,7)
    public var awg = 30                   // 30 ou 16 (diamètres du guide, isolant compris)
    public var longueurCibleM = 25 * 0.3048
    public var graine: UInt64 = 1
    public var mu = 0.20
    public var bruit = 0.30
    public var largeurMM = 18.0, rNoyauMM = 7.0, rFlasqueMM = 27.0
    public var montage = "v10c"
    public var guide = false               // guide d'enroulement imprimé (vis à double hélice)
    public var manivelleTrMin = 60.0
    public init() {}
    public var diametre: Double { awg == 16 ? 2.40e-3 : 1.10e-3 }
    public var geometrie: GeometrieBobine {
        var g = GeometrieBobine()
        g.rNoyau = rNoyauMM / 1000; g.rFlasque = rFlasqueMM / 1000; g.largeur = largeurMM / 1000
        g.arrivee = arriveeMM / 1000; g.distanceArrivee = distanceArriveeMM / 1000
        return g
    }
}

public struct Verification: Codable, Sendable {
    public var nom: String
    public var ok: Bool
    public var valeur: String
    public var limite: String
    public var correctif: String
}

public struct RapportEssai: Codable, Sendable {
    public var parametres: ParametresEssai
    public var longueurM: Double
    public var tours: Int
    public var deborde: Bool
    public var rayonMaxMM: Double
    public var margeFlasqueMM: Double
    public var dureeMoteurS: Double
    public var vitesseMoyenneTrMin: Double
    public var coupleMoteurMaxNm: Double
    public var basculementManivelleDeg: Double
    public var contraintePLAManivelleMPa: Double
    public var forceMainN: Double
    public var profilMM: [Double]
    public var verifications: [Verification]
}

public enum Essai {
    /// Montages de l'axe vertical P-25 (calcul de poutre axe_v8.py).
    public static let montages: [Montage] = [
        Montage(id: "v10c", nom: "v10 corrigée : 2 paliers lisses Ø10,3 imprimés", detail: "Palier bas dans la base (y −14,5 à −4,8) et bouchon guide (y 9,5 à 16,5), entraxe 23,4 mm, jeu au diamètre ≈ 0,25 une fois imprimé.", jeuDeg: 0.612, degParN: 0.0266, sigmaParN: 0.30559),
        Montage(id: "v10a", nom: "v10 corrigée, paliers alésés au foret 10,1", detail: "Mêmes paliers repassés au foret Ø10,1 : jeu au diamètre ≈ 0,15.", jeuDeg: 0.367, degParN: 0.0266, sigmaParN: 0.30559),
        Montage(id: "v10", nom: "Bobineur_v10 tel quel", detail: "Aucun palier : trou Ø14 en bas (jeu 2 mm), P-27 flotte dans une cavité r 16,6 ; seul le collier P-26 frotte dans une poche de 3 mm.", jeuDeg: 4.9, degParN: 0.2, sigmaParN: 0.30559),
        Montage(id: "v8", nom: "Bobineur_v8 tel quel", detail: "Bague P-27 de 5 mm en haut, axe Ø10 libre dans le trou Ø14 du bas.", jeuDeg: 2.2918, degParN: 0.13393, sigmaParN: 0.30559),
        Montage(id: "b2", nom: "Bague basse P-28 ajoutée", detail: "P-27 + P-28 (Ø14/Ø10), entraxe 28 mm, jeu 0,10.", jeuDeg: 0.40635, degParN: 0.02194, sigmaParN: 0.30559),
        Montage(id: "b2a", nom: "P-27 + P-28 alésées (jeu 0,05)", detail: "Bagues percées pour 0,05 mm de jeu. Aucune réimpression de la base.", jeuDeg: 0.20318, degParN: 0.02194, sigmaParN: 0.30559),
        Montage(id: "b2c", nom: "P-27 + P-28 alésées + âme acier Ø3", detail: "Avec une tige d'acier Ø3 noyée dans l'axe imprimé.", jeuDeg: 0.20318, degParN: 0.015125, sigmaParN: 0.21751),
        Montage(id: "r608", nom: "2 roulements 608 dans la base", detail: "Logements Ø22,2 haut et bas, tourillons Ø8.", jeuDeg: 0.07822, degParN: 0.041614, sigmaParN: 0.58955),
        Montage(id: "r608c", nom: "2 × 608 + âme acier Ø3", detail: "Comme 608, avec âme acier Ø3.", jeuDeg: 0.07822, degParN: 0.023652, sigmaParN: 0.35882),
    ]

    /// Essai complet sans écran : moteur jusqu'à la cible (ou débordement), puis 2 s de manivelle pour l'axe vertical.
    public static func lancer(_ p: ParametresEssai, pasTemps: Double = 1e-3) -> (RapportEssai, FilEnroulement) {
        let fil = FilEnroulement(diametre: p.diametre, geometrie: p.geometrie, graine: p.graine)
        fil.mu = p.mu; fil.bruit = p.bruit
        if p.guide { fil.guide = GuideVaEtVient() }
        let montage = montages.first { $0.id == p.montage } ?? montages[0]
        let phys = Physique(montage: montage) { fil.rayonCourant }
        phys.p.manivelleTrMin = p.manivelleTrMin
        var coupleMax = 0.0, coupleRegime = 0.0
        var t = 0.0
        while !fil.deborde && fil.longueur < p.longueurCibleM && t < 600 {
            let jBob = 2e-6 + 0.5 * 8.9e3 * fil.longueur * .pi * pow(p.diametre / 2, 2) * pow(fil.rayonCourant, 2)
            phys.pas(pasTemps, jTotal: 3e-6 + jBob)
            _ = fil.avancer(jusqua: phys.e.thE07)
            coupleMax = max(coupleMax, phys.e.coupleMoteur)
            if t > 0.5 { coupleRegime = max(coupleRegime, phys.e.coupleMoteur) }
            t += pasTemps
        }
        let dureeMoteur = t
        let tours = Int(phys.e.thE07 / (2 * .pi))
        // manivelle : bascule puis 2 s à la main
        phys.demanderBascule()
        var basc = 0.0, sig = 0.0, main = 0.0
        for _ in 0..<Int((phys.dureeBascule + 2.0) / pasTemps) {
            phys.pas(pasTemps, jTotal: 3e-6)
            if phys.e.phase == .manivelle { basc = max(basc, phys.e.basculementDeg); sig = max(sig, phys.e.sigmaMPa); main = max(main, phys.e.forceMain) }
        }
        let rmax = fil.rayonMax * 1000
        let marge = p.rFlasqueMM - rmax
        var v: [Verification] = []
        let ok25 = !fil.deborde && fil.longueur >= p.longueurCibleM
        v.append(Verification(nom: "25 pi enroulés sans déborder", ok: ok25,
                              valeur: String(format: "%.2f m", fil.longueur), limite: String(format: "%.2f m", p.longueurCibleM),
                              correctif: ok25 ? "" : p.guide ? "Bobine trop petite pour ce fil, même avec le guide." : (abs(p.arriveeMM - p.largeurMM / 2) > 2 ? String(format: "Aligner l'arrivée du fil sur le milieu de la bobine : décaler de %.1f mm.", p.arriveeMM - p.largeurMM / 2) : "Bobine trop petite pour ce fil : flasques plus grands ou largeur utile plus grande.")))
        v.append(Verification(nom: "Marge sous la lèvre du flasque", ok: marge >= 2.0,
                              valeur: String(format: "%.1f mm", marge), limite: "≥ 2 mm",
                              correctif: marge >= 2 ? "" : "Centrer l'arrivée du fil, ou agrandir les flasques."))
        v.append(Verification(nom: "Désalignement du couple conique (manivelle)", ok: basc <= 0.5,
                              valeur: String(format: "%.2f°", basc), limite: "≤ 0,5°",
                              correctif: basc <= 0.5 ? "" : "Repasser les deux paliers lisses de la base au foret Ø10,1 (jeu 0,15) ou allonger le bouchon guide."))
        v.append(Verification(nom: "Contrainte dans l'axe PLA", ok: sig < 10,
                              valeur: String(format: "%.1f MPa", sig), limite: "< 10 MPa (Sy 20, n ≥ 2)",
                              correctif: sig < 10 ? "" : "Âme acier Ø3 noyée dans l'axe."))
        // Au démarrage, un moteur CC donne toujours son couple de blocage (w = 0) : c'est normal.
        // On vérifie le couple en régime (après 0,5 s) contre le couple nominal de la fiche (1,79 kg·cm).
        let nominal = 1.79 * 0.0980665
        v.append(Verification(nom: "Couple moteur en régime sous le nominal", ok: coupleRegime <= nominal,
                              valeur: String(format: "%.3f N·m (démarrage %.3f)", coupleRegime, coupleMax), limite: String(format: "≤ %.3f N·m (nominal fiche S01)", nominal),
                              correctif: coupleRegime <= nominal ? "" : "Réduire la tension du tensionneur ou le rayon de la bobine pleine."))
        let r = RapportEssai(parametres: p, longueurM: fil.longueur, tours: tours, deborde: fil.deborde,
                             rayonMaxMM: rmax, margeFlasqueMM: marge, dureeMoteurS: dureeMoteur,
                             vitesseMoyenneTrMin: dureeMoteur > 0 ? Double(tours) / dureeMoteur * 60 : 0,
                             coupleMoteurMaxNm: coupleMax, basculementManivelleDeg: basc, contraintePLAManivelleMPa: sig,
                             forceMainN: main, profilMM: fil.profil().map { $0 * 1000 }, verifications: v)
        return (r, fil)
    }

    /// Balayage de la position d'arrivée du fil : taux de réussite sur plusieurs tirages.
    public static func balayer(base: ParametresEssai, de: Double, a: Double, pas: Double, tirages: Int) -> [[String: Double]] {
        var res: [[String: Double]] = []
        var x = de
        while x <= a + 1e-9 {
            var okN = 0, Ls = 0.0, rm = 0.0
            for g in 1...max(1, tirages) {
                var p = base; p.arriveeMM = x; p.graine = UInt64(g)
                let fil = FilEnroulement(diametre: p.diametre, geometrie: p.geometrie, graine: p.graine)
                fil.mu = p.mu; fil.bruit = p.bruit
                while !fil.deborde && fil.longueur < p.longueurCibleM { fil.poserMaillon() }
                if !fil.deborde { okN += 1 }
                Ls += fil.longueur; rm += fil.rayonMax * 1000
            }
            let n = Double(max(1, tirages))
            res.append(["arriveeMM": x, "reussite": Double(okN) / n, "longueurMoyM": Ls / n, "rayonMaxMoyMM": rm / n])
            x += pas
        }
        return res
    }
}
