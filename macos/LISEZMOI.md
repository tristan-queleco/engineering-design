# Engineering Design pour macOS

App native (SwiftUI + SceneKit), compilée à 100 % sur le Mac. Jalon 1 :

- **Pièces paramétrées** : l'arbre E-07 de l'enrouleur (Ø, longueur, gorges DIN 471, méplats). Une cote changée met à jour l'aperçu 3D et la vérification.
- **Macro SolidWorks** : le bouton écrit `~/Documents/Engineering Design/macros/<pièce>.bas` (cp1252) et copie son texte. On la colle dans l'éditeur VBA du PTV FSG : elle crée de vraies fonctions SolidWorks cotées.
- **STL** : même maillage que l'aperçu.
- **Assemblage** : les pièces réelles du simulateur v3 (`assemblage.json` + `.obj`) et sa vérification (conflits en rouge, jeux, pièces flottantes).
- **Simulation** : le moteur physique du simulateur v3 (`Sources/MoteurEnrouleur`, copie de la branche `claude/project-thread-xwxdda` du dépôt vault, commit 156f7dc).
- **MCP local** : `engineering-design-mcp` (stdio). Claude Desktop et Claude Code l'utilisent avec le compte Claude de l'usager : aucune clé API.

## Compiler

```bash
git clone --depth 1 --filter=blob:none --sparse -b claude/project-thread-43wthw https://github.com/tristan-queleco/engineering-design ~/Developer/engineering-design
cd ~/Developer/engineering-design && git sparse-checkout set macos
bash macos/construire.sh
```

L'app s'installe dans `~/Applications/Engineering Design.app`. Le projet vit dans `~/Documents/Engineering Design/enrouleur.edprojet.json`, partagé par l'app et le serveur MCP.

## Outils MCP

`lister_pieces`, `changer_parametre`, `generer_macro`, `exporter_stl`, `essai_enroulement`.

## Suite

- Jalon 2 : relire le STEP exporté par SolidWorks (OpenCASCADE), vérification d'assemblage en Swift, E-07 paramétrée placée dans l'assemblage.
- Jalon 3 : MCP par connexion de compte (OAuth) pour claude.ai et ChatGPT.
