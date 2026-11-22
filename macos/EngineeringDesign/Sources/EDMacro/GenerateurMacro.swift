import Foundation
import EDModele

/// Écrit la macro VBA SolidWorks d'une pièce paramétrée. La macro crée de VRAIES fonctions
/// SolidWorks cotées (esquisse, révolution, enlèvements) : on peut ensuite double-cliquer une cote.
/// Les utilitaires viennent de Eq15_pieces_Tristan.bas (testé dans le PTV de la FSG, oct. 2026).
public enum GenerateurMacro {

    public static func macro(_ p: Piece, date: Date = Date()) -> String {
        switch p.type {
        case .arbre: return entete(p, date: date) + utilitaires + arbre(p)
        }
    }

    /// Texte prêt pour l'éditeur VBA : CRLF, encodé cp1252 (sinon les accents cassent l'import).
    public static func donneesBas(_ texte: String) -> Data {
        let crlf = texte.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\n", with: "\r\n")
        return crlf.data(using: .windowsCP1252, allowLossyConversion: true) ?? Data(crlf.utf8)
    }

    @discardableResult
    public static func ecrire(_ p: Piece, dans dossier: URL) throws -> URL {
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let url = dossier.appendingPathComponent("\(p.fichier).bas")
        try donneesBas(macro(p)).write(to: url, options: .atomic)
        return url
    }

    // MARK: - morceaux

