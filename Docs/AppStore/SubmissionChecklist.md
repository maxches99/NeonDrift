# MAS Submission Checklist

1. Open the project in Xcode and sign in with the Apple Developer account for the target team.
2. Set `TEAM_ID` in the build settings or replace `$(TEAM_ID)` in the export plist during CI/export.
3. Confirm the target uses `Config/AppStore/Info.plist`.
4. Confirm App Sandbox is enabled with `Config/AppStore/NeonDrift.entitlements`.
5. Attach `Assets/AppIcon.icns` or migrate the icon into an `.xcassets` catalog named `AppIcon`.
6. Archive with the `app-store` configuration and validate the archive in Organizer.
7. Paste the copy from `Docs/AppStore/StoreListing.md` into App Store Connect, preserving the wording `animated desktop overlay` or `live wallpaper effect`.
8. Paste `Docs/AppStore/AppReviewNotes.txt` into the App Review Notes field.
