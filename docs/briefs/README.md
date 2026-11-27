# FIDOSims — agent briefs

Owner: Mokhamad Ikbal Taqyudin · Last updated: 19 Nov 2026

The kickoff asks for **four features**, each with timing per command-response and in total:

1. Register / add a card
2. Authentication
3. Change the card PIN
4. Reset the card

These briefs deliver exactly that, on iOS, in three steps. Anything beyond it is in the **Parked** list and is built only if the BU asks for it.

## How to work with these briefs

1. **One brief at a time, in order.** Do not start the next brief until Ikbal has signed off the "Verified by Ikbal on device" checklist of the current one.
2. **Git.** Use one branch per brief (`brief/0N-<name>`) and one commit per task.
3. **Report.** End each brief with a summary: what changed, the decisions you made, and open questions.
4. **Ground rules.** The ground rules in brief 01 §2 apply to every brief.
5. **Keep it lean.** Build what the brief asks for and nothing more. If something extra seems necessary, ask first.

## Scope

- **iOS only.** Android is descoped. Do not build anything for it.
- **Final UI is waiting on the UI/UX team.**
  - Until it arrives, every screen is an engineering screen under `Features/Lab/`: functional, plain SwiftUI, no visual polish.
  - Keep all logic in the SDK facade (`FIDOSimulator`) and in ViewModels, so the final UI only replaces Views.
- **No third-party SDKs (including YubiKit).** Everything is built in-house on Apple frameworks only (CoreNFC, CryptoKit, CommonCrypto, Security), for compliance and ease of audit, and for full control of per-APDU timing and the trace format. Algorithms: ECDH P-256, HKDF-SHA256, AES-256-CBC with random IV, HMAC-SHA256, SHA-256 left 16 bytes (PIN hash); ES256 is added in brief 03.
- **Direct CTAP over NFC.** The app talks CTAP to the card itself, because that is the only way to time each command. No ASAuthorization or platform passkey APIs.
- **Timing = what the mockup shows.** Per-command RTT, transaction total (including the wait for the card), APDU total and number of exchanges. Shown on screen and exported as a text log.

## Sequence

| Brief | Delivers | Kickoff features |
|---|---|---|
| [01 Foundation](01-foundation.md) (in progress) | Workspace, APDU layer + chaining, NFC transport, per-APDU timing, trace + text export, diagnostics screen | — |
| [02 CTAP + PIN](02-ctap-pin.md) | CBOR, CTAP client, GetInfo, PIN protocol 2, ClientPIN, `FIDOSimulator` facade | **Change PIN**, **Reset** (+ Set PIN, needed after a reset) |
| [03 Register + Authenticate](03-register-authenticate.md) | MakeCredential, GetAssertion, minimal local RP, credential store, Registrations and History | **Register**, **Authentication** |
| 04 Final UI | Written when the UI/UX team delivers | All four, final look |

## Parked — only if the BU asks

- Repeated runs (campaigns) with statistics, CSV export.
- Comparison with the PC reader / test bench (Python tooling, python-fido2 test vectors).
- Negative test suite and raw APDU console.
- Attestation verification (certificate chains). The mockup says "Attestation: not requested".
- Discoverable credentials and GetNextAssertion; extensions; EdDSA.
- PIN protocol 1, unless the card does not support protocol 2.
- Software authenticator for development without a card.
- ML-DSA (post-quantum, e.g. ML-DSA-65): only if the card reports support in GetInfo `algorithms` and the BU asks. Keys and signatures are far larger (public key ~1.9 KB, signature ~3.3 KB), so authData parsing and storage must not assume fixed key sizes.

## Open decisions

| Decision | From | Assumption until answered |
|---|---|---|
| Which number is the "transaction total" | BU | From the start of the NFC session to the last exchange (`sessionTotal`) |
| PIN protocol, default PIN, reset allowed over NFC | Card team | Protocol 2; default PIN only as a UI default; reset may be refused |
| Sharing real card traces with the agent | IT/security | Synthetic fixtures only |
| Final UI | UI/UX team | Engineering screens only |

## Contracts owned by Ikbal

The agent implements these as written and asks before changing them.

| Contract | Defined in |
|---|---|
| `CardTransport` API | 01 |
| Trace format and metrics | 01, small additions in 02 |
| `FIDOSimulator` facade and progress steps | 02 |
| `StoredCredential` / `CredentialStore` | 03 |

## Testing approach

- Unit tests cover what can be tested without a card: APDU encoding, chaining, CBOR, parsing, the crypto building blocks, RP checks.
- **The real card is the reference.** A feature is done when it works on the IDEMIA card on an iPhone, as checked by Ikbal.
- Synthetic fixtures live under `Fixtures/synthetic/`. Real traces go under `Fixtures/real/`, added only by Ikbal after IT/security approval.

## Engineering UI map (`Features/Lab/`)

| Screen | Brief |
|---|---|
| Diagnostics (Hex / Safe / Decoded) | 01, 02 |
| Change PIN, Set PIN, Reset | 02 |
| Register, Authenticate, Registrations, History | 03 |
