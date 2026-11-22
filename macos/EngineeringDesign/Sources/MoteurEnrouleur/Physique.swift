import Foundation
import simd

/// Modèle physique de l'enrouleur (équipe 15), unités SI.
/// Chaîne à 1 degré de liberté : J·α = T_entrée − T_fil − T_frottement.
/// Mode moteur : courbe couple-vitesse du 28PG sur E-07 (accouplement engagé).
/// Bascule (v10 corrigée, 21 nov. soir) : on pousse la tige P-21 v2 de 27,6 mm ; sa fenêtre entraîne la patte du chariot
/// moteur d'un bout à l'autre de sa fente (36,48 → 74,48) : l'accouplement quitte E-07 à 8,4 mm. La rampe (pente 6 mm, 3,73 mm)
/// lève la grappe entre 1 et 7 mm de course ; en fin de course le plateau est sous le collier P-26 jusqu'à 8,6 mm au-delà de l'axe.
/// Mode manivelle : la main impose la vitesse de la manivelle, z35 → z21 → z45 → z15 → E-07 (5:1).
public struct Parametres {
    public var moteurW0 = 515.0 * 2 * .pi / 60      // à vide, fiche S01 28PG-365-24V rapport 15 (Brio)
    public var moteurTs = 4.32 * 0.0980665          // blocage 4,32 kg·cm = 0,424 N·m (fiche S01) ; nominal 322 tr/min à 1,79 kg·cm
    public var jMoteur = 4e-5
    public var tensionFil = 4.0                      // N, SUPPOSÉE
    public var rendement = 0.95                      // par engrènement
    public var frottement = 0.004                    // N·m par palier
    public var bras = 0.150                          // m, manivelle
    public var manivelleTrMin = 60.0
    public var module = 1.25e-3
    public var alpha = 20.0 * .pi / 180
    public var z15 = 15.0, z45 = 45.0, z21 = 21.0, z35 = 35.0   // Bobineur_v8 : P-29, P-30, P-34, P-35
    public var largeurConique = 8e-3
    public var course = 0.0276                       // recul du chariot moteur = course de la patte dans sa fente
    public var levee = 0.00373                       // levée de la grappe (chaîne de cotes v10 corrigée)
    public var courseTige = 0.0276                   // poussée de la tige P-21 (la patte du chariot fait butée)
    public init() {}
}

public enum Phase: String, Sendable { case moteur = "mode moteur", bascule = "bascule par la tige", manivelle = "mode manivelle" }

/// Un montage de l'axe vertical, calibré par le calcul de poutre (axe_plastique.py).
public struct Montage: Codable, Identifiable, Hashable, Sendable {
    public init(id: String, nom: String, detail: String, jeuDeg: Double, degParN: Double, sigmaParN: Double) {
        self.id = id; self.nom = nom; self.detail = detail; self.jeuDeg = jeuDeg; self.degParN = degParN; self.sigmaParN = sigmaParN
    }
    public var id: String
    public var nom: String
    public var detail: String
    public var jeuDeg: Double        // basculement dû au jeu (2c/S)
    public var degParN: Double       // basculement élastique par newton d'effort tangentiel conique
    public var sigmaParN: Double     // contrainte max dans le PLA par newton (MPa/N)
}

public struct Etat {
    public init() {}
    public var t = 0.0
    public var phase = Phase.moteur
    public var thE07 = 0.0, wE07 = 0.0
    public var thGrappe = 0.0, thLateral = 0.0, thManivelle = 0.0
    public var chariot = 0.0, leve = 0.0, tige = 0.0
    public var coupleMoteur = 0.0, forceMain = 0.0
    public var ftConique = 0.0, faConique = 0.0, ftDroite = 0.0
    public var basculementDeg = 0.0, sigmaMPa = 0.0
    public var thArbreMoteur = 0.0               // seul l'arbre du moteur tourne ; le carter reste fixe sur le chariot
}

