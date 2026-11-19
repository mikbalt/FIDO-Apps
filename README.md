# FIDOSims

Internal R&D app that runs FIDO2 (CTAP2) transactions directly against a FIDO NFC card and times
every APDU command–response. It does not use ASAuthorization or any platform passkey API.
See [`docs/briefs/01-foundation.md`](docs/briefs/01-foundation.md) and
[`docs/trace-format.md`](docs/trace-format.md).

| Path | What |
|---|---|
| `App/` | iOS app (SwiftUI), generated from `App/project.yml` with XcodeGen |
| `FIDOKit/` | Swift package: `CardCore` (pure Swift, macOS-testable) and `FIDOKit` (CoreNFC transport, diagnostics) |
| `tools/pc-baseline/` | Python PC/SC recorder that writes the same trace format |
| `tools/sync-fixtures.sh` | Copies test fixtures into the app's mock traces |

## First-time setup

1. Install XcodeGen: `brew install xcodegen`
2. Copy the signing example and fill in your team and bundle ID prefix:
   `cp App/Config/Signing.local.xcconfig.example App/Config/Signing.local.xcconfig`
   You can skip this for Simulator builds: without it, the project uses `com.example` and no team.
   NFC on a device needs a paid team, because the NFC Tag Reading capability is not available to personal teams.
3. Generate the Xcode project: `cd App && xcodegen generate`
4. Open `FIDOSims.xcworkspace` (not the `.xcodeproj`). It shows the `FIDOSims` and `FIDOKit` schemes.

### Generated project

`App/FIDOSims.xcodeproj` is **gitignored**. `App/project.yml` is the only source of truth, which avoids
merge conflicts in `project.pbxproj`. Run `xcodegen generate` again after pulling changes to
`project.yml`, or after adding or removing files in the app target.

## Tests

```sh
cd FIDOKit && swift build && swift test
```

`CardCoreTests` covers APDU encoding, the trace format, metrics, the text export (pinned by golden files),
`MockTransport` and `ISO7816Channel`. `FIDOKitTests` runs the diagnostics scenario against the fixtures.
The NFC transport is compiled out on macOS (`#if os(iOS)`), so it is exercised only on a device.

Fixtures live in `FIDOKit/Tests/CardCoreTests/Fixtures/`:

- `synthetic/`: hand-written traces plus one written by the PC recorder's `--simulate` mode.
- `golden/`: expected text logs.
- `real/`: traces exported from real cards (added by Ikbal).

After changing fixtures, run `tools/sync-fixtures.sh` to update `App/FIDOSims/Resources/MockTraces/`.

## Mock run

1. In Xcode, pick the `FIDOSims` scheme and an iOS Simulator, then Run. The Simulator has no NFC, so
   the transport is forced to Mock.
2. Pick a fixture and tap **Run SELECT + GetInfo**. The tiles and exchange rows show the fixture's
   recorded numbers. For example, `fido2-getinfo-chained` shows Session total 1593.100 ms,
   Card wait 1500.000 ms, APDU total 91.000 ms, Host 2.100 ms and 5 exchanges.
3. Turn on **Replay in real time** to replay with the recorded delays. This lets you watch the live
   counter and try **Cancel**.
4. **Export** in the toolbar shares the trace as JSON or as the text log. Sensitive exchanges are always
   redacted. The last 10 runs are kept in memory under History.

A JSON exported from the phone can be added to `Fixtures/real/` and replayed the same way.

## NFC run (device)

Requires a signed build (see setup) on an iPhone with NFC. Choose **NFC** and tap Run. When the system
sheet appears, hold the card near the top of the iPhone. The app runs `SELECT_FIDO` and `GET_INFO`.

## PC baseline recorder

See [`tools/pc-baseline/README.md`](tools/pc-baseline/README.md):

```sh
python3 tools/pc-baseline/record_trace.py --reader 0 --label "Lab card A" --runs 10 --length-form short --out traces/
```
