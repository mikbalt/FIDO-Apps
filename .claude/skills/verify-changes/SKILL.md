---
name: verify-changes
description: Run every FIDOSims check before a commit or merge - swift test for FIDOKit, xcodegen project generation, the iOS Simulator and generic-device (unsigned) app builds, and a scan for warnings in project code. Use after code changes, before committing, or when asked "is everything green?".
---

# Verify changes

Run from the repo root and report each step as pass/fail with the relevant output.

1. **SDK tests**
   ```sh
   cd FIDOKit && swift build --build-tests 2>&1 | grep -E "warning:|error:" ; swift test 2>&1 | grep -E "error:|✘|Test run"
   ```
   Every `Test run` line must say `passed`. Any `warning:` from project sources is a defect.

2. **Fixtures in sync** (only if `FIDOKit/Tests/CardCoreTests/Fixtures/synthetic` changed):
   `tools/sync-fixtures.sh`, then confirm `git status` shows the copies under `App/FIDOSims/Resources/MockTraces`.

3. **Project generation** (if app files were added/removed or `App/project.yml` changed):
   `cd App && xcodegen generate`.

4. **App builds**
   ```sh
   xcodebuild -workspace FIDOSims.xcworkspace -scheme FIDOSims -destination 'generic/platform=iOS Simulator' \
     -derivedDataPath /tmp/fidosims-dd build 2>&1 | grep -E "error:|warning:|BUILD" | sort -u
   xcodebuild -workspace FIDOSims.xcworkspace -scheme FIDOSims -destination 'generic/platform=iOS' \
     -derivedDataPath /tmp/fidosims-dd CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|warning:|BUILD" | sort -u
   ```
   Both must print `BUILD SUCCEEDED`. The only accepted warning is `appintentsmetadataprocessor`.
   Never add signing values to make a build pass.

5. **Secrets scan** of the diff: no PINs, tokens, team IDs or real card data in code, fixtures or docs
   (`git diff main --stat` and inspect new fixtures).

Summarise: tests passed (count), builds, warnings, anything that needs attention.
