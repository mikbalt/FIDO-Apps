# Brief 03 — Register + Authenticate

| | |
|---|---|
| Project | FIDOSims (iOS only) |
| Owner | Mokhamad Ikbal Taqyudin |
| Depends on | Brief 02, signed off on device |
| Kickoff features | **Register / add a card**, **Authentication**. All four features are done after this brief. |
| Next | Brief 04 — Final UI (when the UI/UX team delivers) |

## 1. Context

Register and Authenticate are the flows on slide 4 of the kickoff deck. The app plays three roles:

- **Local RP:** makes the challenge, then checks and stores the result.
- **WebAuthn client:** builds clientData and maps the options to CTAP.
- **CTAP platform:** talks to the card.

The JavaScript calls on the slide define the behaviour to reproduce natively:

| Slide | Native equivalent |
|---|---|
| `parseCreationOptionsFromJSON` | Creation options as Codable JSON |
| `navigator.credentials.create()` | The `register` scenario |
| `getAuthenticatorData()`, `getPublicKey()`, `getPublicKeyAlgorithm()`, `getTransports()` | Parsed fields on the result |
| `toJSON()` | Result as JSON |
| `AbortController.abort()` | Cancel button |

This brief also adds the mockup's **Registrations** and **History** tabs as engineering screens.

Ground rules: brief 01 §2 and the README apply. **Keep it lean:** build only what is listed here.

## 2. Assumptions

| Item | Value |
|---|---|
| RP | `rpId = "fidosims.example"`, origin `https://fidosims.example` (as in the mockup) |
| User verification | PIN is always used, as the mockup shows "PIN verified" |
| Attestation | Requested as `none`: the format is recorded, not verified (the mockup shows "Attestation: not requested") |
| Algorithm | ES256 only |
| Credential type | Non-discoverable by default; `rk` is an option |

## 3. Tasks

### T1 — New target `WebAuthn` (depends on `CTAP`, `PinUvAuth`): basics

- **Options as Codable JSON:**
  - creation options: `rp`, `user`, `challenge`, `pubKeyCredParams`, `authenticatorSelection`, `attestation`;
  - request options: `rpId`, `challenge`, `allowCredentials`, `userVerification`;
  - binary fields are base64url without padding.
- **clientDataJSON** uses the exact WebAuthn serialization: `{"type":"webauthn.create","challenge":"<b64url>","origin":"https://fidosims.example","crossOrigin":false}`.
  - Key order `type`, `challenge`, `origin`, `crossOrigin`; no whitespace. Authentication uses `webauthn.get`.
  - `clientDataHash = SHA-256(clientDataJSON)`.
- **authenticatorData parser** (study guide §6):
  - `rpIdHash`, flags (UP, UV, AT, ED), `signCount`;
  - for registration: AAGUID, credential ID, and the COSE key (its end is found with the bytes-consumed value from brief 02).
- **COSE ES256 key → CryptoKit `P256.Signing.PublicKey`.** Keep the original COSE bytes as well.

Acceptance:

- [ ] Golden test for the clientDataJSON bytes.
- [ ] Flag decoding for `0x41`, `0x45`, `0x05`.
- [ ] authData parsing with and without attested data.

### T2 — MakeCredential (Register)

**Request:**

- Parameters:
  - `0x01` clientDataHash;
  - `0x02` rp;
  - `0x03` user (`id` = 16 random bytes, `name` = username, `displayName`);
  - `0x04` pubKeyCredParams `[ES256]`;
  - `0x07` options;
  - `0x08` pinUvAuthParam;
  - `0x09` pinUvAuthProtocol = 2.
- **PIN token:** subcommand `0x09`, permission `mc` (`0x01`), rpId. Then `pinUvAuthParam = authenticate(token, clientDataHash)`.
- **options:** `{"rk": true}` only when rk is chosen; otherwise send no options.
  - Never send `up: false`.
  - Never send `uv` together with `pinUvAuthParam`.

**Response:**

- Decode `{1 fmt, 2 authData, 3 attStmt}`.
- Build the WebAuthn `attestationObject` (text keys `fmt`, `attStmt`, `authData`) for the JSON result.

**Result JSON** (the `toJSON()` equivalent):

- `id`, `rawId`, `type: "public-key"`;
- `response`: `clientDataJSON`, `attestationObject`, `authenticatorData`, `transports: ["nfc"]`, `publicKeyAlgorithm: -7`.

### T3 — GetAssertion (Authenticate)

**Request:**

- `0x01` rpId; `0x02` clientDataHash.
- `0x03` allowList, holding the stored credential ID of the selected registration.
- `0x06` pinUvAuthParam; `0x07` protocol 2.
- **PIN token:** permission `ga` (`0x02`), rpId.
- Do not send `rk`. Leave `up` at its default.

**Response:** decode `{1 credential, 2 authData, 3 signature, 4 user?}`.

**Result JSON:** `id`, `rawId`, `type`, `response` (`clientDataJSON`, `authenticatorData`, `signature`, `userHandle`).

### T4 — Minimal local RP

**Begin:** a 32-byte random challenge, plus the options built from the assumptions in §2.

