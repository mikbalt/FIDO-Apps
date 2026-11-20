# Brief 01 — Foundation: workspace, CardCore, NFC spike

| | |
|---|---|
| Project | FIDOSims — FIDO simulator app (iOS only; Android descoped) |
| Owner | Mokhamad Ikbal Taqyudin |
| Status | Ready for implementation |
| Depends on | Nothing. Uses synthetic fixtures; real card traces are added later. |
| Next | Brief 02 — CTAP + PIN (Change PIN, Reset) |

## 1. Context

FIDOSims is an internal R&D test app. It runs FIDO2 (CTAP2) transactions **directly** against a FIDO NFC card and measures the elapsed time of every APDU command–response, plus the totals. The app plays both the WebAuthn client and a local relying party. It does **not** use ASAuthorization or any platform passkey API, because those hide the individual APDUs we need to time.

This brief covers only the foundation:

- the repo and workspace;
- the APDU layer;
- the NFC transport;
- timing traces;
- a diagnostics screen that runs SELECT + authenticatorGetInfo against a real card.

CTAP/CBOR, PIN, MakeCredential and the final UI come in later briefs.

## 2. Ground rules

- **Swift and concurrency.**
  - Swift 6 language mode with strict concurrency.
  - `@preconcurrency import CoreNFC` is allowed.
  - `@unchecked Sendable` is allowed only inside the NFC transport, with a comment explaining the invariant.
- **Dependencies.** No third-party Swift dependencies.
- **App structure.** SwiftUI + MVVM with `@Observable` view models. One type per file, feature folders, and reusable views in `Components/`.
- **SDK boundaries.** SDK code has no UI. Anything that does not need CoreNFC lives in `CardCore` and must build and test on macOS (`swift test`).
- **Contracts.** Items marked **[CONTRACT]** are owned by Ikbal: the transport API, the trace format and the timing metrics. Implement them as written. If you believe one must change, stop and ask.
- **Secrets.** Never write secrets in plaintext to logs or exports. Exchanges can be flagged `sensitive`; this is required from brief 02 on, for ClientPIN.
- **Commits and reporting.** Make small commits, one per task. At the end, post a short summary: what changed, the decisions you made, and any open questions.

**Stop and ask if:**

- a contract needs to change;
- a third-party dependency seems necessary;
- XcodeGen is unavailable;
- signing needs values that are not in this brief.

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

**`FIDOKit/Package.swift`**

- Tools version 6.0. Platforms `.iOS(.v17)` and `.macOS(.v14)`.
- Targets:
  - `CardCore`.
  - `FIDOKit`: depends on `CardCore` and re-exports it with `@_exported import CardCore`.
- Test targets:
  - `CardCoreTests`, with `Fixtures` as resources.
  - `FIDOKitTests`.
- Product: library `FIDOKit`.
- Wrap every use of CoreNFC in `#if os(iOS)`, so the package still builds on macOS.

**App project**, generated from `App/project.yml` with XcodeGen:

- iOS 17+.
- Depends on the local package `../FIDOKit`.
- Bundle ID `$(BUNDLE_ID_PREFIX).fidosims`; signing values come from `Signing.local.xcconfig`.
- `Info.plist`:
  - `NFCReaderUsageDescription`.
  - `com.apple.developer.nfc.readersession.iso7816.select-identifiers` = [`A0000006472F0001`].
- Entitlements: `com.apple.developer.nfc.readersession.formats` = [`TAG`].

**Workspace and repo**

- `FIDOSims.xcworkspace` opens both the app project and the package.
- `.gitignore` covers Xcode, SwiftPM, Python and `Signing.local.xcconfig`.
- Decide whether the generated `.xcodeproj` is committed or gitignored, and document the choice.

Acceptance:

- [ ] After `xcodegen generate`, opening the workspace shows schemes `FIDOSims` and `FIDOKit`, and both build for the iOS Simulator.
- [ ] `cd FIDOKit && swift build && swift test` succeeds on macOS.
- [ ] The README explains first-time setup: install XcodeGen, copy the signing example, generate, open the workspace.

### T2 — APDU model (`CardCore/APDU`)

- `CommandAPDU` has the fields `cla`, `ins`, `p1`, `p2`, `data` and `le: Int?`. `nil` means Le is absent; otherwise the range is 1…65536.
- `encoded(_ form: LengthForm) throws -> Data` supports forms `.short` and `.extended`. It covers ISO 7816-4 cases 1–4 in both forms:
  - short: Le 256 is encoded as `00`;
  - extended case 2: `00 Le1 Le2`;
  - extended cases 3 and 4: `00 Lc1 Lc2 data [Le1 Le2]`;
  - extended Le 65536 is encoded as `00 00`.
