#!/bin/bash
# build.sh — compila e installa l'app KeepAwake.app (icona in barra dei menu).
#
# L'app mostra un fulmine ⚡️ in barra SOLO quando KeepAwake e' attivo
# (SleepDisabled = 1), cosi' non ci si dimentica di spegnerlo.
#
# Perche' un bundle .app e non un binario nudo: su macOS 26 (Tahoe) un
# NSStatusItem creato da un eseguibile non impaginato come .app viene
# piazzato fuori schermo (screen=nil) e non appare mai. Inoltre su Tahoe
# va usata l'API moderna MenuBarExtra (SwiftUI), non NSStatusItem.

set -eu

QUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$HOME/Applications/KeepAwake.app"
BIN="$HOME/Library/Application Support/keepawake-menubar"

if ! command -v swiftc >/dev/null 2>&1; then
  echo "serve swiftc (Xcode Command Line Tools): xcode-select --install" >&2
  exit 1
fi

echo "compilo MenuBarExtra.swift..."
mkdir -p "$BIN"
swiftc -O -parse-as-library -o "$BIN/keepawake-menubar" "$QUI/MenuBarExtra.swift"

echo "creo il bundle $APP..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN/keepawake-menubar" "$APP/Contents/MacOS/keepawake-menubar"
chmod +x "$APP/Contents/MacOS/keepawake-menubar"
cp "$QUI/Info.plist" "$APP/Contents/Info.plist"

echo "firmo ad-hoc..."
/usr/bin/codesign -s - --deep --force "$APP" >/dev/null 2>&1 || true

echo "avvio..."
open "$APP"

cat <<'EOF'

Fatto. Per l'avvio automatico al login:
  Impostazioni di Sistema > Generali > Elementi login > + > KeepAwake.app

Nota macOS 26 (Tahoe): la prima volta puo' servire abilitare l'app in
  Impostazioni di Sistema > Barra dei Menu (nuovo controllo privacy).
EOF
