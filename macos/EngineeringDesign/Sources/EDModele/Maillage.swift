import Foundation
import simd

/// Maillage triangulé (un sommet par coin, normales plates) : aperçu 3D et STL.
public struct Maillage: Sendable {
    public var positions: [SIMD3<Float>] = []
    public var normales: [SIMD3<Float>] = []
    public var nombreTriangles: Int { positions.count / 3 }

    mutating func triangle(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ c: SIMD3<Double>) {
        let n = simd_cross(b - a, c - a)
        let l = simd_length(n)
        guard l > 1e-9 else { return }          // triangle dégénéré (méplat qui écrase un coin)
        let u = n / l
        let nf = SIMD3<Float>(Float(u.x), Float(u.y), Float(u.z))
        for p in [a, b, c] { positions.append(SIMD3<Float>(Float(p.x), Float(p.y), Float(p.z))); normales.append(nf) }
    }

    /// STL ASCII en mm.
    public func stl(nom: String) -> String {
        var s = "solid \(nom)\n"
        s.reserveCapacity(nombreTriangles * 200)
        for t in 0..<nombreTriangles {
            let n = normales[3 * t]
            s += "facet normal \(n.x) \(n.y) \(n.z)\n outer loop\n"
            for k in 0..<3 { let p = positions[3 * t + k]; s += "  vertex \(p.x) \(p.y) \(p.z)\n" }
            s += " endloop\nendfacet\n"
        }
        return s + "endsolid \(nom)\n"
    }
}

public extension Piece {
    func maillage(divisions: Int = 72) -> Maillage {
        switch type {
        case .arbre: return GeometrieArbre(self).maillage(divisions: divisions)
        }
    }
}

public extension GeometrieArbre {
    /// Révolution du profil autour de X (Y vers le haut), puis méplats : tout ce qui dépasse Y = m
    /// dans une zone de méplat est ramené sur le plan (même résultat que l'enlèvement de la macro).
    func maillage(divisions: Int = 72) -> Maillage {
        var m = Maillage()
        let bornes = meplats.flatMap { [$0.lowerBound, $0.upperBound] }

        // 1. couper les segments du profil aux bornes des méplats
        var segs: [((x: Double, r: Double), (x: Double, r: Double))] = []
        let p = profil
        for i in 0..<(p.count - 1) {
            let a = p[i], b = p[i + 1]
            var xs = [a.x]
            if a.x != b.x {
                let dedans = bornes.filter { $0 > min(a.x, b.x) && $0 < max(a.x, b.x) }.sorted()
                xs += a.x < b.x ? dedans : Array(dedans.reversed())
            }
            xs.append(b.x)
            for k in 0..<(xs.count - 1) {
                func r(_ x: Double) -> Double { a.x == b.x ? a.r : a.r + (b.r - a.r) * (x - a.x) / (b.x - a.x) }
                let xa = xs[k], xb = xs[k + 1]
                segs.append(a.x == b.x ? ((a.x, a.r), (b.x, b.r)) : ((xa, r(xa)), (xb, r(xb))))
            }
        }

        func sommet(_ x: Double, _ r: Double, _ t: Double, plat: Bool) -> SIMD3<Double> {
            var y = r * cos(t)
            let z = r * sin(t)
            if plat, y > distanceMeplat { y = distanceMeplat }
            return SIMD3(x, y, z)
        }

        // 2. surfaces de révolution (sens des triangles : normales vers l'extérieur)
        let dt = 2 * Double.pi / Double(divisions)
        for (a, b) in segs {
            let plat = dansMeplat((a.x + b.x) / 2)
            for k in 0..<divisions {
                let t0 = Double(k) * dt, t1 = Double(k + 1) * dt
                let A = sommet(a.x, a.r, t0, plat: plat), B = sommet(b.x, b.r, t0, plat: plat)
                let C = sommet(b.x, b.r, t1, plat: plat), D = sommet(a.x, a.r, t1, plat: plat)
                m.triangle(A, C, B)
                m.triangle(A, D, C)
            }
        }

        // 3. murs aux bornes intérieures des méplats (passage du rond au plat)
        for x in bornes where x > 0 && x < longueur {
            let r = rayonA(x)
            guard r > distanceMeplat else { continue }
            for k in 0..<divisions {
                let t0 = Double(k) * dt, t1 = Double(k + 1) * dt
                let R0 = sommet(x, r, t0, plat: false), R1 = sommet(x, r, t1, plat: false)
                let P0 = sommet(x, r, t0, plat: true), P1 = sommet(x, r, t1, plat: true)
                m.triangle(R0, P0, P1)
                m.triangle(R0, P1, R1)
            }
        }
        return m
    }

    /// Rayon extérieur du profil à l'abscisse x.
    func rayonA(_ x: Double) -> Double {
        for g in gorges where x > g && x < g + largeurGorge { return rayonGorge }
        return rayon
    }
}
