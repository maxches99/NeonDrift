# NeonDrift — Agent Guide

Working directory: root of this repo.  
Single-file app: `Sources/NeonDrift/main.swift`.  
Metal shaders: `Sources/NeonDrift/Resources/`.  
Release metadata: `version.env`.

---

## Build & Run

```bash
# Instant dev loop — no .app bundle, runs in place
swift run NeonDrift

# Package + launch a local .app (ad-hoc signed)
./Scripts/compile_and_run.sh

# Package only (no launch)
./Scripts/package_app.sh release

# Universal binary (Apple Silicon + Intel)
ARCHES="arm64 x86_64" ./Scripts/package_app.sh release
```

The packaged app is written to `./NeonDrift.app`.

Build fails are almost always a Metal shader compile error or a Swift 6 concurrency issue — check the first error, not the cascade.

---

## Code Conventions

- **One file**: all Swift lives in `main.swift`. Do not split into multiple files unless the user explicitly asks.
- **Swift 6 strict concurrency**: every actor boundary crossing must be explicit. No `@preconcurrency` suppressions without a comment explaining why.
- **Metal shaders**: `.metal` files in `Resources/`. Keep shader uniforms in sync with the Swift-side structs — they are not checked at compile time.
- **No third-party dependencies**: SwiftPM `Package.swift` has no external packages; keep it that way.
- **Comments**: only when the _why_ is non-obvious. No MARK headers, no section banners.

---

## Commits

- Write commits in **English**, imperative mood, lowercase subject.
- Subject line ≤ 72 characters, no trailing period.
- Body only when the change needs context that the diff does not provide.
- No AI attribution lines (`Co-Authored-By`, generated-with footers, etc.).

```
fix crash when Metal device is nil on headless boot

The device lookup returns nil under some VM configurations; fall back
to a no-op renderer instead of force-unwrapping.
```

Commit types (no strict prefix required, but be consistent):
- `add` — new feature or shader
- `fix` — bug fix
- `remove` — deleted code or file
- `refactor` — internal restructure, no behavior change
- `release` — version bump commit (see below)

---

## Versioning

Version lives in `version.env`:

```env
MARKETING_VERSION=0.1.3   # user-visible (semver)
BUILD_NUMBER=4             # integer, increment on every release
```

Increment rules:
- **Patch** (`0.1.x`): bug fixes, shader tweaks, no new settings keys.
- **Minor** (`0.x.0`): new visual family, new settings key, behavioral change visible to the user.
- **Major** (`x.0.0`): breaking change to saved settings format or minimum macOS version bump.

---

## Release Process

1. Decide the new version (patch / minor / major).
2. Edit `version.env` — bump `MARKETING_VERSION` and `BUILD_NUMBER`.
3. Build and smoke-test locally:
   ```bash
   ./Scripts/compile_and_run.sh
   ```
4. Verify the About panel shows the correct version.
5. Commit the version bump:
   ```
   release 0.1.4
   ```
6. Tag the commit:
   ```bash
   git tag v0.1.4
   ```
7. Package the distributable zip:
   ```bash
   ./Scripts/package_app.sh release
   zip -r NeonDrift-0.1.4.zip NeonDrift.app
   ```
8. Push branch and tag:
   ```bash
   git push && git push --tags
   ```
9. Create a GitHub release against the tag; attach the zip. Use the same subject as the commit for the title.

For a **Mac App Store** build, run after step 6:
```bash
TEAM_ID=YOUR_TEAM_ID ./Scripts/archive_mas.sh
```
Then upload the resulting `build/AppStoreExport/*.pkg` via Transporter or Xcode Organizer.

---

## What Not to Touch

- `NeonDrift.xcodeproj/` — only needed for App Store archiving. Do not change project settings unless the task is specifically about the Xcode target.
- `Config/AppStore/` — entitlements and export options for MAS. Edit only for App Store-related tasks.
- `Assets/AppIcon.iconset/` — source icons. Regenerate `AppIcon.icns` via `iconutil` if icons change.
- `build/` — generated artefacts, never commit.
- `NeonDrift.app` — built app bundle at repo root, never commit (it is gitignored in spirit; verify `.gitignore` if unsure).

---

## Testing

There is no automated test suite. Verification is manual:

1. `./Scripts/compile_and_run.sh` — app launches, overlay appears on the desktop.
2. Switch Spaces — overlay follows correctly.
3. Open Settings panel — all controls respond, no crash.
4. Quit and relaunch — settings are restored.

For shader-only changes, `swift run NeonDrift` is faster than a full package build.