- `ResponseAPDU` holds `data` and `sw`, parsed from raw bytes (at least 2 bytes).
- `StatusWord` helpers:
  - `sw1`, `sw2`, and `isSuccess` (true for 9000);
  - display names for 9000, 61xx, 6Cxx, 6700, 6985, 6A80, 6A82, 6D00, 6E00 and 9100.
- A `Hex` utility that parses and formats hex with spaces, e.g. `00 A4 04 00`.

Acceptance (unit tests):

- [ ] All 4 cases encode to the expected bytes in both forms, including the boundaries:
  - Lc 255 in short form is OK; Lc 256 in short form throws;
  - Le 256 in short form → `00`; Le 65536 in extended form → `00 00`;
  - data longer than 65535 bytes throws.
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

The transport itself takes the timestamps, as close to the hardware call as possible. That way, actor hops and decorators never end up inside an RTT.

**[CONTRACT] Trace format.** Write this up in `docs/trace-format.md`.

- A trace is metadata plus ordered events. The event types are `sessionStarted`, `cardDetected`, `exchange` and `sessionEnded`.
- Each `exchange` event records:
  - `index`: 1-based, counts physical APDUs;
  - `commandIndex` and `label`: the logical command it belongs to, e.g. `SELECT_FIDO`, `GET_INFO`;
  - `tx`, `rx`, `sw`;
  - `tStart`, `tEnd`;
  - `sensitive`.
- Times are monotonic nanoseconds since `sessionStarted` (Int64). `createdAt` is wall-clock time, for display only.
- Hex strings in JSON are uppercase with no spaces.

```json
{
  "schemaVersion": 1,
  "id": "6F1C2D3E-0000-4000-8000-000000000001",
  "createdAt": "2026-11-20T09:15:02Z",
  "app": { "name": "FIDOSims", "version": "0.1.0", "build": "1" },
  "transport": "nfc",
  "device": { "model": "iPhone16,2", "os": "iOS 26.1" },
  "card": { "label": "Lab card A", "initialSelectedAID": "A0000006472F0001" },
  "options": { "lengthForm": "short", "getResponseSupported": false },
  "events": [
    { "type": "sessionStarted", "t": 0 },
    { "type": "cardDetected", "t": 1503000000 },
    { "type": "exchange", "index": 1, "commandIndex": 1, "label": "SELECT_FIDO",
      "tx": "00A4040008A0000006472F000100", "rx": "4649444F5F325F30", "sw": "9000",
      "tStart": 1503100000, "tEnd": 1515500000, "sensitive": false },
    { "type": "sessionEnded", "t": 1842700000, "reason": "completed" }
  ]
}
```

`TraceRecorder` builds a `Trace` from a `CardConnection` plus `RawExchange`s and must be concurrency-safe.

**[CONTRACT] Metrics.** These definitions are provisional; the final version is pending the BU's answer.

| Metric | Definition |
|---|---|
| `cardWait` | `cardDetected − sessionStarted` |
| `apduTotal` | Σ (`tEnd − tStart`) over all exchanges |
| `sessionTotal` | `tEnd` of the last exchange − `sessionStarted` (includes waiting for the card) |
| `hostOverhead` | `sessionTotal − cardWait − apduTotal` (app processing + stack time between exchanges) |
| Per logical command | Σ RTT of its physical exchanges, plus the exchange count |

Display values in milliseconds with 3 decimals, e.g. `12.400 ms`.

Add this note to the docs: on iOS, CoreNFC sends its own SELECT for the first matching AID during discovery, before handing over the tag. That time falls inside `cardWait`, not inside any exchange. This is why `initialSelectedAID` is recorded.

**Exports**

- JSON is the trace itself. `redactSensitive` defaults to true.
- The text log must match this golden format:

```
FIDOSims trace <id> | nfc | <device model> <os> | Lab card A
01 SELECT_FIDO
TX 00 A4 04 00 08 A0 00 00 06 47 2F 00 01 00
RX 46 49 44 4F 5F 32 5F 30 | SW 9000
RTT 12.400 ms
...
Session total 1842.700 ms | Card wait 1503.000 ms | APDU total 319.500 ms | Host 20.200 ms | 8 exchanges
```

- In Safe mode and in redacted exports, the data of a sensitive exchange is rendered as `<redacted N bytes>`.

**MockTransport**

- Built from a trace JSON fixture. It replays `rx`/`sw` for each expected `tx`, in order.
- It reports the recorded durations without sleeping, unless `realtime: true` is set.
- It is strict: a `tx` that differs from the script fails with an error showing the expected and actual bytes.

Acceptance:

- [ ] JSON round-trip: `decode(encode(trace)) == trace`, and all synthetic fixtures decode.
- [ ] Metrics are correct for a fixture with known numbers.
- [ ] The text export matches a golden file, and redaction works.
- [ ] MockTransport replays a fixture and fails clearly on a mismatch.

