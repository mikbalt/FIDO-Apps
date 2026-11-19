# Brief 01 — Foundation: workspace, CardCore, NFC spike

| | |
|---|---|
| Project | FIDOSims — FIDO simulator app (iOS first, Android later) |
| Owner | Mokhamad Ikbal Taqyudin |
| Status | Ready for implementation |
| Depends on | Nothing. Uses synthetic fixtures; real card traces are added later. |
| Next | Brief 02 — CBOR / CTAP layer, GetInfo decoding |

## 1. Context

FIDOSims is an internal R&D test app. It runs FIDO2 (CTAP2) transactions **directly** against a FIDO NFC card and measures the elapsed time of every APDU command–response, plus the totals. The app plays both the WebAuthn client and a local relying party. It does **not** use ASAuthorization or any platform passkey API, because those hide the individual APDUs we need to time.

This brief covers only the foundation: the repo and workspace; the APDU layer; the NFC transport; timing traces; a diagnostics screen that runs SELECT + authenticatorGetInfo against a real card.

CTAP/CBOR, PIN, MakeCredential and the final UI come in later briefs.

## 2. Ground rules

- **Swift and concurrency.** Swift 6 language mode with strict concurrency. `@preconcurrency import CoreNFC` is allowed. `@unchecked Sendable` is allowed only inside the NFC transport, with a comment explaining the invariant.
- **Dependencies.** No third-party Swift dependencies.
- **App structure.** SwiftUI + MVVM with `@Observable` view models. One type per file, feature folders, and reusable views in `Components/`.
- **SDK boundaries.** SDK code has no UI. Anything that does not need CoreNFC lives in `CardCore` and must build and test on macOS (`swift test`).
- **Contracts.** Items marked **[CONTRACT]** are owned by Ikbal: the transport API, the trace format and the timing metrics. Implement them as written. If you believe one must change, stop and ask.
- **Secrets.** Never write secrets in plaintext to logs or exports. Exchanges can be flagged `sensitive`; this is required from brief 02 on, for ClientPIN.
- **Commits and reporting.** Make small commits, one per task. At the end, post a short summary: what changed, the decisions you made, and any open questions.

**Stop and ask if:** a contract needs to change; a third-party dependency seems necessary; XcodeGen is unavailable; signing needs values that are not in this brief.

## 3. Repository layout

```
fido-sims/
├── FIDOSims.xcworkspace
├── App/
│   ├── project.yml                          # XcodeGen spec: source of truth for the .xcodeproj
│   ├── Config/
│   │   ├── Base.xcconfig
│   │   └── Signing.local.xcconfig.example   # DEVELOPMENT_TEAM, BUNDLE_ID_PREFIX (real file is gitignored)
│   └── FIDOSims/
│       ├── App/                             # FIDOSimsApp.swift, AppContainer.swift
│       ├── Features/Diagnostics/            # DiagnosticsView.swift, DiagnosticsViewModel.swift
│       ├── Components/                      # MetricTileView, ExchangeRowView, TraceListView, ...
│       ├── Resources/                       # Assets, MockTraces/*.json
│       ├── Info.plist
│       └── FIDOSims.entitlements
├── FIDOKit/                                 # Swift Package (SDK)
│   ├── Package.swift
│   ├── Sources/
│   │   ├── CardCore/                        # pure Swift: APDU/, Channel/, Transport/, Trace/, Mock/
│   │   └── FIDOKit/                         # NFC/NFCCardTransport.swift, Diagnostics/, Exports.swift
│   └── Tests/
│       ├── CardCoreTests/                   # + Fixtures/synthetic/, Fixtures/real/
│       └── FIDOKitTests/
├── tools/pc-baseline/                       # record_trace.py, requirements.txt, README.md
└── docs/
    ├── briefs/01-foundation.md              # this file
    └── trace-format.md
```

## 4. Tasks

### T1 — Repo and workspace skeleton

**`FIDOKit/Package.swift`**: tools version 6.0; platforms `.iOS(.v17)` and `.macOS(.v14)`. Targets `CardCore`, and `FIDOKit` (depends on `CardCore`, re-exports it with `@_exported import CardCore`). Test targets `CardCoreTests` (with `Fixtures` as resources) and `FIDOKitTests`. Product: library `FIDOKit`. Wrap every use of CoreNFC in `#if os(iOS)`.

