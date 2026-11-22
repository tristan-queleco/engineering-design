// swift-tools-version:5.9
import PackageDescription

// Engineering Design : app native macOS (SwiftUI + SceneKit), compilée à 100 % en local.
// Modules :
//   EDModele        pièces paramétrées (JSON), validation, maillage d'aperçu et STL — Foundation seulement
//   EDMacro         macro VBA SolidWorks générée à partir du modèle (cp1252, CRLF)
//   MoteurEnrouleur physique de l'enrouleur GMC-2024 (copie du simulateur v3, voir LISEZMOI)
//   EngineeringDesign           l'app
//   engineering-design-mcp      serveur MCP local (stdio) pour Claude Desktop / Claude Code
let package = Package(
    name: "EngineeringDesign",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "EngineeringDesign", targets: ["EngineeringDesign"]),
        .executable(name: "engineering-design-mcp", targets: ["engineering-design-mcp"]),
    ],
    targets: [
        .target(name: "EDModele", path: "Sources/EDModele"),
        .target(name: "EDMacro", dependencies: ["EDModele"], path: "Sources/EDMacro"),
        .target(name: "MoteurEnrouleur", path: "Sources/MoteurEnrouleur"),
        .executableTarget(name: "EngineeringDesign",
                          dependencies: ["EDModele", "EDMacro", "MoteurEnrouleur"],
                          path: "Sources/EngineeringDesign"),
        .executableTarget(name: "engineering-design-mcp",
                          dependencies: ["EDModele", "EDMacro", "MoteurEnrouleur"],
                          path: "Sources/engineering-design-mcp"),
    ]
)
