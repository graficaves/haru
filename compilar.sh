#!/bin/bash
# Compila Haru y arma el bundle build/Haru.app. No necesita Xcode: alcanza con
# swiftc y el SDK de las Command Line Tools (xcode-select --install).
#
#   ./compilar.sh              para la arquitectura de esta Mac (arm64 o x86_64)
#   ./compilar.sh --universal  binario universal (arm64 + x86_64) con lipo
set -euo pipefail
cd "$(dirname "$0")"

UNIVERSAL=0
for arg in "$@"; do
  case "$arg" in
    --universal) UNIVERSAL=1 ;;
    *) echo "Uso: $0 [--universal]"; exit 2 ;;
  esac
done

APP="build/Haru.app"
BIN="$APP/Contents/MacOS/Haru"
FUENTES=(Sources/Logica/*.swift Sources/App/*.swift)
MARCOS=(-framework SwiftUI -framework AppKit -framework ServiceManagement -framework ApplicationServices)

compilar() { # $1 = arquitectura, $2 = salida
  swiftc -O -target "$1-apple-macos14.0" -parse-as-library "${MARCOS[@]}" "${FUENTES[@]}" -o "$2"
}

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

if [ "$UNIVERSAL" = 1 ]; then
  echo "▸ Compilando para arm64 y x86_64…"
  compilar arm64 build/Haru-arm64
  compilar x86_64 build/Haru-x86_64
  lipo -create build/Haru-arm64 build/Haru-x86_64 -output "$BIN"
  rm -f build/Haru-arm64 build/Haru-x86_64
else
  ARQ="$(uname -m)"
  echo "▸ Compilando para ${ARQ}…"
  compilar "$ARQ" "$BIN"
fi

echo "▸ Armando el bundle…"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>es</string>
	<key>CFBundleExecutable</key>
	<string>Haru</string>
	<key>CFBundleIdentifier</key>
	<string>io.github.graficaves.haru</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>Haru</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSAppleEventsUsageDescription</key>
	<string>Haru usa System Events para cerrar la ventana de VS Code del proyecto que cerrás.</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP/Contents/PkgInfo"

# Firma ad-hoc: sin firma macOS no da identidad estable a la app. Cada
# compilación cambia la firma, así que el permiso de Accesibilidad puede
# tener que darse de nuevo después de recompilar.
echo "▸ Firmando (ad-hoc)…"
codesign --force --deep --sign - "$APP" 2>&1 | grep -v "replacing existing signature" || true

echo "✅ Listo: $APP ($(lipo -archs "$BIN"))"