### T4 — ISO 7816 channel (`CardCore/Channel`)

`ISO7816Channel` sits on top of a `CardTransport` and a `TraceRecorder`. It sends one **logical** command, which may turn into several physical exchanges:

```swift
public func send(_ command: CommandAPDU, label: String, sensitive: Bool = false) async throws -> ResponseAPDU
```

Rules:

1. **Encoding form** comes from `ChannelOptions.lengthForm`: `.short` by default, `.extended` optional.
2. **Command chaining** applies in short form when data is longer than 255 bytes:
   - split the data into chunks of at most 255 bytes;
   - every chunk except the last gets `CLA | 0x10`, so NFCCTAP_MSG `80` becomes `90`;
   - every intermediate response must be `9000`, otherwise throw;
   - only the last chunk carries Le.
3. **`61xx`**: send `00 C0 00 00 xx` (`xx = 00` means 256) and append the returned data. Repeat until a final SW arrives.
4. **`6Cxx`**: resend the same command once, with Le = `xx`.
5. **`9100`** is an NFCCTAP status update. Its data is one status byte: `01` PROCESSING or `02` UPNEEDED.
   - Poll with NFCCTAP_GETRESPONSE `80 11 00 00 00` until a final SW arrives.
   - The poll interval is configurable (default 0); the timeout defaults to 30 s.
   - Expose status updates (an `AsyncStream` or a callback) so the UI can show "keep the card in place".
6. **Task cancellation** stops between exchanges and throws `CancellationError`. Exchanges already done stay in the trace.
7. **Recording**: every physical exchange is recorded under the same `commandIndex` and `label`.

Helpers:

- `selectFIDO()` sends `00 A4 04 00 08 A0 00 00 06 47 2F 00 01 00` and returns the version string (`U2F_V2` / `FIDO_2_0`).
- `nfcctapMsg(_ payload: Data)` builds CLA `80`, INS `10`, P1, P2 `00`, with the maximum Le for the form.
  - P1 is `80` when `options.getResponseSupported` is true, otherwise `00`. The default is false in this brief.

Acceptance (unit tests with MockTransport):

- [ ] A chain of three `61xx` responses: data is concatenated in order, and 4 exchanges are recorded under one command.
- [ ] `61 00` triggers a GET RESPONSE with Le `00`.
- [ ] `6Cxx` triggers exactly one resend with the corrected Le.
- [ ] A 600-byte payload in short form becomes 3 chunks with CLA `90`, `90`, `80`; a non-9000 intermediate response throws.
- [ ] `9100` (PROCESSING) twice, then `9000`: exactly 2 GETRESPONSE polls. Endless `9100` ends in a timeout error.
- [ ] Cancelling mid-chain throws `CancellationError`, and the trace keeps the completed exchanges.

### T5 — NFC transport and diagnostics scenario (`FIDOKit`)

**`NFCCardTransport`** (iOS only):

- **Session and detection.**
  - Use `NFCTagReaderSession(pollingOption: .iso14443)`.
  - On detection, take the first `.iso7816` tag and connect.
  - Set `cardDetectedAt` once the connect succeeds, and store `initialSelectedAID`.
  - If several tags are detected, show an alert message and restart polling.
- **Transmit.**
  - Wrap the raw bytes with `NFCISO7816APDU(data:)`. A `nil` result (for example, a refused extended encoding) throws `CardError.invalidAPDU`.
  - Call `sendCommand(apdu:)`, with the timestamps taken right around that call.
- **Errors.** Map session invalidation to `CardError`:
  - `.userCancelled`;
  - `.sessionTimeout` (the iOS 60 s limit);
  - `.tagConnectionLost`;
  - `.nfcUnavailable`;
  - `.underlying(Error)`.
- **Alert messages.** Update `alertMessage` as the run progresses: "Hold the card near the top of the iPhone", "Reading…", "Done".
- **Availability.** `isAvailable` returns `NFCTagReaderSession.readingAvailable`.

**`FIDODiagnostics.runSelectAndGetInfo(transport:options:) async throws -> Trace`**

1. Run open → `SELECT_FIDO` → `GET_INFO` (`nfcctapMsg([0x04])`) → close.
2. If SELECT does not return 9000 with a known version string, record it and stop. The trace is still returned.
3. In the GetInfo response, the first byte is the CTAP status (`00` = OK) and the rest is raw CBOR. Decoding the CBOR is brief 02. A `6D00` is recorded as "CTAP1-only card".
4. Options: `lengthForm`, `getResponseSupported`, `cardLabel`.

Acceptance:

- [ ] FIDOKitTests run diagnostics against MockTransport fixtures for:
  - (a) a `FIDO_2_0` card with a `61xx` chain on GetInfo;
  - (b) a `U2F_V2`-only card that returns `6D00` for GetInfo;
  - (c) a SELECT failure with `6A82`.
