# Brief 02 — CBOR & CTAP layer, GetInfo decoding

| | |
|---|---|
| Project | FIDOSims (iOS only) |
| Owner | Mokhamad Ikbal Taqyudin |
| Depends on | Brief 01, signed off on device |
| Use cases completed | None. This is the infrastructure every later brief uses. |
| Next | Brief 03 — PIN & card management |

## 1. Context

Brief 01 can send SELECT and GetInfo and time the raw bytes. This brief adds the layer that understands those bytes:

- a canonical CBOR codec;
- a CTAP client on top of `ISO7816Channel`;
- a fully decoded GetInfo, which acts as the capability matrix for all later scenarios.

It also upgrades the trace format to v2, so traces can show app-side processing and logical command results, not only raw APDUs. Finally, it sets up python-fido2 as the test oracle.

Ground rules: brief 01 §2 and the README apply.

## 2. Inputs

- **From Ikbal, optional:** real GetInfo traces from brief 01 in `Fixtures/real/`, once IT/security approves. Not blocking.
- **Assumption until the card team answers:** the card is CTAP 2.1. If brief 01 showed the card is `U2F_V2`-only (GetInfo returns `6D00`), stop: the plan changes.

## 3. Tasks

### T1 — New target `CTAP`

- New target `CTAP`, depending on `CardCore`. Test target `CTAPTests`, with `Fixtures/` as resources.
- `FIDOKit` depends on `CTAP` and re-exports it.
- `CTAP` contains no CoreNFC code and builds and tests on macOS.

### T2 — Canonical CBOR (`CTAP/CBOR`)

**Value model**

- Supported types: unsigned and negative integers (full 64-bit range), byte strings, text strings, arrays, maps, `true`, `false`, `null`.
- The decoder rejects, each with a specific error: floats, tags, `undefined`, indefinite lengths, truncated input, and invalid UTF-8.

**Encoder:** always emits CTAP2 canonical form.

- Integers and lengths use the shortest form.
- Lengths are always definite.
- Map keys are sorted by major type first, then shorter encoded key first, then bytewise. So integer keys come before text keys; COSE labels sort as `1, 3, -1, -2, -3`; `"rk" < "up" < "uv"`.
- Duplicate keys are an error.
- Nesting deeper than 4 levels in an outgoing request is an error.

**Decoder**

- Returns the value **and the number of bytes consumed**. Brief 04 needs this to find where the COSE key ends inside authData.
- Decoding authenticator responses never fails just because the CBOR is not canonical. Instead it produces a `CanonicalityReport` listing each violation: non-shortest integer or length, unsorted keys. The CTAP client turns each violation into a trace `warning` event. A card that sends non-canonical CBOR is a **finding** for the card team.

**Diagnostic notation printer** (RFC 8949 §8), for example `{1: ["FIDO_2_0", "FIDO_2_1"], 3: h'2FC0…'}`.

- Optional annotation of known keys, e.g. `1 /versions/: [...]`. The schema comes from the command models.

Acceptance:

- [ ] Every vector from `tools/vectors/cbor.json` (T7): `decode(hex)` then `encode` gives back the same hex, and values built in Swift encode to the Python hex.
- [ ] Sort-order tests for mixed int/text keys, COSE labels, and `rk`/`up`/`uv`.
- [ ] Rejection or canonicality-violation tests for: non-shortest integer, unsorted map, indefinite length, duplicate key, depth over 4 (encoder side), truncated input.
- [ ] The bytes-consumed value is correct when decoding a CBOR item followed by trailing bytes.

### T3 — CTAP client (`CTAP/Client`)

```swift
public func send(_ command: CTAPCommandCode,
                 parameters: CBORValue?,
                 label: String,
                 sensitive: Bool = false) async throws -> CBORValue?
```

**Framing and status**

- Wraps `command byte ‖ CBOR(parameters)` in NFCCTAP_MSG through `ISO7816Channel`.
- Parses the status byte. A non-zero status throws `CTAPError(code:name:)`. An empty body after `00` is allowed.
- Includes the full status-code table: every code from the study guide §9. `0xE0–0xEF` are named "extension-specific" and `0xF0–0xFF` "vendor-specific".

**Message size.** After GetInfo, a request larger than `maxMsgSize` (default 1024) is refused before it is sent, with `requestTooLarge`. A debug bypass for negative tests comes in brief 06.

