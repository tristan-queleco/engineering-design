#!/bin/bash
# Compile Engineering Design sur le Mac et l'installe dans ~/Applications (aucun mot de passe).
#   bash macos/construire.sh
# Garder le dépôt HORS d'iCloud (ex. ~/Developer/engineering-design) : les fichiers « dataless » cassent git et swift build.
set -euo pipefail
ICI="$(cd "$(dirname "$0")" && pwd)"
PAQUET="$ICI/EngineeringDesign"
APP="$HOME/Applications/Engineering Design.app"

echo "1/4 Compilation (release)…"
cd "$PAQUET"
swift build -c release --product EngineeringDesign
swift build -c release --product engineering-design-mcp
BIN="$(swift build -c release --show-bin-path)"

echo "2/4 Icône…"
if [ ! -f "$ICI/logo/AppIcon.icns" ]; then bash "$ICI/logo/construire-icone.sh"; fi

echo "3/4 Paquet .app…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/EngineeringDesign" "$APP/Contents/MacOS/EngineeringDesign"
cp "$BIN/engineering-design-mcp" "$APP/Contents/MacOS/engineering-design-mcp"
cp "$ICI/logo/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Engineering Design</string>
  <key>CFBundleDisplayName</key><string>Engineering Design</string>
  <key>CFBundleIdentifier</key><string>ca.tristanmorin.engineeringdesign</string>
  <key>CFBundleExecutable</key><string>EngineeringDesign</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || echo "(signature ad hoc ignorée)"
touch "$APP"

echo "4/4 Terminé : $APP"
echo "Brancher Claude Code :  claude mcp add -s user engineering-design -- \"$APP/Contents/MacOS/engineering-design-mcp\""
open "$APP"
