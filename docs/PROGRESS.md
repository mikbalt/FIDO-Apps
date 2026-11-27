# Progress

Last updated: 27 Nov 2026. The backlog lives in [GitHub issues](https://github.com/mikbalt/FIDO-Apps/issues);
this page is the overview. Update it at the end of every brief or issue (`/report-progress`).

## Briefs

| Brief | Code | On device (Ikbal) | Notes |
|---|---|---|---|
| [01 Foundation](briefs/01-foundation.md) | Done (T1–T7) | Pending — [#1](https://github.com/mikbalt/FIDO-Apps/issues/1) | T7 PC recorder is optional and done |
| [02 CTAP + PIN](briefs/02-ctap-pin.md) | Done (T1–T10), on `main` | Pending — [#2](https://github.com/mikbalt/FIDO-Apps/issues/2) | Change PIN, Set PIN, Reset |
| [03 Register + Authenticate](briefs/03-register-authenticate.md) | Part A done: T1–T4 (SDK only), on branch `brief/03-register-authenticate` | Not verified on the card — started before the #2 sign-off, by the owner's approval | Part B (T5–T8: store, facade, History, UI) not started — tracking [#7](https://github.com/mikbalt/FIDO-Apps/issues/7) |
| 04 Final UI | Not written | — | Waits for the UI/UX team |

Kickoff features: Change PIN ✅ code, Reset ✅ code, Register ⏳ brief 03, Authentication ⏳ brief 03.
None is "done" until checked on the IDEMIA card.

## Brief 02 — task status

| Task | Status | Where |
|---|---|---|
| T1 CBOR (`CTAP` target) | Done | `FIDOKit/Sources/CTAP/CBOR` |
| T2 CTAP client | Done | `CTAP/Client` |
| T3 GetInfo + Decoded view | Done; Decoded view checked in the Simulator | `CTAP/Commands/GetInfo`, `CTAP/Decoding`, `App/.../Components/DecodedTraceView.swift` |
| T4 PIN protocol 2 (`PinUvAuth`) | Done | `PinUvAuth/Protocol` |
| T5 authenticatorClientPIN | Done | `PinUvAuth/ClientPIN` |
| T6 `FIDOSimulator` facade | Done | `FIDOKit/Simulator` |
| T7 Scenarios | Done | `FIDOSimulator.swift` |
| T8 Store PIN (Keychain) | Done; no automated test yet — [#3](https://github.com/mikbalt/FIDO-Apps/issues/3) | `FIDOKit/PINStore` |
| T9 Trace additions (v2) | Done | `CardCore/Trace`, `docs/trace-format.md` |
| T10 Lab UI | Done; checked in the Simulator | `App/FIDOSims/Features/Lab` |

Checks at the end of brief 02: `swift test` 131 tests pass; app builds for the Simulator and a generic
iOS device (unsigned) with no warnings in project code.

## Brief 03 — task status

Part A started before the on-device sign-off of Brief 02 ([#2](https://github.com/mikbalt/FIDO-Apps/issues/2)), with the owner's approval.
**Nothing here is verified on the card**; no "Verified by Ikbal on device" box is ticked.

| Task | Status | Where |
|---|---|---|
| T1 WebAuthn target | Done (unit tests only) — [#9](https://github.com/mikbalt/FIDO-Apps/issues/9) | `FIDOKit/Sources/WebAuthn` (`Options`, `ClientData`, `AuthenticatorData`, `Support`) |
| T2 MakeCredential | Done against `FakeAuthenticator` only | `WebAuthn/Commands`, `WebAuthn/Results` |
| T3 GetAssertion | Done against `FakeAuthenticator` only | `WebAuthn/Commands`, `WebAuthn/Results` |
| T4 Minimal local RP | Done (named checks, positive and negative tests) | `WebAuthn/RelyingParty` |
| T5–T8 | Not started (part B) | — |

`LocalRelyingParty` takes a `KnownCredential` (id, COSE key, signCount, invalidated) so the `StoredCredential`
contract in T5 is untouched; T5 maps its records to it.

## Open work

| Issue | What | Who |
|---|---|---|
| [#1](https://github.com/mikbalt/FIDO-Apps/issues/1) | Brief 01 sign-off on device | Ikbal |
| [#2](https://github.com/mikbalt/FIDO-Apps/issues/2) | Brief 02 sign-off on device; GetInfo values to the card team | Ikbal |
| [#3](https://github.com/mikbalt/FIDO-Apps/issues/3) | Automated test for `KeychainPINStore` | Agent (`agent-ready`) |
| [#4](https://github.com/mikbalt/FIDO-Apps/issues/4) | App test target for the Lab view models | Agent (`agent-ready`) |
| [#5](https://github.com/mikbalt/FIDO-Apps/issues/5) | Lab UI polish from the Simulator check | Agent (`agent-ready`) |
| [#6](https://github.com/mikbalt/FIDO-Apps/issues/6) | Decide: replay of exported PIN-scenario traces | Ikbal (decision) |
| [#7](https://github.com/mikbalt/FIDO-Apps/issues/7) | Brief 03 tracking | Agent, after #2 |

## Open decisions (from the briefs README)

| Decision | From | Assumption until answered |
|---|---|---|
| Which number is the "transaction total" | BU | `sessionTotal` (start of the NFC session to the last exchange) |
| PIN protocol, default PIN, reset over NFC | Card team | Protocol 2; `1234` only as a UI default; reset may be refused |
| Sharing real card traces with the agent | IT/security | Synthetic fixtures only |
| Final UI | UI/UX team | Engineering screens only |

## Known limitations

- PIN and Reset screens need NFC and a real card; there is no mock for them in the Simulator.
- Traces from PIN scenarios cannot be replayed (redacted, and PIN protocol 2 is randomized) — see #6.
- `onCardReset` is wired but does nothing until brief 03 T5.
- MakeCredential and GetAssertion have only run against `FakeAuthenticator`. The real card may differ (e.g. signCount always 0, flags, attestation format).
- Each Lab screen keeps its last 10 runs in memory only; persistence comes with brief 03 T7.