**P1 for NFCCTAP_MSG**

- From this brief on, `getResponseSupported` defaults to **true** (P1 = `80`).
- If the card answers an NFCCTAP_MSG with `6A86` or `6B00`, retry once with P1 = `00`. Keep P1 = `00` for the rest of the session and record a trace `warning` (`P1_FALLBACK`).

**Trace.** Each `send` emits a v2 `command` event (T5) containing the CTAP command byte and status.
When the card answers an extended-form command with `61xx`, record the warning `EXTENDED_FORM_CHAINED`.

Acceptance:

- [ ] Against MockTransport: a status `00` + CBOR body decodes; a non-zero status throws with the right name; an oversize request is refused without sending.
- [ ] P1 fallback works and is recorded.
- [ ] Non-canonical response CBOR produces `warning` events without failing the command.

### T4 — GetInfo model (`CTAP/Commands/GetInfo`)

- Decode keys `0x01`–`0x15` into typed fields, following the study guide §4 table.
- `options` become a typed `AuthenticatorOptions` plus the raw map.
- Unknown keys are preserved and displayed, never treated as errors.
- `Capabilities` helpers, with these defaults when a key is absent:
  - `preferredPinProtocol`: 2 if listed, otherwise 1;
  - `clientPin`: `.set`, `.notSet` or `.unsupported`;
  - `supportsResidentKeys`, `supportsPinUvAuthToken`, `makeCredUvNotRqd`, `credMgmt`;
  - `maxMsgSize` (default 1024), `maxCredentialCountInList`;
  - `algorithms` (default `[ES256]`), `minPINLength` (default 4);
  - `remainingDiscoverableCredentials`, `firmwareVersion`.
- After GetInfo, the trace `card` metadata is filled with `aaguid`, `versions` and `firmwareVersion`.

Acceptance:

- [ ] A synthetic GetInfo with all keys `0x01`–`0x15` plus one unknown key decodes completely.
- [ ] Defaults apply when keys are absent.
- [ ] For each real GetInfo fixture (auto-skip if none), typed fields equal the python-fido2 output from `decode_getinfo.py` (T7).

### T5 — Trace format v2 [CONTRACT change approved by Ikbal]

`schemaVersion: 2`. The decoder must still read v1.

**Time reference.** `t = 0` is `scenarioStarted`, emitted when a scenario begins (before the NFC sheet opens). v1 traces keep `sessionStarted` as their reference.

**Top-level additions**

- `scenario`: `diagnostics`, `setPIN`, `changePIN`, `reset`, `register`, `authenticate`, `raw`.
- `outcome`: `{ "status": "success" | "failure" | "cancelled", "error": { "domain", "code", "name", "message" }? }`, where domain is one of `transport`, `iso7816`, `ctap`, `validation`, `rp`, `internal`.
- `card` gains the optional fields `aaguid`, `versions` and `firmwareVersion`.

**New event types**

| Event | Fields | Meaning |
|---|---|---|
| `scenarioStarted` / `scenarioEnded` | `t` | Bounds of the whole user-visible transaction |
| `command` | `commandIndex`, `label`, `ctapCommand`?, `ctapStatus`?, `sw`, `tStart`, `tEnd`, `exchanges` | One logical command (all its physical exchanges) |
| `hostStep` | `label`, `tStart`, `tEnd` | App-side work: `CBOR_ENCODE`, `CBOR_DECODE`, `PIN_PROTOCOL`, `RP_VERIFY`, … |
| `status` | `t`, `value` (`PROCESSING` / `UPNEEDED`) | NFCCTAP 9100 updates |
| `warning` | `t`, `code`, `message` | Non-canonical CBOR, P1 fallback, reserved flag bits, … |

**[CONTRACT] Timeline model.** Additive; replaces the provisional v1 metrics.

```
scenarioTotal = preSession + cardWait + cardPhase + postSession
  preSession  = sessionStarted − scenarioStarted         (RP begin, clientData, …)
  cardWait    = cardDetected − sessionStarted            (sheet + user tap + CoreNFC implicit SELECT)
  cardPhase   = lastExchangeEnd − cardDetected
      apduTotal     = Σ exchange RTT
      inSessionHost = cardPhase − apduTotal              (= v1 "hostOverhead")
  postSession = scenarioEnded − lastExchangeEnd          (session close, RP verify, store)
sessionTotal  = cardWait + cardPhase                     (= v1 "sessionTotal")
```