**App project**, generated from `App/project.yml` with XcodeGen: iOS 17+; depends on the local package `../FIDOKit`; bundle ID `$(BUNDLE_ID_PREFIX).fidosims`, signing values from `Signing.local.xcconfig`. `Info.plist`: `NFCReaderUsageDescription`; `com.apple.developer.nfc.readersession.iso7816.select-identifiers` = [`A0000006472F0001`]. Entitlements: `com.apple.developer.nfc.readersession.formats` = [`TAG`].

**Workspace and repo**: `FIDOSims.xcworkspace` opens both the app project and the package. `.gitignore` covers Xcode, SwiftPM, Python and `Signing.local.xcconfig`. Decide whether the generated `.xcodeproj` is committed or gitignored, and document the choice.

Acceptance:

- [ ] After `xcodegen generate`, opening the workspace shows schemes `FIDOSims` and `FIDOKit`, and both build for the iOS Simulator.
- [ ] `cd FIDOKit && swift build && swift test` succeeds on macOS.
- [ ] The README explains first-time setup: install XcodeGen, copy the signing example, generate, open the workspace.

### T2 — APDU model (`CardCore/APDU`)

- `CommandAPDU` has the fields `cla`, `ins`, `p1`, `p2`, `data` and `le: Int?`. `nil` means Le is absent; otherwise the range is 1…65536.
- `encoded(_ form: LengthForm) throws -> Data` supports `.short` and `.extended`, covering ISO 7816-4 cases 1–4 in both forms: short Le 256 → `00`; extended case 2 `00 Le1 Le2`; extended cases 3 and 4 `00 Lc1 Lc2 data [Le1 Le2]`; extended Le 65536 → `00 00`.
- `ResponseAPDU` holds `data` and `sw`, parsed from raw bytes (at least 2 bytes).
- `StatusWord` helpers: `sw1`, `sw2`, `isSuccess` (9000); display names for 9000, 61xx, 6Cxx, 6700, 6985, 6A80, 6A82, 6D00, 6E00 and 9100.
- A `Hex` utility that parses and formats hex with spaces, e.g. `00 A4 04 00`.

Acceptance (unit tests):

- [ ] All 4 cases encode to the expected bytes in both forms, including the boundaries: Lc 255 short OK, Lc 256 short throws; Le 256 short → `00`; Le 65536 extended → `00 00`; data longer than 65535 bytes throws.
- [ ] Response parsing rejects input shorter than 2 bytes, and the SW helpers are correct.

### T3 — Transport contract, trace, mock (`CardCore/Transport`, `Trace`, `Mock`)

**[CONTRACT] Transport**

```swift
public enum TransportKind: String, Codable, Sendable { case nfc, mock, pcsc }

public struct CardConnection: Sendable {
    public let sessionStartedAt: ContinuousClock.Instant
    public let cardDetectedAt: ContinuousClock.Instant
    public let initialSelectedAID: Data?          // what the OS already selected during discovery
}

public struct RawExchange: Sendable {
    public let command: Data                      // exact bytes sent
    public let response: ResponseAPDU
    public let startedAt: ContinuousClock.Instant // taken immediately before the I/O call
    public let endedAt: ContinuousClock.Instant   // taken immediately after it returns
}

public protocol CardTransport: AnyObject, Sendable {
    var kind: TransportKind { get }
    /// Starts a session and suspends until a card is connected.
    func open(prompt: String) async throws -> CardConnection
    /// Sends exactly one physical APDU. No chaining here.
    func transmit(_ command: Data) async throws -> RawExchange
    func close(errorMessage: String?) async
}
```

The transport itself takes the timestamps, as close to the hardware call as possible, so actor hops and decorators never end up inside an RTT.

**[CONTRACT] Trace format** — see `docs/trace-format.md`. `TraceRecorder` builds a `Trace` from a `CardConnection` plus `RawExchange`s and must be concurrency-safe.

