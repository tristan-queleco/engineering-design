#!/bin/bash
# Fabrique AppIcon.icns (macOS) à partir de logo-1024.png. Sur le Mac : bash construire-icone.sh
set -e
cd "$(dirname "$0")"
rm -rf AppIcon.iconset && mkdir AppIcon.iconset
for s in 16 32 128 256 512; do
  sips -z $s $s logo-1024.png --out AppIcon.iconset/icon_${s}x${s}.png >/dev/null
  d=$((s*2)); sips -z $d $d logo-1024.png --out AppIcon.iconset/icon_${s}x${s}@2x.png >/dev/null
done
iconutil -c icns AppIcon.iconset -o AppIcon.icns
rm -rf AppIcon.iconset
echo "AppIcon.icns prêt"
