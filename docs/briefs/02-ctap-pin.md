# Brief 02 — CTAP + PIN: Change PIN and Reset

| | |
|---|---|
| Project | FIDOSims (iOS only) |
| Owner | Mokhamad Ikbal Taqyudin |
| Depends on | Brief 01, signed off on device |
| Kickoff features | **Change the card PIN**, **Reset the card** (plus Set PIN, needed after a reset) |
| Next | Brief 03 — Register + Authenticate |

## 1. Context

Brief 01 can send APDUs and time them. This brief adds the minimum CTAP2 stack needed to talk to the card:

- CBOR encoding and decoding;
- a CTAP client;
- GetInfo;
- PIN protocol 2 and authenticatorClientPIN.

On top of that it delivers two of the four kickoff features. It also introduces the `FIDOSimulator` facade, which brief 03 and the final UI will use.

Ground rules: brief 01 §2 and the README apply. **Keep it lean:** build only what is listed here.

## 2. Inputs and assumptions

| Input | Assumption until the card team answers |
|---|---|
| PIN protocol | Protocol 2. If GetInfo shows the card supports only protocol 1, **stop and ask**. |
| Default PIN | `1234` appears only as a UI default. Never hard-coded in the SDK. |
| Reset over NFC | May be refused by the card. Handle it cleanly. |
| Spare lab card | Ikbal uses one for reset and wrong-PIN tests. |

## 3. Tasks

### T1 — New target `CTAP` (depends on `CardCore`): CBOR

- **Types:** unsigned and negative integers (64-bit), byte strings, text strings, arrays, maps, booleans, null.
- **The decoder rejects** floats, tags, indefinite lengths and truncated input.
- **The encoder always emits CTAP2 canonical form:**
  - integers and lengths in the shortest form;
  - map keys sorted by major type, then shorter encoded key first, then bytewise. So integer keys come before text keys, COSE labels sort as `1, 3, -1, -2, -3`, and `"rk" < "up" < "uv"`.
- **The decoder returns the value and the number of bytes consumed.** Brief 03 needs this to find where the COSE key ends inside authData.
- `FIDOKit` depends on `CTAP` and re-exports it. `CTAP` contains no CoreNFC code and tests on macOS.

Acceptance:

- [ ] Unit tests for integer and length boundaries (23/24, 255/256, 65535/65536), key sort order, round-trips, and the rejections above.

### T2 — CTAP client

```swift
public func send(_ command: CTAPCommandCode,
                 parameters: CBORValue?,
                 label: String,
                 sensitive: Bool = false) async throws -> CBORValue?
```

- Wraps `command byte ‖ CBOR(parameters)` in NFCCTAP_MSG (`80 10 00 00 …`) through `ISO7816Channel`.
- **P1 stays `00`.** On NFC the tap already counts as user presence.
- **Status byte:** `00` returns the decoded body (which may be empty). Anything else throws `CTAPError` with its name.
- **Status-code names** come from the study guide §9 table.

### T3 — GetInfo

Decode into typed fields:

- `versions`, `aaguid`, `options`, `maxMsgSize`, `pinUvAuthProtocols`;
- `maxCredentialCountInList`, `algorithms`, `minPINLength` (default 4);
- `firmwareVersion`, `remainingDiscoverableCredentials`.

The options needed are `clientPin`, `rk`, `pinUvAuthToken` and `makeCredUvNotRqd`. Other keys are kept raw and shown, never treated as errors.

**Diagnostics** now decodes GetInfo. The **Decoded** view shows:

- one line per command (label + short meaning, e.g. "Capabilities received"), as in the mockup log;
- a GetInfo table;
- a plain-text dump of the CBOR for each command.

Acceptance:

- [ ] A synthetic GetInfo decodes, including an unknown key.
- [ ] The Decoded view works in the Simulator with the mock fixture.

### T4 — PIN protocol 2 (new target `PinUvAuth`, depends on `CTAP`)

- **Key agreement:** ECDH on P-256 with CryptoKit `P256.KeyAgreement`; Z is the x-coordinate of the shared point. The platform key is sent as COSE `{1: 2, 3: -25, -1: 1, -2: x, -3: y}`.
- **Shared secret:** `HKDF-SHA-256(salt = 32 × 0x00, IKM = Z, info = "CTAP2 HMAC key", L = 32)` ‖ `HKDF(…, info = "CTAP2 AES key", L = 32)`. These are **two separate 32-byte calls, not one 64-byte call.**
- **encrypt:** AES-256-CBC with the AES half of the secret, a random 16-byte IV, no padding; output is `IV ‖ ciphertext`. Use CommonCrypto, because CryptoKit has no CBC.
- **authenticate:** HMAC-SHA-256, full 32 bytes. With the shared secret as the key, use its HMAC half; with a token as the key, use the token directly.
- Randomness (ephemeral key, IV) is injectable for tests.
- Secrets never appear in traces or logs.

Acceptance:

- [ ] Encrypt/decrypt round-trip.
- [ ] A test that the shared secret is built from two HKDF calls.
- [ ] `authenticate` returns 32 bytes.

### T5 — authenticatorClientPIN

| Sub | Name | Formula |
|---|---|---|
| `0x01` | getPINRetries | Returns `pinRetries` |
| `0x02` | getKeyAgreement | Returns the card's COSE key |
| `0x03` | setPIN | `newPinEnc = encrypt(shared, pad64(PIN))`; `pinUvAuthParam = authenticate(shared, newPinEnc)` |
| `0x04` | changePIN | `pinHashEnc = encrypt(shared, LEFT(SHA-256(current), 16))`; `pinUvAuthParam = authenticate(shared, newPinEnc ‖ pinHashEnc)` |
| `0x09` | getPinUvAuthTokenUsingPinWithPermissions | `pinHashEnc` + permissions + rpId; `token = decrypt(shared, resp[0x02])`. Used in brief 03. |
| `0x05` | getPinToken | Only if GetInfo has no `pinUvAuthToken` option (CTAP 2.0 card) |