**[CONTRACT] Metrics** (provisional, pending the BU's answer):

| Metric | Definition |
|---|---|
| `cardWait` | `cardDetected − sessionStarted` |
| `apduTotal` | Σ (`tEnd − tStart`) over all exchanges |
| `sessionTotal` | `tEnd` of the last exchange − `sessionStarted` (includes waiting for the card) |
| `hostOverhead` | `sessionTotal − cardWait − apduTotal` |
| Per logical command | Σ RTT of its physical exchanges, plus the exchange count |

Display values in milliseconds with 3 decimals, e.g. `12.400 ms`.

**Exports**: JSON is the trace itself, `redactSensitive` defaults to true. The text log must match the golden format (see `docs/trace-format.md`). In Safe mode and in redacted exports, the data of a sensitive exchange is rendered as `<redacted N bytes>`.

**MockTransport**: built from a trace JSON fixture; replays `rx`/`sw` for each expected `tx`, in order; reports the recorded durations without sleeping, unless `realtime: true`; strict — a mismatching `tx` fails with an error showing the expected and actual bytes.

Acceptance:

- [ ] JSON round-trip: `decode(encode(trace)) == trace`, and all synthetic fixtures decode.
- [ ] Metrics are correct for a fixture with known numbers.
- [ ] The text export matches a golden file, and redaction works.
- [ ] MockTransport replays a fixture and fails clearly on a mismatch.

### T4 — ISO 7816 channel (`CardCore/Channel`)

`ISO7816Channel` sits on top of a `CardTransport` and a `TraceRecorder` and sends one **logical** command, which may turn into several physical exchanges:

```swift
public func send(_ command: CommandAPDU, label: String, sensitive: Bool = false) async throws -> ResponseAPDU
```

1. Encoding form from `ChannelOptions.lengthForm` (`.short` default).
2. Short-form command chaining for data > 255 bytes: chunks ≤ 255; `CLA | 0x10` on all but the last; intermediate responses must be `9000`; only the last chunk carries Le.
3. `61xx`: send `00 C0 00 00 xx` (`00` = 256), append data, repeat.
4. `6Cxx`: resend once with Le = `xx`.
5. `9100` NFCCTAP status update (`01` PROCESSING, `02` UPNEEDED): poll `80 11 00 00 00`; poll interval configurable (default 0), timeout default 30 s; expose status updates.
6. Task cancellation stops between exchanges and throws `CancellationError`; completed exchanges stay in the trace.
7. Every physical exchange is recorded under the same `commandIndex` and `label`.

Helpers: `selectFIDO()` (sends `00 A4 04 00 08 A0 00 00 06 47 2F 00 01 00`, returns `U2F_V2` / `FIDO_2_0`); `nfcctapMsg(_ payload:)` (CLA `80`, INS `10`, P1 `80` if `getResponseSupported` else `00`, P2 `00`, max Le for the form).

Acceptance (unit tests with MockTransport):

- [ ] Three `61xx` responses: data concatenated in order, 4 exchanges under one command.
- [ ] `61 00` triggers GET RESPONSE with Le `00`.
- [ ] `6Cxx` triggers exactly one resend with the corrected Le.
- [ ] A 600-byte payload in short form → 3 chunks with CLA `90`, `90`, `80`; a non-9000 intermediate response throws.
- [ ] `9100` twice, then `9000`: exactly 2 polls. Endless `9100` → timeout error.
- [ ] Cancelling mid-chain throws `CancellationError`; the trace keeps completed exchanges.

### T5 — NFC transport and diagnostics scenario (`FIDOKit`)

`NFCCardTransport` (iOS only): `NFCTagReaderSession(pollingOption: .iso14443)`; first `.iso7816` tag; `cardDetectedAt` after connect; store `initialSelectedAID`; several tags → alert and restart polling. Transmit with `NFCISO7816APDU(data:)` (`nil` → `CardError.invalidAPDU`) and `sendCommand(apdu:)`, timestamps right around the call. Map invalidation to `CardError` (`.userCancelled`, `.sessionTimeout`, `.tagConnectionLost`, `.nfcUnavailable`, `.underlying(Error)`). Alert messages: "Hold the card near the top of the iPhone", "Reading…", "Done". `isAvailable` = `NFCTagReaderSession.readingAvailable`.

`FIDODiagnostics.runSelectAndGetInfo(transport:options:) async throws -> Trace`: open → `SELECT_FIDO` → `GET_INFO` (`nfcctapMsg([0x04])`) → close. If SELECT does not return 9000 with a known version, record it and stop (trace still returned). GetInfo: first byte CTAP status, rest raw CBOR (decoded in brief 02). `6D00` is recorded as "CTAP1-only card". Options: `lengthForm`, `getResponseSupported`, `cardLabel`.

Acceptance:

- [ ] FIDOKitTests run diagnostics against MockTransport fixtures for (a) `FIDO_2_0` with a `61xx` chain on GetInfo; (b) `U2F_V2`-only returning `6D00`; (c) SELECT failure `6A82`.
- [ ] The package still builds on macOS, with the NFC code compiled out.

### T6 — Diagnostics screen (App)

Temporary engineering screen that will grow into "Logs and timing"; build its parts as reusable components. Controls: transport NFC/Mock (Mock forced in the Simulator or when NFC is unavailable); mock fixture picker; length form; card label; Run and Cancel. While running: state (waiting for card, exchanging, done, failed) and a live elapsed-time counter. Result: metric tiles (Session total, Card wait, APDU total, Host overhead, Exchanges); exchange list (index, label, RTT, TX/RX hex, SW); Hex / Safe toggle. Export JSON and text through `ShareLink`; keep the last 10 traces in memory. `AppContainer` builds the transports; the ViewModel depends only on `CardTransport`.

Acceptance:

- [ ] In the Simulator, Mock runs every fixture end to end, and the numbers on screen match the fixture.
- [ ] The app builds for a generic iOS device, with the NFC entitlement and Info.plist keys present.

### T7 — PC baseline recorder (`tools/pc-baseline`)

Python 3.10+, `pyscard` only. `record_trace.py --reader <index|name substring> --label "Lab card A" --runs 10 --length-form short --out traces/`. Same sequence and chaining rules as T5. `time.perf_counter_ns()` around each `transmit`; `sessionStarted` before `connect()`, `cardDetected` after. One trace JSON per run in the same format (transport `pcsc`, device = reader name + host OS); a per-label summary table (count, min, mean, p95, max RTT, ms with 3 decimals). README: install, list readers, example run.

Acceptance:

- [ ] A script-produced trace decodes in Swift and replays through MockTransport (synthetic if no reader is available).

## 5. Fixtures

Synthetic fixtures in `Tests/CardCoreTests/Fixtures/synthetic/`, copied to the app's `Resources/MockTraces/`: `synthetic-fido2-getinfo-chained.json`, `synthetic-u2f-only.json`, `synthetic-select-fail.json`. Real traces go under `Fixtures/real/` later. Do not invent "real" ones.

## 6. Definition of done

- [ ] Every acceptance criterion in T1–T7 is checked.
- [ ] `swift test` passes on macOS.
- [ ] The app builds for the Simulator and a generic iOS device, with no warnings in project code.
- [ ] `docs/trace-format.md` is written.
- [ ] The README covers setup, tests, a mock run and the PC recorder.
- [ ] The summary is posted: changes, decisions, open questions.

## 7. Verified by Ikbal on device (not by the agent)

- [ ] The NFC sheet appears, the IDEMIA card is detected, and SELECT returns `FIDO_2_0` or `U2F_V2` with 9000.
- [ ] GET_INFO returns status `00` + data. Any chaining shows up as separate exchanges.
- [ ] Extended length either works or fails cleanly. Record which, as an answer for the card team.
- [ ] RTTs look plausible. Compare 10 iPhone runs with 10 PC-recorder runs on the same card.
- [ ] A JSON exported from the phone replays identically through MockTransport. It becomes the first file in `Fixtures/real/`.

## 8. Out of scope (later briefs)

CBOR and CTAP decoding (brief 02); PIN/UV auth protocols; MakeCredential, GetAssertion, Reset; the final UI from the mockup; persistence and history; Android.
