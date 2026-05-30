#!/usr/bin/env bash
set -euo pipefail

CONF=${1:-release}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

source "$ROOT/version.env"

HOST_ARCH=$(uname -m)
ARCH_LIST=( ${ARCHES:-$HOST_ARCH} )

for ARCH in "${ARCH_LIST[@]}"; do
  swift build -c "$CONF" --arch "$ARCH"
done

APP="$ROOT/${APP_NAME}.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

ICON_SOURCE="$ROOT/Assets/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${MARKETING_VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key><string>${MACOS_MIN_VERSION}</string>
</dict>
</plist>
PLIST

build_product_path() {
  local name="$1"
  local arch="$2"
  echo ".build/${arch}-apple-macosx/$CONF/$name"
}

if [[ ${#ARCH_LIST[@]} -gt 1 ]]; then
  BINARIES=()
  for ARCH in "${ARCH_LIST[@]}"; do
    BINARIES+=("$(build_product_path "$APP_NAME" "$ARCH")")
  done
  lipo -create "${BINARIES[@]}" -output "$APP/Contents/MacOS/$APP_NAME"
else
  cp "$(build_product_path "$APP_NAME" "${ARCH_LIST[0]}")" "$APP/Contents/MacOS/$APP_NAME"
fi
chmod +x "$APP/Contents/MacOS/$APP_NAME"

BUILD_DIR=$(dirname "$(build_product_path "$APP_NAME" "${ARCH_LIST[0]}")")
shopt -s nullglob
for bundle in "$BUILD_DIR"/"$APP_NAME".bundle "$BUILD_DIR"/"$APP_NAME"_*.bundle; do
  [[ -d "$bundle" ]] || continue
  cp -R "$bundle" "$APP/Contents/Resources/"
done
shopt -u nullglob

if [[ -f "$ICON_SOURCE" ]]; then
  cp "$ICON_SOURCE" "$APP/Contents/Resources/AppIcon.icns"
fi

xattr -cr "$APP"
codesign --force --sign - "$APP"

echo "Created $APP"
