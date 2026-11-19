# FIDOSims

Internal R&D app that runs FIDO2 (CTAP2) transactions directly against a FIDO NFC card and times
every APDU command–response. See [`docs/briefs/01-foundation.md`](docs/briefs/01-foundation.md).

## First-time setup

1. Install XcodeGen: `brew install xcodegen`
2. Copy the signing example and fill in your team and bundle ID prefix:
   `cp App/Config/Signing.local.xcconfig.example App/Config/Signing.local.xcconfig`
   (Optional for Simulator builds: without it the project uses `com.example` and no team.)
3. Generate the Xcode project: `cd App && xcodegen generate`
4. Open `FIDOSims.xcworkspace` (not the `.xcodeproj`). It contains the `FIDOSims` app and the `FIDOKit` package.

### Generated project

`App/FIDOSims.xcodeproj` is **gitignored**. `App/project.yml` is the only source of truth, which avoids
merge conflicts in `project.pbxproj`. Run `xcodegen generate` again after pulling changes to
`project.yml` or after adding/removing files in the app target.
