#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT/build/NeonDrift.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT/build/AppStoreExport}"
CONFIGURATION="${CONFIGURATION:-Release}"
TEAM_ID="${TEAM_ID:-}"
PROJECT_PATH="${PROJECT_PATH:-$ROOT/NeonDrift.xcodeproj}"
SCHEME="${SCHEME:-NeonDrift}"
EXPORT_OPTIONS_TEMPLATE="$ROOT/Config/AppStore/ExportOptions-AppStore.plist"
EXPORT_OPTIONS_PATH="$ROOT/build/ExportOptions-AppStore.plist"

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Missing Xcode project at $PROJECT_PATH"
  echo "Create or open an Xcode project/workspace for NeonDrift, then rerun this script."
  exit 1
fi

if [[ -z "$TEAM_ID" ]]; then
  echo "Set TEAM_ID before archiving for the Mac App Store."
  exit 1
fi

mkdir -p "$ROOT/build"
sed "s/\$(TEAM_ID)/$TEAM_ID/g" "$EXPORT_OPTIONS_TEMPLATE" > "$EXPORT_OPTIONS_PATH"

xcodebuild archive \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=macOS" \
  -allowProvisioningUpdates \
  TEAM_ID="$TEAM_ID"

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PATH" \
  -allowProvisioningUpdates

echo "Archive: $ARCHIVE_PATH"
echo "Export:  $EXPORT_PATH"
