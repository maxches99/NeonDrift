# NeonDrift

NeonDrift is a macOS live wallpaper app that renders animated desktop overlays with Metal.

Instead of replacing the wallpaper selected in System Settings, NeonDrift creates a borderless, non-interactive window at the desktop layer for each display. The result is a live wallpaper effect that stays behind desktop icons and regular app windows.

## Highlights

- Metal-powered animated desktop overlay for macOS
- Multiple visual families: plasma, fractals, patterns, and atmospheric themes
- Per-display configuration with global defaults
- Launch at login support
- Optional background mode with a status bar control surface
- Export and import for settings
- Diagnostics and renderer status inside the app

## Requirements

- macOS 14 or later
- Apple Silicon or Intel Mac with Metal support
- Xcode 16+ or Swift 6 toolchain for local builds

## Project Layout

- `Sources/NeonDrift/main.swift` contains the app, settings UI, and desktop overlay management
- `Sources/NeonDrift/Resources/` contains the Metal shader sources
- `Scripts/package_app.sh` builds and assembles a distributable `.app`
- `Scripts/compile_and_run.sh` packages and launches the app for local development
- `Scripts/archive_mas.sh` archives the Xcode project for Mac App Store export
- `version.env` stores the app name, bundle id, and release version metadata

## Local Development

Build and run from SwiftPM:

```bash
swift run NeonDrift
```

Package and launch a local app bundle:

```bash
./Scripts/compile_and_run.sh
```

Create a release app bundle without launching it:

```bash
./Scripts/package_app.sh release
```

The packaged app is created at `./NeonDrift.app`.

## Release Packaging

The current release metadata lives in `version.env`:

```env
APP_NAME=NeonDrift
BUNDLE_ID=com.maxches.wallpaper.neon-drift
MARKETING_VERSION=0.1.0
BUILD_NUMBER=1
MACOS_MIN_VERSION=14.0
```

To create the local release build:

```bash
./Scripts/package_app.sh release
```

To prepare a Mac App Store archive from the Xcode project:

```bash
TEAM_ID=YOUR_TEAM_ID ./Scripts/archive_mas.sh
```

Supporting App Store metadata and review notes live in `Docs/AppStore/`.

## Notes

- NeonDrift does not modify the system wallpaper preference.
- The live effect is created entirely through desktop-layer windows and Metal rendering.
- No screen recording, accessibility permission, or input monitoring is required for the wallpaper effect.