    static func n(_ v: Double) -> String {          // nombre VBA (point décimal)
        var s = String(format: "%.4f", v)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    static func entete(_ p: Piece, date: Date) -> String {
        let df = DateFormatter(); df.locale = Locale(identifier: "fr_CA"); df.dateFormat = "d MMM yyyy HH:mm"
        var s = """
        ' ============================================================================
        ' \(p.id) \(p.nom) (\(p.fichier).SLDPRT), révision \(p.revision)
        ' Générée par Engineering Design le \(df.string(from: date)). Ne pas modifier à la main :
        ' changer les paramètres dans l'app, puis régénérer la macro.
        '
        ' Paramètres :

        """
        for q in p.parametres {
            s += "'   \(q.cle) = \(n(q.valeur)) \(q.unite)   \(q.nom)\n"
        }
        s += """
        '
        ' Utilisation dans SolidWorks (PTV FSG) :
        '   1. Outils > Macro > Nouveau... > enregistrer « \(p.fichier).swp » dans le dossier voulu
        '   2. Éditeur VBA : Fichier > Importer un fichier... > ce .bas
        '   3. Outils > Références : cocher SolidWorks Type Library et SolidWorks Constant type library
        '   4. Curseur dans Sub main, puis F5. La pièce est enregistrée à côté de la macro.
        ' Unités de l'API : mètres (MM convertit). Axe X = axe de l'arbre, Y vers le haut.
        ' ============================================================================
        Option Explicit

        Dim swApp As SldWorks.SldWorks
        Dim Part As SldWorks.ModelDoc2
        Dim SM As SldWorks.SketchManager
        Dim FM As SldWorks.FeatureManager
        Dim dossier As String

        Const MM As Double = 0.001
        Const PI As Double = 3.14159265358979


        """
        return s
    }

    static let utilitaires = """
    ' =========================== utilitaires ===========================
    Private Sub NouvellePiece()
        Dim gabarit As String
        gabarit = swApp.GetUserPreferenceStringValue(swDefaultTemplatePart)
        Set Part = swApp.NewDocument(gabarit, 0, 0, 0)
        Set SM = Part.SketchManager
        Set FM = Part.FeatureManager
    End Sub

    ' n = 1 face (XY), 2 dessus (XZ), 3 droite (YZ) : sans dépendre de la langue de SolidWorks
    Private Function PlanBase(n As Integer) As SldWorks.Feature
        Dim f As SldWorks.Feature, k As Integer
        Set f = Part.FirstFeature
        Do While Not f Is Nothing
            If f.GetTypeName2 = "RefPlane" Then
                k = k + 1
                If k = n Then Set PlanBase = f: Exit Function
            End If
            Set f = f.GetNextFeature
        Loop
    End Function

    Private Sub OuvrirEsquisse(plan As SldWorks.Feature)
        Part.ClearSelection2 True
        plan.Select2 False, 0
        SM.InsertSketch True
        SM.AddToDB = True
    End Sub

    Private Sub FermerEsquisse(nom As String)
        Dim f As SldWorks.Feature
        Set f = SM.ActiveSketch
        SM.AddToDB = False
        SM.InsertSketch True
        f.Name = nom
        Part.ClearSelection2 True
        f.Select2 False, 0
    End Sub

    Private Function Ligne(ByVal x1 As Double, ByVal y1 As Double, ByVal x2 As Double, ByVal y2 As Double) As SldWorks.SketchSegment
        Set Ligne = SM.CreateLine(x1 * MM, y1 * MM, 0, x2 * MM, y2 * MM, 0)
    End Function

    Private Sub Coter(ByVal seg As Object, ByVal xt As Double, ByVal yt As Double)
        Part.ClearSelection2 True
        seg.Select4 False, Nothing
        Part.AddDimension2 xt * MM, yt * MM, 0
        Part.ClearSelection2 True
    End Sub

    ' Enlèvement symétrique au plan d'esquisse
    Private Sub EnlevementMilieu(ByVal prof As Double, nom As String)
        Dim f As SldWorks.Feature
        Set f = FM.FeatureCut4(True, False, False, swEndCondMidPlane, 0, prof * MM, 0, _
            False, False, False, False, 0, 0, False, False, False, False, False, True, True, _
            False, False, False, 0, 0, False, False)
        If f Is Nothing Then MsgBox "Échec de l'enlèvement " & nom Else f.Name = nom
    End Sub

    Private Sub Revolution(nom As String)
        Dim f As SldWorks.Feature
        Set f = FM.FeatureRevolve2(True, True, False, False, False, False, swEndCondBlind, 0, _
            2 * PI, 0, False, False, 0, 0, 0, 0, 0, True, True, True)
        If f Is Nothing Then MsgBox "Échec de la révolution " & nom Else f.Name = nom
    End Sub

    Private Sub Enregistrer(nom As String, materiau As String)
        Dim e As Long, w As Long, db As String
        Part.ForceRebuild3 False
        If materiau = "AISI 303" Then
            ' 303 n'est pas dans toutes les bibliothèques : sinon AISI 304 (propriétés voisines)
            Part.SetMaterialPropertyName2 "", "SOLIDWORKS Materials", "AISI 303"
            If Part.GetMaterialPropertyName2("", db) = "" Then Part.SetMaterialPropertyName2 "", "SOLIDWORKS Materials", "AISI 304"
        ElseIf materiau <> "" Then
            Part.SetMaterialPropertyName2 "", "SOLIDWORKS Materials", materiau
        End If
        Part.ShowNamedView2 "*Isometric", 7
        Part.ViewZoomtofit2
        Part.Extension.SaveAs dossier & nom & ".SLDPRT", 0, 1, Nothing, e, w
    End Sub

    ' Profil de révolution : points (x, r) le long de l'axe X, fermé sur l'axe. Chaque segment est coté.
    Private Sub ProfilRevolution(pts As Variant)
        Dim i As Integer, n As Integer, s As SldWorks.SketchSegment
        Dim xa As Double, ya As Double, xb As Double, yb As Double, xmin As Double, xmax As Double
        n = (UBound(pts) + 1) / 2
        xmin = pts(0): xmax = pts(0)
        For i = 0 To n - 1
            If pts(2 * i) < xmin Then xmin = pts(2 * i)
            If pts(2 * i) > xmax Then xmax = pts(2 * i)
        Next i
        For i = 0 To n - 1
            xa = pts(2 * i): ya = pts(2 * i + 1)
            xb = pts((2 * i + 2) Mod (2 * n)): yb = pts((2 * i + 3) Mod (2 * n))
            Set s = Ligne(xa, ya, xb, yb)
            If ya <> 0 Or yb <> 0 Then
                If xa = xb Then Coter s, xa - 2, (ya + yb) / 2 Else Coter s, (xa + xb) / 2, ya + 3
            End If
        Next i
        SM.CreateCenterLine (xmin - 5) * MM, 0, 0, (xmax + 5) * MM, 0, 0
    End Sub

    ' Méplat : enlève tout ce qui dépasse Y = m entre x1 et x2 (cote m = distance axe-plat)
    Private Sub FaireMeplat(ByVal x1 As Double, ByVal x2 As Double, ByVal m As Double, ByVal r As Double, nom As String)
        Dim s1 As SldWorks.SketchSegment, ax As SldWorks.SketchSegment, h As Double
        h = r - m + 1
        OuvrirEsquisse PlanBase(1)
        Set s1 = Ligne(x1, m, x2, m)
        Ligne x2, m, x2, m + h
        Ligne x2, m + h, x1, m + h
        Ligne x1, m + h, x1, m
        Set ax = SM.CreateCenterLine((x1 - 1) * MM, 0, 0, (x2 + 1) * MM, 0, 0)
        Coter s1, (x1 + x2) / 2, m + h + 2
        Part.ClearSelection2 True
        s1.Select4 False, Nothing
        ax.Select4 True, Nothing
        Part.AddDimension2 (x1 - 3) * MM, m / 2 * MM, 0
        Part.ClearSelection2 True
        FermerEsquisse "Esq_" & nom
        EnlevementMilieu 2 * r + 4, nom
    End Sub


    """

    static func arbre(_ p: Piece) -> String {
        let g = GeometrieArbre(p)
        let pts = g.profil.map { "\(n($0.x)), \(n($0.r))" }
        var lignes: [String] = []
        var courante = ""
        for (i, t) in pts.enumerated() {
            courante += t + (i < pts.count - 1 ? ", " : "")
            if (i + 1) % 4 == 0 && i < pts.count - 1 { lignes.append(courante + "_"); courante = "" }
        }
        lignes.append(courante)
        let tableau = lignes.joined(separator: "\n        ")
        var meplats = ""
        for (i, m) in g.meplats.enumerated() {
            meplats += "    FaireMeplat \(n(m.lowerBound)), \(n(m.upperBound)), \(n(g.distanceMeplat)), \(n(g.rayon)), \"Meplat_\(i + 1)\"\n"
        }
        return """
        ' =========================== \(p.id) \(p.nom) ===========================
        Sub main()
            Set swApp = Application.SldWorks
            dossier = swApp.GetCurrentMacroPathFolder & "\\"
            swApp.SetUserPreferenceToggle swInputDimValOnCreate, False
            NouvellePiece
            OuvrirEsquisse PlanBase(1)
            ProfilRevolution Array(\(tableau))
            FermerEsquisse "Esq_profil_tourne"
            Revolution "Arbre_rond"
        \(meplats)    Enregistrer "\(p.fichier)", "\(p.materiau)"
            MsgBox "\(p.fichier).SLDPRT créé dans " & dossier
        End Sub

        """
    }
}