**Registration checks** (each recorded as a named check: pass or fail, with a short detail):

- clientData `type`, challenge, origin;
- `rpIdHash == SHA-256(rpId)`;
- UP and UV flags set;
- AT present;
- key parses as ES256;
- credential ID not already stored;
- attestation `fmt` recorded (not verified).

**Authentication checks:**

- the credential is stored and not invalidated;
- clientData `type`, challenge, origin;
- `rpIdHash`; UP and UV set;
- **signature** over `authData ‖ clientDataHash` verifies with the stored key (DER signature, CryptoKit);
- **signCount:** if both the stored and the new value are non-zero, the new value must be greater. If either is zero, record "counter not used".

**On pass:** save or update the credential.

Acceptance:

- [ ] Unit tests for every check, positive and negative: tampered authData, wrong challenge, wrong origin, bad signature, non-increasing counter. Build the test data in the tests with a CryptoKit P-256 key.

### T5 — Credential store and Registrations [CONTRACT]

```swift
public struct StoredCredential: Codable, Sendable, Identifiable {
    public let id: UUID
    public let credentialId: Data
    public let rpId: String
    public let userHandle: Data
    public let username: String
    public let cardLabel: String
    public let publicKeyCOSE: Data
    public var signCount: UInt32
    public let discoverable: Bool
    public let attestationFormat: String
    public let createdAt: Date
    public var lastUsedAt: Date?
    public var invalidated: Bool
}
```

- **Storage:** a Codable JSON file in Application Support, written atomically.
- **Reset hook:** the brief 02 `onCardReset(cardLabel)` marks that card's credentials as `invalidated`.
- **Lab › Registrations:**
  - a list (username, card, created, last used, signCount, "invalidated" badge);
  - a detail view with the credential ID, public key, flags and AAGUID;
  - delete.

### T6 — Scenarios on the facade

```swift
public func register(_ request: RegistrationRequest, progress: …) async -> ScenarioResult<RegistrationOutcome>
public func authenticate(_ request: AuthenticationRequest, progress: …) async -> ScenarioResult<AuthenticationOutcome>
```

**Register:**

- Sequence: `SELECT_FIDO` → `GET_INFO` → `CLIENT_PIN_KEY_AGREEMENT` → `CLIENT_PIN_TOKEN` → `MAKE_CREDENTIAL`, then close the session, then RP checks + store.
- Progress steps: `waitingForCard` → `cardDetected` → `pinVerified` → `executing("Creating credential")` → `executing("Verify and save")` → `completed`. These match the mockup's step list.

**Authenticate:**

- Sequence: `SELECT_FIDO` → `GET_INFO` → `CLIENT_PIN_KEY_AGREEMENT` → `CLIENT_PIN_TOKEN` → `GET_ASSERTION`, then close the session, then RP checks + update.

**Both:**

- The outcome contains the result JSON, the list of checks and the stored credential.
- The trace uses the brief 01/02 format and metrics.

### T7 — History (the mockup's History tab)

- Every scenario run saves its trace as a file in Application Support.
- **Lab › History:**
  - a list of runs: scenario, time, card, outcome, transaction total;
  - opens the existing trace view;
  - export: text log and JSON;
  - delete.
- While a past run is open, the screen clearly shows which run it is, with a way back to the latest. (This is the agent's question 4 from brief 01.)

### T8 — Lab UI: Register and Authenticate

- **Register:**
  - username: manual or random (e.g. `nusa-042`);
  - PIN: default, custom or stored;
  - card label;
  - rk toggle.
- **Authenticate:** pick a registration from the store, PIN, card label.
  - Invalidated registrations can still be picked. They are shown with a warning, and the request is sent anyway so the card's answer can be checked after a reset.
- **While running:** the live step list and an elapsed-time counter.
- **Result:**
  - outcome;
  - transaction total, APDU total, exchanges;
  - the list of checks;
  - "View registration" / "View log"; export.

## 4. Definition of done

- [ ] T1–T8 are done.
- [ ] `swift test` passes on macOS.
- [ ] The app builds with no warnings in project code.
- [ ] `docs/trace-format.md` is updated if anything changed.
- [ ] The summary is posted.

## 5. Verified by Ikbal on device

- [ ] Register with PIN works: flags `0x45`, all checks pass, and the credential appears in Registrations.
- [ ] Authenticate with that credential works: flags `0x05`, the signature check passes, and signCount goes up (or note that the card always returns 0).
- [ ] All four features end to end on one spare card:
  1. register;
  2. authenticate;
  3. change PIN;
  4. authenticate with the new PIN;
  5. reset;
  6. authenticate again → fails with `0x2E`, and the registration shows "invalidated";
  7. set PIN.
- [ ] Every run appears in History, with per-command timing and transaction total, and its text log exports.
- [ ] Note the typical timings per feature and send them to the BU as a first indication.

## 6. Out of scope

- Attestation verification, discoverable-credential login, GetNextAssertion, excludeList, extensions, algorithms other than ES256.
- Everything in the README "Parked" list.
- Final UI. Android (descoped).
