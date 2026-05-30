#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
source "$ROOT/version.env"

pkill -x "$APP_NAME" 2>/dev/null || true
# Local dev path: fast ad-hoc package build outside the Mac App Store flow.
SIGNING_MODE=adhoc "$ROOT/Scripts/package_app.sh" release
open "$ROOT/${APP_NAME}.app"