- [ ] The package still builds on macOS, with the NFC code compiled out.

### T6 — Diagnostics screen (App)

This is a temporary engineering screen. It will grow into the "Logs and timing" screen of the final UI, so build its parts as reusable components.

**Controls**

- Transport: NFC or Mock. Mock is forced in the Simulator, or when NFC is unavailable.
- Mock fixture picker.
- APDU length form: short or extended.
- Card label.
- **Run** and **Cancel** buttons.

**While running**

- Show the state: waiting for card, exchanging, done or failed.
- Show a live elapsed-time counter.

**Result**

- Metric tiles: Session total, Card wait, APDU total, Host overhead, Exchanges.
- Exchange list: index, label, RTT, TX/RX hex, SW.
- A **Hex / Safe** toggle. A Decoded view comes in brief 02.

**Export and history**

- Export JSON and text through `ShareLink`.
- Keep the last 10 traces in memory. No persistence yet.

**Wiring**

- `AppContainer` builds the transports. The ViewModel depends only on `CardTransport`.

Acceptance:

- [ ] In the Simulator, Mock runs every fixture end to end, and the numbers on screen match the fixture.
- [ ] The app builds for a generic iOS device, with the NFC entitlement and Info.plist keys present.

### T7 — PC baseline recorder (`tools/pc-baseline`) — OPTIONAL

**Optional.** Not requested by the kickoff. Skip it if you have not started it; finish it if it is already mostly done.

Python 3.10 or newer, with `pyscard` as the only dependency.

- **Command line:** `record_trace.py --reader <index|name substring> --label "Lab card A" --runs 10 --length-form short --out traces/`
- **Sequence:** the same as T5 (`SELECT_FIDO`, `GET_INFO`), with the same chaining rules (`61xx`, `6Cxx`, `9100`).
- **Timing.**
  - Use `time.perf_counter_ns()` around each `transmit`.
  - `sessionStarted` is taken before `connect()`, and `cardDetected` after it.
- **Output.**
  - One trace JSON per run, in the **same format** as the app, with transport `pcsc` and device = reader name + host OS.
  - A summary table per label: count, min, mean, p95, max RTT, in ms with 3 decimals.
- **README:** install steps, how to list readers, an example run.

Acceptance:

- [ ] A trace produced by the script decodes in Swift and replays through MockTransport. Add one script-produced sample as a test fixture; it may be synthetic if no reader is available.

## 5. Fixtures

Until real card traces are available, create **synthetic** fixtures in `Tests/CardCoreTests/Fixtures/synthetic/` and copy them to the app's `Resources/MockTraces/`. Name them clearly:

- `synthetic-fido2-getinfo-chained.json`: SELECT → `FIDO_2_0` 9000; GET_INFO → `61xx` + a GET RESPONSE chain ending in status `00` + arbitrary bytes.
- `synthetic-u2f-only.json`: SELECT → `U2F_V2` 9000; GET_INFO → `6D00`.
- `synthetic-select-fail.json`: SELECT → `6A82`.

Ikbal will add real traces under `Fixtures/real/` later. Do not invent "real" ones.

## 6. Definition of done

- [ ] Every acceptance criterion in T1–T6 is checked (and T7, if you did it).
- [ ] `swift test` passes on macOS.
- [ ] The app builds for the Simulator and a generic iOS device, with no warnings in project code.
- [ ] `docs/trace-format.md` is written, including the answers given during this brief: `sessionEnded.reason` enum, redaction representation, `sessionTotal` ends at the last exchange, follow-up APDUs (GET RESPONSE, NFCCTAP_GETRESPONSE) always in short form.
- [ ] The README covers setup, tests and a mock run.
- [ ] The summary is posted: changes, decisions, open questions.

## 7. Verified by Ikbal on device (not by the agent)

- [ ] The NFC sheet appears, the IDEMIA card is detected, and SELECT returns `FIDO_2_0` or `U2F_V2` with 9000.
- [ ] GET_INFO returns status `00` + data. Any chaining shows up as separate exchanges.
- [ ] Extended length either works or fails cleanly. Record which, as an answer for the card team.
- [ ] RTTs look plausible over 10 iPhone runs. If T7 was done, compare with 10 PC-recorder runs on the same card.
- [ ] A JSON exported from the phone replays identically through MockTransport. It becomes the first file in `Fixtures/real/`.

## 8. Out of scope (later briefs)

- CBOR, CTAP, PIN protocol, Change PIN, Reset (brief 02).
- Register, Authenticate, Registrations and History (brief 03).
- The final UI: waiting on the UI/UX team, separate brief later.
- Android: descoped. Do not build anything for it.
- Anything in the README "Parked" list.
