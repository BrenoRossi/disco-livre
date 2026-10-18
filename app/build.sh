#!/bin/zsh
# Compila o "Disco Livre.app" (precisa só das Ferramentas de Linha de Comando: xcode-select --install)
set -e
cd "${0:A:h}"
VERSAO=$(sed -n 's/^VERSAO="\(.*\)"/\1/p' ../bin/disco-livre)

# Apenas artefatos recém-gerados. Não remove quarentena ou metadados do fonte.
# https://developer.apple.com/library/archive/qa/qa1940/_index.html
limpar_metadados_build() {
  local item atributo
  [[ -d $1 && ! -L $1 && $1 == *.app ]] || return 1
  while IFS= read -r -d '' item; do
    for atributo in com.apple.FinderInfo com.apple.ResourceFork; do
      if xattr -sp "$atributo" "$item" >/dev/null 2>&1; then
        xattr -sd "$atributo" "$item" || return 1
      fi
    done
  done < <(find "$1" -print0)
  return 0
}

# O FileProvider pode recolocar FinderInfo imediatamente em um .app dentro de
# Documentos. Gere/assine fora de pastas sincronizadas; guarde só o caminho aqui.
BUILD_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/disco-livre-build.XXXXXX")
APP="$BUILD_ROOT/Disco Livre.app"
TMP="$BUILD_ROOT/tmp"
trap 'rm -rf -- "$TMP"' EXIT
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$TMP/AppIcon.iconset"

for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -parse-as-library -target $arch-apple-macos13.0 \
    DiscoLivre.swift -o "$TMP/DiscoLivre-$arch"
done
lipo -create "$TMP"/DiscoLivre-* -output "$APP/Contents/MacOS/DiscoLivre"

swiftc -O -swift-version 5 icone.swift -o "$TMP/icone"
"$TMP/icone" "$TMP/AppIcon.iconset"
iconutil -c icns "$TMP/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"

# a ferramenta e a skill vão dentro do app (autoinstalação pra quem baixa o .dmg)
cp ../bin/disco-livre "$APP/Contents/Resources/disco-livre"
mkdir -p "$APP/Contents/Resources/skill-disco-livre"
cp ../skill/disco-livre/SKILL.md "$APP/Contents/Resources/skill-disco-livre/SKILL.md"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>DiscoLivre</string>
  <key>CFBundleIdentifier</key><string>com.disco-livre.app</string>
  <key>CFBundleName</key><string>Disco Livre</string>
  <key>CFBundleDisplayName</key><string>Disco Livre</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSAO</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
EOF

limpar_metadados_build "$APP"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
rm -rf "$TMP"
mkdir -p build
print -r -- "$APP" > build/app-path
print -r -- "✓ $APP"
