# AGENTS.md — working on FIDOSims

Instructions for any coding agent (and human) working in this repo. Read this first, then
[`docs/PROGRESS.md`](docs/PROGRESS.md) for where things stand and
[`docs/briefs/README.md`](docs/briefs/README.md) for the plan.

## What this is

FIDOSims is an internal iOS R&D app that runs FIDO2 (CTAP2) **directly** against a FIDO NFC card and
times every APDU command–response. It does not use ASAuthorization or any platform passkey API.
Owner: Mokhamad Ikbal Taqyudin ("Ikbal"). The briefs in `docs/briefs/` are the specification.

| Path | What |
|---|---|
| `App/` | iOS app (SwiftUI). `App/project.yml` is the source of truth; the `.xcodeproj` is generated and gitignored |
| `App/FIDOSims/Features/Lab/` | Engineering screens (until the final UI): Diagnostics, Change PIN, Set PIN, Reset |
| `FIDOKit/Sources/CardCore` | APDU, ISO 7816 channel, transport contract, traces, `MockTransport`. Pure Swift |
| `FIDOKit/Sources/CTAP` | Canonical CBOR, `CTAPClient`, GetInfo model, Decoded-view decoder. Pure Swift |
| `FIDOKit/Sources/PinUvAuth` | PIN/UV auth protocol 2 (CryptoKit + CommonCrypto), authenticatorClientPIN |
| `FIDOKit/Sources/FIDOKit` | CoreNFC transport (iOS only), the `FIDOSimulator` facade, Keychain PIN store |
| `App/FIDOSimsTests/` | App unit tests for the Lab view models (compiles `FakeAuthenticator` in; never shipped in the app) |
| `FIDOKit/Tests/FIDOTestSupport` | **Test-only** `FakeAuthenticator` (a ClientPIN card in memory). Never ship it |
| `tools/pc-baseline/` | Python PC/SC recorder (optional, brief 01 T7) |
| `docs/trace-format.md` | The trace format contract (schema v2, reads v1) |

## Commands

```sh
# SDK: build and test on macOS (must pass before every commit)
cd FIDOKit && swift build && swift test

# App: regenerate the project after adding/removing app files or editing project.yml
cd App && xcodegen generate

# App builds (both must succeed with no warnings in project code)
xcodebuild -workspace FIDOSims.xcworkspace -scheme FIDOSims \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/fidosims-dd build
xcodebuild -workspace FIDOSims.xcworkspace -scheme FIDOSims \
  -destination 'generic/platform=iOS' -derivedDataPath /tmp/fidosims-dd CODE_SIGNING_ALLOWED=NO build

# App tests (Lab view models; Swift Testing, no NFC)
xcodebuild -project App/FIDOSims.xcodeproj -scheme FIDOSims \
  -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/fidosims-dd test

# After changing fixtures in FIDOKit/Tests/CardCoreTests/Fixtures/synthetic
tools/sync-fixtures.sh
```

The only expected warning is Xcode's `appintentsmetadataprocessor` note; anything else is a defect.

## Ground rules (brief 01 §2, apply to every brief)

- **Swift 6** language mode, strict concurrency. `@preconcurrency import CoreNFC` is allowed.
  `@unchecked Sendable` only inside the NFC transport, with a comment explaining the invariant.
- **No third-party Swift dependencies.**
- **SwiftUI + MVVM** with `@Observable` view models. **One type per file**, feature folders, reusable
  views in `Components/`. Logic lives in the SDK facade and view models, so the final UI only replaces Views.
- **SDK has no UI.** Anything that does not need CoreNFC builds and tests on macOS. Wrap CoreNFC in `#if os(iOS)`.
- **Secrets** (PINs, shared secrets, tokens) never appear in logs, traces or exports. PIN-carrying exchanges
  are flagged `sensitive`; exports always redact them. Secret types print as `<redacted>`.
- **Signing:** never hard-code `DEVELOPMENT_TEAM` or a real bundle prefix. The owner sets them in
  `App/Config/Signing.local.xcconfig` (gitignored). Build checks use `CODE_SIGNING_ALLOWED=NO`.
- **Tests** use Swift Testing (`import Testing`), not XCTest.
- **Keep it lean.** Build what the brief asks for and nothing more. If something extra seems necessary, ask first.

## Contracts — stop and ask before changing

Owned by Ikbal. Implement them as written; if one must change, stop and ask.