public final class Physique {
    public var p = Parametres()
    public var e = Etat()
    public var montage: Montage
    public var rayonFil: () -> Double          // rayon d'enroulement courant (fourni par le dépôt du fil)
    public var tDebutBascule = Double.infinity   // déclenchée par l'usager (tige P-21)
    public var dureeBascule = 2.0

    public init(montage: Montage, rayonFil: @escaping () -> Double) {
        self.montage = montage
        self.rayonFil = rayonFil
    }

    public var rm15: Double {
        let r15 = p.z15 * p.module / 2, r45 = p.z45 * p.module / 2
        return r15 * (1 - 0.5 * p.largeurConique / hypot(r15, r45))
    }
    public var deltaG: Double { atan(p.z45 / p.z15) }
    public var rapport: Double { (p.z45 / p.z15) * (p.z35 / p.z21) }   // 5:1

    public func reinitialiser() { e = Etat(); tDebutBascule = .infinity }
    public func demanderBascule() { if tDebutBascule == .infinity { tDebutBascule = e.t } }

    /// Avance d'un pas dt (s). Retourne l'angle tourné par E-07 pendant le pas.
    @discardableResult
    public func pas(_ dt: Double, jTotal: Double) -> Double {
        let r = rayonFil()
        let tFil = p.tensionFil * r
        let avant = e.thE07
        e.t += dt
        if e.t < tDebutBascule { e.phase = .moteur }
        else if e.t < tDebutBascule + dureeBascule { e.phase = .bascule }
        else { e.phase = .manivelle }

        switch e.phase {
        case .moteur:
            let tm = max(0, p.moteurTs * (1 - e.wE07 / p.moteurW0))
            e.coupleMoteur = tm
            let a = (tm - tFil - 2 * p.frottement) / (jTotal + p.jMoteur)
            e.wE07 = max(0, e.wE07 + a * dt)
            e.thE07 += e.wE07 * dt
            e.thArbreMoteur = e.thE07
            e.forceMain = 0; e.ftConique = 0; e.faConique = 0; e.ftDroite = 0
            e.chariot = 0; e.leve = 0; e.tige = 0
        case .bascule:
            let u = (e.t - tDebutBascule) / dureeBascule
            e.tige = u
            e.chariot = u * p.course                      // la tige entraîne directement la patte (jeu 0,2 mm)
            e.leve = min(1, max(0, (u * p.courseTige - 0.001) / 0.006)) * p.levee
            e.coupleMoteur = 0
            // E-07 ralentit sous la tension du fil
            let a = -(tFil + 2 * p.frottement) / jTotal
            e.wE07 = max(0, e.wE07 + a * dt)
            e.thE07 += e.wE07 * dt
        case .manivelle:
            e.chariot = p.course; e.leve = p.levee; e.tige = 1
            let wCible = p.manivelleTrMin * 2 * .pi / 60 * rapport
            let a = (wCible - e.wE07) / 0.3       // la main monte en vitesse en ~0,3 s
            e.wE07 += a * dt
            e.thE07 += e.wE07 * dt
            let tE07 = tFil + 2 * p.frottement + jTotal * a
            e.ftConique = abs(tE07) / rm15
            e.faConique = e.ftConique * tan(p.alpha) * sin(deltaG)
            let tGrappe = tE07 * p.z45 / p.z15 / p.rendement
            e.ftDroite = abs(tGrappe) / (p.z21 * p.module / 2)
            let tMan = tGrappe * p.z35 / p.z21 / p.rendement
            e.forceMain = abs(tMan) / p.bras
            e.thGrappe = -e.thE07 * p.z15 / p.z45
            e.thLateral = -e.thGrappe * p.z21 / p.z35
            e.thManivelle = e.thLateral
        }
        e.basculementDeg = e.phase == .manivelle ? montage.jeuDeg + montage.degParN * e.ftConique : 0
        e.sigmaMPa = montage.sigmaParN * e.ftConique
        return e.thE07 - avant
    }
}
