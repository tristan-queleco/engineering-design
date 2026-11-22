import Foundation

/// Un maillon de fil posé sur la bobine (sphère de diamètre d).
/// a : position axiale depuis la face intérieure du flasque côté moteur (m)
/// r : rayon du centre (m) ; phi : angle dans le repère de la bobine (rad, croît avec l'enroulement)
public struct Maillon: Codable, Sendable { public var a, r, phi: Double }

/// Géométrie de la bobine et du brin, en mètres.
public struct GeometrieBobine: Codable, Sendable {
    public var rNoyau = 0.007
    public var rFlasque = 0.027
    public var largeur = 0.018
    public var arrivee = 0.01731        // position axiale du point d'arrivée du fil (coupe-fil), mesurée comme a
    public var distanceArrivee = 0.099  // brin libre jusqu'à la pince du tensionneur (CAD v8)
    public init() {}
}

/// Guide d'enroulement 100 % imprimé (vis à double hélice entraînée 1:1 par E-07) : l'œillet fait un aller-retour
/// de `course` centré sur `centre`, à `pasTour` par tour de bobine, avec un jeu mort `jeu` (cliquet dans la rainure).
/// G1 z17 → renvoi z22 → G2 z32 (22 nov.) : la vis fait 17/32 de tour par tour de bobine (pas 11 × 17/32 = 5,84 mm). Avec 1:1, le motif
/// revenait tous les 3 tours et le fil retombait aux mêmes endroits (bosses de 1,8 mm). `lisse` : retournement adouci de la vis réelle.
public struct GuideVaEtVient: Codable, Sendable {
    public var pasTour = 0.011 * 17 / 32, course = 0.0165, jeu = 0.0005, centre = 0.009, distance = 0.044, lisse = 0.07
    public init() {}
    /// Position de l'œillet (m, même repère que a) après `tours` tours de bobine, sans le jeu.
    public func position(tours: Double) -> Double {
        func tri(_ v: Double) -> Double { let u = v.truncatingRemainder(dividingBy: 2); let w = u < 0 ? u + 2 : u; return w < 1 ? w : 2 - w }
        let v = tours * pasTour / course
        var s = 0.0
        for j in -10...10 { s += tri(v + Double(j) * lisse / 10) }
        return centre - course / 2 + course * s / 21
    }
}

/// Générateur pseudo-aléatoire reproductible (xorshift) + loi normale.
public struct Hasard: RandomNumberGenerator, Sendable {
    var s: UInt64
    public init(graine: UInt64) { s = graine &* 6364136223846793005 &+ 1442695040888963407; if s == 0 { s = 1 } }
    public mutating func next() -> UInt64 { s ^= s << 13; s ^= s >> 7; s ^= s << 17; return s }
    public mutating func normale() -> Double {
        let u1 = max(1e-12, Double.random(in: 0..<1, using: &self)), u2 = Double.random(in: 0..<1, using: &self)
        return sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
    }
}

/// Enroulement sans guide, maillon par maillon (même modèle que fil_hauteur.py).
/// Chaque maillon arrive au point de tangence du brin puis glisse sur la surface du fil déjà posé sous deux forces :
/// la tension qui l'appuie vers l'axe (T·d/r, effet cabestan) et la composante latérale de la tension
/// (angle de défilement vers le point d'arrivée, T·(a_arrivée − a)/D). Frottement de Coulomb (μ tiré au hasard).
/// Le fil n'est jamais droit (mémoire de la bobine source) : le point de contact erre au hasard (corrélé).
public final class FilEnroulement {
    public let d: Double
    public var g: GeometrieBobine
    public var mu = 0.20, muSd = 0.05, bruit = 0.30
    /// Guide imprimé : si présent, le point d'arrivée suit l'œillet du suiveur.
    public var guide: GuideVaEtVient? { didSet { if let gd = guide { eG = gd.position(tours: 0); g.arrivee = eG; g.distanceArrivee = gd.distance } } }
    public private(set) var tours = 0.0
    private var eG = 0.0
    /// Position axiale actuelle de l'œillet du guide (m), ou nil sans guide.
    public var oeillet: Double? { guide == nil ? nil : eG }
    public private(set) var maillons: [Maillon] = []
    public private(set) var longueur = 0.0
    public private(set) var deborde = false
    private var rng: Hasard
    private var zeta = 0.0
    private var aCour: Double
    private var phiCour = 0.0
    private var bacs: [[Int32]]
    private let nbBacs: Int

    public init(diametre: Double, geometrie: GeometrieBobine = GeometrieBobine(), graine: UInt64 = 1, aDepart: Double? = nil) {
        d = diametre; g = geometrie
        rng = Hasard(graine: graine)
        nbBacs = max(16, Int(2 * .pi * (geometrie.rNoyau + diametre / 2) / diametre))
        bacs = Array(repeating: [], count: nbBacs)
        aCour = min(max(aDepart ?? geometrie.arrivee, diametre / 2), geometrie.largeur - diametre / 2)
    }

    public var rayonCourant: Double { (maillons.last?.r ?? g.rNoyau + d / 2) + d / 2 }
    public var rayonMax: Double { (maillons.map(\.r).max() ?? g.rNoyau) + d / 2 }
    /// Angle de bobine (depuis le début) à atteindre pour poser le prochain maillon.
    public var phiProchain: Double { phiCour + d / (maillons.last?.r ?? g.rNoyau + d / 2) }