- Per-label totals are also reported for `command` and `hostStep` events.
- Which of these the BU calls "transaction total" is still open. Show all of them.
- **Cost of recording.** Recording an event must not do I/O or UI work. Events are appended to memory only.

**Text export.** Add one command-level summary line per logical command and the host-step lines. The segment breakdown goes at the bottom.

Acceptance:

- [ ] v2 round-trip; v1 fixtures still decode and give the same v1 metrics.
- [ ] Timeline segments add up exactly to `scenarioTotal` on a fixture with known numbers.
- [ ] `docs/trace-format.md` updated, with a v2 example.

### T6 — Diagnostics upgrade (Lab › Diagnostics)

- `FIDODiagnostics` now uses `CTAPClient`. It emits `scenarioStarted`/`scenarioEnded` and records host steps (`CBOR_DECODE`).
- Add a **Decoded** tab next to Hex / Safe:
  - CBOR diagnostic notation for each command;
  - a GetInfo capability table: versions, AAGUID, options, PIN protocols, algorithms, limits, firmware.
- Warnings appear as a list above the exchanges.

Acceptance:

- [ ] Decoded view works in the Simulator with the synthetic GetInfo fixture.
- [ ] Warnings are visible.

### T7 — Python oracle (`tools/`)

- `tools/requirements.txt` pins `pyscard`, `fido2` (python-fido2) and `webauthn` (py_webauthn, used from brief 04). Use the current major versions and verify module paths against them.
- `tools/vectors/gen_cbor_vectors.py` writes `cbor.json` to `CTAPTests/Fixtures/vectors/`.
  - Format: a list of `{name, hex, diag}`.
  - Cases:
    - integer boundaries: 0, 23, 24, 255, 256, 65535, 65536, 2³²−1, 2³², −1, −24, −25, −256, −257;
    - byte and text strings of length 0, 23, 24, 255, 256;
    - nested arrays and maps;
    - mixed int/text keys;
    - a COSE EC2 key;
    - the GetInfo request.
  - Encode with python-fido2's CBOR module, which produces CTAP canonical output.
- `tools/vectors/decode_getinfo.py <trace.json>` parses the GetInfo response with python-fido2 and writes a JSON summary that the Swift tests compare against.
- `tools/pc-baseline/ctap_runner.py --scenario diagnostics --runs N` drives python-fido2 over PC/SC (`CtapPcscDevice`).
  - Time each physical APDU by hooking the pyscard connection, for example with a `CardConnectionObserver` or a thin wrapper around `transmit`.
  - Write trace v2 JSON with transport `pcsc`.
  - Keep `record_trace.py` from brief 01 for raw-APDU runs.

Acceptance:

- [ ] Running the scripts from a clean venv reproduces the committed vectors exactly.
- [ ] A `ctap_runner.py` trace decodes in Swift. A synthetic sample is acceptable if no reader is available.

## 4. Definition of done

- [ ] T1–T7 acceptance criteria are checked.
- [ ] `swift test` passes on macOS.
- [ ] The app builds with no warnings in project code.
- [ ] The README and `docs/trace-format.md` are updated.
- [ ] The summary is posted.

## 5. Verified by Ikbal on device

- [ ] The IDEMIA card's GetInfo is decoded on the iPhone and matches `decode_getinfo.py` field by field.
- [ ] Record these values and send them to the card team as confirmation: versions, PIN protocols, options (`clientPin`, `rk`, `pinUvAuthToken`, `makeCredUvNotRqd`, `credMgmt`), `maxMsgSize`, `maxCredentialCountInList`, algorithms, firmware. Then update "Open decisions" in the README.
- [ ] Note whether the card returns non-canonical CBOR (any `warning`). If it does, report it to the card team.
- [ ] Note whether the card accepts P1 = `80` or a `P1_FALLBACK` warning was recorded.
- [ ] Compare iPhone and `ctap_runner.py` diagnostics timings on the same card.

## 6. Out of scope

- ClientPIN and the PIN protocols (brief 03).
- MakeCredential (brief 04), GetAssertion (brief 05).
- Credential management, bio enrollment, large blobs, authenticatorConfig.
- CTAP1/U2F commands.
- Final UI. Android (descoped).
