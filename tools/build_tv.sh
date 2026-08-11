#!/usr/bin/env bash
#
# Builds the living-room packages of Sabuflix.
#
#   ./tools/build_tv.sh              # Tizen + webOS packages
#   ./tools/build_tv.sh android      # Android TV / Google TV APK as well
#
# Everything lands in dist/:
#
#   dist/sabuflix-tizen-webapp.zip   Samsung Tizen web app  (tizen package)
#   dist/sabuflix-webos-app.zip      LG webOS app           (ares-package)
#   dist/com.sabuflix.app_*.ipk      LG webOS installer, when ares-cli is present
#   dist/sabuflix-tv.apk             Android TV / Google TV, with `android`
#
# Samsung and LG both run the app as a packaged web application, so the Flutter
# web build is the payload for each; only the descriptor and the icons differ.
# Neither vendor's packaging tool is required to produce the zips — they are
# complete application source trees, ready to hand to Tizen Studio or ares-cli
# on a machine that has the signing certificate.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DIST="$ROOT/dist"
WEB_BUILD="$ROOT/build/web"
WITH_ANDROID="${1:-}"

log() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

log "Building Flutter web (the payload for both TV platforms)"
# --no-web-resources-cdn is the one that matters: by default the engine fetches
# CanvasKit from gstatic.com at startup, which a packaged TV app loading from
# file:// cannot do — the app would hang on a black screen with nothing in the
# logs. This bundles the renderer into the package instead.
#
# --pwa-strategy=none: a service worker cannot register from a file:// URL
# either, and its failure aborts the boot on webOS.
flutter build web --release --no-web-resources-cdn --pwa-strategy=none

# TV apps load from the local package, not from a server root, so every asset
# reference has to be relative. Flutter refuses a relative --base-href, so the
# tag is rewritten after the fact.
log "Rewriting <base href> for local (file://) loading"
sed -i.bak 's|<base href="/">|<base href="./">|' "$WEB_BUILD/index.html"
rm -f "$WEB_BUILD/index.html.bak"

mkdir -p "$DIST"

package_tv() {
  local name="$1"      # tizen | webos
  local target="$DIST/$name"

  log "Assembling the $name package"
  rm -rf "$target"
  mkdir -p "$target"
  cp -R "$WEB_BUILD/." "$target/"
  # The descriptor and the launcher art sit next to index.html.
  cp "$ROOT/tv/$name/"* "$target/"

  (cd "$target" && zip -qr "$DIST/sabuflix-$name-app.zip" .)
  echo "    dist/sabuflix-$name-app.zip"
}

package_tv tizen
package_tv webos
mv -f "$DIST/sabuflix-tizen-app.zip" "$DIST/sabuflix-tizen-webapp.zip"

# ares-cli can produce the real installer without a certificate, so use it when
# the machine has it. Tizen's packager always needs a signing profile, so that
# step stays manual — see docs/TV.md.
if command -v ares-package >/dev/null 2>&1; then
  log "Packaging the webOS .ipk with ares-cli"
  ares-package "$DIST/webos" -o "$DIST" >/dev/null
  ls "$DIST"/*.ipk
else
  echo
  echo "ares-cli not found — skipping the .ipk."
  echo "Install it with:  npm install -g @webos-tools/cli"
  echo "Then:             ares-package dist/webos -o dist"
fi

if [ "$WITH_ANDROID" = "android" ]; then
  log "Building the Android TV / Google TV APK"
  flutter build apk --release --no-tree-shake-icons
  cp build/app/outputs/flutter-apk/app-release.apk "$DIST/sabuflix-tv.apk"
  echo "    dist/sabuflix-tv.apk"
fi

log "Done"
ls -1 "$DIST"