| Contract | Where |
|---|---|
| `CardTransport` API | brief 01 T3, `CardCore/Transport` |
| Trace format and metrics | `docs/trace-format.md` (brief 01, small additions in 02) |
| `FIDOSimulator` facade, `ScenarioStep`, `ScenarioResult` | brief 02 T6, `FIDOKit/Simulator` |
| `StoredCredential` / `CredentialStore` | brief 03 T5 |

Also stop and ask if: a third-party dependency seems necessary; XcodeGen is unavailable; signing needs
values that are not in the brief; GetInfo shows a U2F-only card or no PIN protocol 2.

## Decisions already made (do not re-litigate)

- `sessionEnded.reason` is a closed enum mapped 1:1 from `CardError`; decoders keep unknown values as `.unknown(raw)`.
- Redacted JSON exchanges: `"tx": null, "rx": null, "txLength", "rxLength", "redacted": true`. The
  `<redacted N bytes>` placeholder is only for the text log and the Safe view. `MockTransport` refuses redacted traces.
- `sessionTotal` ends at the last exchange (not `sessionEnded`). It is the assumed "transaction total" until the BU decides.
- GET RESPONSE (`00 C0 00 00 xx`) and NFCCTAP_GETRESPONSE (`80 11 00 00 00`) are always short form.
  `EXTENDED_FORM_CHAINED` is warned when the card answers an extended-form command with `61xx`.
- NFCCTAP_MSG P1 stays `00` (brief 02): on NFC the tap is user presence.
- Trace v2 is small: `scenario`, `outcome`, `card.aaguid/versions/firmwareVersion`, `exchange.ctapStatus`,
  `warning`. Metrics are the brief 01 ones.
- A wrong PIN / CTAP refusal ends the session `completed` with a failed `outcome`.
- When a History trace is shown, the status row says "History · <time>" with "Back to latest";
  numbers on screen are never ambiguous about which run they belong to.
- PIN and Reset screens need NFC; there is no mock for them. The default PIN `1234` is a UI default only.

## Workflow

1. **One brief at a time, in order.** Do not start the next brief until Ikbal signs off the current one's
   "Verified by Ikbal on device" checklist (tracked as a `needs-device` issue).
2. **Git:** one branch per brief, `brief/0N-<name>`, cut from `main`; **one commit per task**, message
   `T<n>: <what>`, ending with the `Co-Authored-By` line. Merge to `main` when the owner asks (fast-forward).
   Small non-brief work (an `agent-ready` issue) uses `issue/<number>-<slug>` and references the issue.
3. **Before each commit:** `swift test` passes; if the app changed, both app builds pass with no warnings.
4. **UI changes:** verify in the Simulator with the `sim-verifier` agent (it uses the
   `xcode-integration:device-interaction` skill). Real-card behaviour is verified only by Ikbal.
5. **At the end:** update `docs/PROGRESS.md`, close or update GitHub issues, and post the summary:
   what changed, decisions made, open questions.

## Delegation: skills and agents

Project skills (`.claude/skills/`) and subagents (`.claude/agents/`):

| Use | When |
|---|---|
| `/implement-brief <brief> [task]` skill | Implement a brief or one of its tasks with the workflow above |
| `/verify-changes` skill | Run every check (tests, project generation, both app builds, warning scan) |
| `/report-progress` skill | Update `docs/PROGRESS.md` and the GitHub issues, and draft the summary |
| `brief-implementer` agent | Delegate one task or one `agent-ready` issue end to end |
| `fido-reviewer` agent | Read-only review of a diff against the contracts, ground rules and decisions |
| `sim-verifier` agent | Drive the Simulator and confirm a UI change works (no rebuilds of its own) |

Useful Xcode skills: `xcode-integration:device-interaction` (Simulator checks),
`xcode-integration:swiftui-specialist` (SwiftUI best practice), `xcode-integration:modernize-tests`.

## Testing approach

- Unit tests cover everything that does not need a card: APDU, chaining, CBOR, parsing, crypto
  (with NIST / RFC known answers), scenarios against `MockTransport` fixtures and `FakeAuthenticator`.
- Fixtures: `FIDOKit/Tests/CardCoreTests/Fixtures/synthetic/` (hand-written or tool-generated, never
  claimed to be real), `golden/` (expected text logs), `real/` (added only by Ikbal after IT/security approval).
- **The real card is the reference.** A feature is done when Ikbal has checked it on the IDEMIA card.
