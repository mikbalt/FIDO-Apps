# FIDOSims

Internal R&D app that runs FIDO2 (CTAP2) transactions directly against a FIDO NFC card and times
every APDU command–response. It does not use ASAuthorization or any platform passkey API.
See [`docs/briefs/README.md`](docs/briefs/README.md) for the plan and the briefs, and
[`docs/trace-format.md`](docs/trace-format.md) for the trace format. Status and open work:
[`docs/PROGRESS.md`](docs/PROGRESS.md) and the GitHub issues. Agents (and humans) start with
[`AGENTS.md`](AGENTS.md).

| Path | What |
|---|---|
| `App/` | iOS app (SwiftUI), generated from `App/project.yml` with XcodeGen |
| `FIDOKit/` | Swift package: `CardCore` (APDU, channel, traces), `CTAP` (CBOR, CTAP client, GetInfo), `PinUvAuth` (PIN protocol 2, ClientPIN), all pure Swift and macOS-testable, and `FIDOKit` (CoreNFC transport, `FIDOSimulator` facade, Keychain PIN store) |
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

`CardCoreTests` covers APDU encoding, the trace format (v1 and v2), metrics, the text export (pinned by golden
files), `MockTransport` and `ISO7816Channel`. `CTAPTests` covers CBOR, the CTAP client, GetInfo and the
Decoded view model. `PinUvAuthTests` covers PIN protocol 2 (NIST and RFC 4231 known answers) and ClientPIN.
`FIDOKitTests` runs the `FIDOSimulator` scenarios: diagnostics against the fixtures, and Set PIN, Change PIN
and Reset against `FakeAuthenticator`, a test-only card in `Tests/FIDOTestSupport` (not part of the app).
The NFC transport is compiled out on macOS (`#if os(iOS)`), so it is exercised only on a device.

Fixtures live in `FIDOKit/Tests/CardCoreTests/Fixtures/`:

- `synthetic/`: hand-written traces plus one written by the PC recorder's `--simulate` mode.
- `golden/`: expected text logs.
- `real/`: traces exported from real cards (added by Ikbal).

After changing fixtures, run `tools/sync-fixtures.sh` to update `App/FIDOSims/Resources/MockTraces/`.

## CI

`.github/workflows/ci.yml` runs on every pull request and on pushes to `main`, on a macOS runner, with no
secrets or signing. It shows up as three checks on the PR (or under the **Actions** tab):

- **SDK (swift test)**: `cd FIDOKit && swift build && swift test`.
- **App (iOS Simulator)** and **App (iOS device (unsigned))**: `xcodegen generate`, then the two `xcodebuild`
  builds from `AGENTS.md` (the device one with `CODE_SIGNING_ALLOWED=NO`).

Each job also fails on any `warning:` in its log except the `appintentsmetadataprocessor` note. To read a
failure, open the check, expand the failing step and look for `error:` (a build or test failure) or the
warning lines printed just before the "Warnings in project code" annotation. Reproduce locally with the
commands in [`AGENTS.md`](AGENTS.md).

## Mock run

1. In Xcode, pick the `FIDOSims` scheme and an iOS Simulator, then Run. The app opens on **Lab**; tap
   **Diagnostics**. The Simulator has no NFC, so the transport is forced to Mock.
2. Pick a fixture and tap **Run SELECT + GetInfo**. The tiles and exchange rows show the fixture's
   recorded numbers. For example, `fido2-getinfo-chained` shows Session total 1593.100 ms,
   Card wait 1500.000 ms, APDU total 91.000 ms, Host 2.100 ms and 5 exchanges.
3. Switch the display to **Decoded** for one line per command, the GetInfo table and the CBOR of each
   command. `getinfo-full` has every GetInfo field brief 02 types, plus an unknown key (`0x30`).
4. Turn on **Replay in real time** to replay with the recorded delays. This lets you watch the live
   counter and try **Cancel**.
5. **Export** in the toolbar shares the trace as JSON or as the text log. Sensitive exchanges are always
   redacted. The last 10 runs are kept in memory under History.

A JSON exported from the phone can be added to `Fixtures/real/` and replayed the same way.

## NFC run (device)

Requires a signed build (see setup) on an iPhone with NFC. Choose **NFC** and tap Run. When the system
sheet appears, hold the card near the top of the iPhone. The app runs `SELECT_FIDO` and `GET_INFO`.

**Change PIN**, **Set PIN** and **Reset** (under Lab) need NFC and a real card; there is no mock for them.
The PIN can be the UI default `1234`, a custom one, or the one stored for that card label ("Store PIN"
keeps it in the Keychain, this device only). Reset is enabled only after you type the card label again,
and must reach the card within about 10 s of the tap. Use a spare card for reset and wrong-PIN tests, and
never run PIN retries down to 0 on a card you cannot reset.

## PC baseline recorder

See [`tools/pc-baseline/README.md`](tools/pc-baseline/README.md):

```sh
python3 tools/pc-baseline/record_trace.py --reader 0 --label "Lab card A" --runs 10 --length-form short --out traces/
```