**PIN validation**, before anything is sent to the card:

- Unicode NFC normalization.
- At least `max(4, minPINLength)` characters; at most 63 UTF-8 bytes.
- Padded with `0x00` to 64 bytes.

**Sensitive exchanges:** setPIN, changePIN and the token subcommands are flagged `sensitive`. The mockup shows them as "Payload redacted".

**Error messages:**

- `0x31` PIN_INVALID: append the remaining retries.
- `0x32` PIN_BLOCKED.
- `0x34` PIN_AUTH_BLOCKED: "remove the card and tap again".
- `0x35` PIN_NOT_SET.
- `0x37` PIN_POLICY_VIOLATION.

### T6 — `FIDOSimulator` facade [CONTRACT]

```swift
public enum ScenarioStep: Sendable, Equatable {
    case waitingForCard, cardDetected, pinVerified, executing(String), completed, failed, cancelled
}

public struct ScenarioResult<Value: Sendable>: Sendable {
    public let value: Value?
    public let error: FIDOSimError?
    public let trace: Trace          // always present, complete up to the failure point
}

public final class FIDOSimulator: Sendable {
    public init(transport: any CardTransport, configuration: FIDOSimConfiguration)
    public func diagnostics(progress: @escaping @Sendable (ScenarioStep) -> Void) async -> ScenarioResult<AuthenticatorInfo>
    public func setPIN(_ pin: String, cardLabel: String, progress: …) async -> ScenarioResult<Void>
    public func changePIN(current: String, new: String, cardLabel: String, progress: …) async -> ScenarioResult<Void>
    public func reset(confirmedCardLabel: String, progress: …) async -> ScenarioResult<Void>
}
```

- Scenarios never throw.
- Task cancellation gives the outcome `cancelled`.
- Diagnostics moves onto the facade.

### T7 — Scenarios

**Change PIN:** `SELECT_FIDO` → `GET_INFO` → `CLIENT_PIN_RETRIES` → `CLIENT_PIN_KEY_AGREEMENT` → `CLIENT_PIN_CHANGE`.

**Set PIN:** `SELECT_FIDO` → `GET_INFO` → `CLIENT_PIN_KEY_AGREEMENT` → `CLIENT_PIN_SET`. Fails early if GetInfo shows a PIN is already set.

**Reset:** `SELECT_FIDO` → `RESET`.

- Send `RESET` immediately, with no GetInfo before it. The card accepts reset only within about 10 s of entering the field.
- The user must type the card label to confirm.
- On `0x30` NOT_ALLOWED, show: "Reset must happen within 10 s of tapping, or this card does not allow reset over NFC".
- On success:
  - delete the stored PIN for that card;
  - call a `onCardReset(cardLabel)` hook. Brief 03 uses it to mark that card's registrations as invalid.

### T8 — Store PIN (the mockup's "Store encrypted PIN")

- Keychain, generic password: service `fidosims.pin`, account = card label, accessible `WhenUnlockedThisDeviceOnly`.
- Updated after a successful Set PIN or Change PIN when the toggle is on.
- Never logged.

### T9 — Trace additions (small, `schemaVersion: 2`; still reads v1)

- **Top level:**
  - `scenario`: `diagnostics`, `setPIN`, `changePIN`, `reset`, `register`, `authenticate`;
  - `outcome`: `{ "status": "success" | "failure" | "cancelled", "error": { "domain", "code", "name", "message" }? }`.
- **`card`:** gains the optional fields `aaguid`, `versions` and `firmwareVersion` from GetInfo.
- **`exchange`:** gains the optional field `ctapStatus` on the exchange that completes a CTAP command.
- **New event `warning`** `{ t, code, message }`. The first code is `EXTENDED_FORM_CHAINED`: the card answered an extended-form command with `61xx`.
- **Metrics are unchanged** from brief 01.

### T10 — Lab UI: Change PIN, Set PIN, Reset

- **Inputs:**
  - card label;
  - PIN: default `1234`, custom, or stored;
  - "Store PIN" toggle.
- **Run / Cancel.**
- **While running:** a live step list and an elapsed-time counter.
- **Result:**
  - outcome and error message;
  - transaction total, APDU total, exchanges;
  - the existing trace view (Hex / Safe / Decoded) and export.
- **Reset:** Run is enabled only after the card label is typed.

## 4. Definition of done

- [ ] T1–T10 are done.
- [ ] `swift test` passes on macOS.
- [ ] The app builds with no warnings in project code.
- [ ] `docs/trace-format.md` is updated.
- [ ] The summary is posted.

## 5. Verified by Ikbal on device (spare card for destructive steps)

- [ ] GetInfo decodes on the iPhone. Note versions, PIN protocols and options, and send them to the card team as confirmation.
- [ ] Change PIN works; the old PIN no longer works.
- [ ] A wrong current PIN gives `0x31`, and retries go down by one.
- [ ] Reset right after the tap works; GetInfo then shows no PIN; Set PIN works.
- [ ] Note whether the card allows reset over NFC at all.
- [ ] Per-command timing and the transaction total are visible, and the text log exports.
- [ ] **Never run PIN retries down to 0 on a card you cannot reset.**

## 6. Out of scope

- PIN protocol 1 (unless needed, see §2).
- Biometric subcommands, credential management, authenticatorConfig.
- MakeCredential and GetAssertion (brief 03).
- Everything in the README "Parked" list.
- Final UI. Android (descoped).
