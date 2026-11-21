# Logo Engineering Design

Métaphore : une pièce prismatique en isométrie (le modèle CAO), percée d'un alésage, avec une cote orange (le paramètre qu'on itère). Fond bleu plan, quadrillage discret.

Règles Apple (HIG, icône d'app macOS) appliquées :
- Canevas 1024 × 1024, forme arrondie 824 × 824 centrée (marge 100 px), ombre portée douce.
- Une seule idée, lisible à 16 px; aucun texte dans l'icône.
- Vue de face légèrement en perspective, lumière venant du haut (face du dessus la plus claire).
- Couches séparées pour Icon Composer (macOS 26, Liquid Glass) : `couche-1-fond.svg`, `couche-2-piece.svg`, `couche-3-cote.svg`.

Fichiers :
- `logo.svg` : source; `gen.py` la régénère (et les couches).
- `logo-1024.png` : rendu.
- `construire-icone.sh` : fabrique `AppIcon.icns` sur le Mac (sips + iconutil).