    private func bac(_ phi: Double) -> Int {
        let p = phi.truncatingRemainder(dividingBy: 2 * .pi)
        return (Int((p < 0 ? p + 2 * .pi : p) / (2 * .pi) * Double(nbBacs))) % nbBacs
    }

    /// Rayon du centre d'un maillon posé en (a, phi) : sur le noyau ou sur les maillons voisins.
    public func hauteur(_ a: Double, _ phi: Double) -> Double {
        var h = g.rNoyau + d / 2
        let ib = bac(phi)
        for db in -1...1 {
            for q in bacs[(ib + db + nbBacs) % nbBacs] {
                let m = maillons[Int(q)]
                let da = a - m.a
                if abs(da) >= d { continue }
                var dphi = (phi - m.phi).truncatingRemainder(dividingBy: 2 * .pi)
                if dphi > .pi { dphi -= 2 * .pi } else if dphi < -.pi { dphi += 2 * .pi }
                let ds = dphi * m.r
                if abs(ds) >= d { continue }
                let c2 = d * d - da * da - ds * ds
                if c2 > 0 { h = max(h, m.r + c2.squareRoot()) }
            }
        }
        return h
    }

    /// Pose un maillon et le retourne (nil si la bobine déborde déjà).
    @discardableResult
    public func poserMaillon() -> Maillon? {
        guard !deborde else { return nil }
        let rPrev = maillons.last?.r ?? g.rNoyau + d / 2
        phiCour += d / rPrev
        tours += d / rPrev / (2 * .pi)
        if let gd = guide {
            let x = gd.position(tours: tours)
            if x - eG > gd.jeu / 2 { eG = x - gd.jeu / 2 } else if eG - x > gd.jeu / 2 { eG = x + gd.jeu / 2 }
            g.arrivee = eG; g.distanceArrivee = gd.distance
        }
        let zn = 0.9 * zeta + (1 - 0.81).squareRoot() * bruit * d * rng.normale()
        var a = aCour + (zn - zeta); zeta = zn
        // Avec le guide, le brin tendu entre l'œillet et le point de tangence entraîne le point de pose :
        // il rattrape l'œillet avec un retard du premier ordre, da/dl = (œillet − a) / longueur libre.
        if guide != nil { a += (g.arrivee - aCour) * d / g.distanceArrivee }
        let amin = d / 2, amax = g.largeur - d / 2
        a = min(max(a, amin), amax)
        let mu = max(0.05, self.mu + muSd * rng.normale())
        let pas = 0.02 * d
        for _ in 0..<400 {
            let h = hauteur(a, phiCour)
            let flat = (g.arrivee - a) / g.distanceArrivee
            let frad = d / h
            let ap = min(a + pas, amax), am = max(a - pas, amin)
            let hp = hauteur(ap, phiCour), hm = hauteur(am, phiCour)
            let wp = flat * (ap - a) - frad * (hp - h)
            let wm = flat * (am - a) - frad * (hm - h)
            let sp = hypot(ap - a, hp - h) + 1e-15, sm = hypot(am - a, hm - h) + 1e-15
            let seuil = mu * hypot(flat, frad)
            if ap != a && wp / sp > seuil && wp >= wm { a = ap }
            else if am != a && wm / sm > seuil { a = am }
            else { break }
        }
        // Crête instable : un fil posé sur le dessus d'UN seul fil (les deux côtés plus bas) ne tient pas ;
        // la moindre vibration le fait rouler dans le creux voisin (côté du tirage latéral, sinon au hasard).
        let e = 0.25 * d
        var h = hauteur(a, phiCour)
        if hauteur(min(a + e, amax), phiCour) < h - 0.01 * d && hauteur(max(a - e, amin), phiCour) < h - 0.01 * d {
            let flat = (g.arrivee - a) / g.distanceArrivee
            let sgn: Double = flat > 0.002 ? 1 : flat < -0.002 ? -1 : (Bool.random(using: &rng) ? 1 : -1)
            for _ in 0..<400 {
                let an = min(max(a + sgn * pas, amin), amax)
                if an == a { break }
                let hn = hauteur(an, phiCour)
                if hn > h + 1e-9 { break }
                a = an; h = hn
            }
        }
        let m = Maillon(a: a, r: hauteur(a, phiCour), phi: phiCour)
        bacs[bac(m.phi)].append(Int32(maillons.count))
        maillons.append(m)
        aCour = a
        longueur += d
        if m.r + d / 2 > g.rFlasque { deborde = true }
        return m
    }

    /// Pose tous les maillons que la rotation de la bobine (angle total, rad) a amenés au point de tangence.
    public func avancer(jusqua angle: Double) -> [Maillon] {
        var nouveaux: [Maillon] = []
        while !deborde && phiProchain <= angle, let m = poserMaillon() { nouveaux.append(m) }
        return nouveaux
    }

    /// Profil de la pile : rayon extérieur max par tranche axiale de largeur d.
    public func profil() -> [Double] {
        let n = max(1, Int(g.largeur / d))
        var p = Array(repeating: g.rNoyau, count: n)
        for m in maillons { let i = min(n - 1, max(0, Int(m.a / d))); p[i] = max(p[i], m.r + d / 2) }
        return p
    }
}
