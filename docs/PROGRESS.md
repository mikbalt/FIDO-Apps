# Progress

Last updated: 20 Nov 2026. The backlog lives in [GitHub issues](https://github.com/mikbalt/FIDO-Apps/issues);
this page is the overview. Update it at the end of every brief or issue (`/report-progress`).

## Briefs

| Brief | Code | On device (Ikbal) | Notes |
|---|---|---|---|
| [01 Foundation](briefs/01-foundation.md) | Done (T1–T7) | Pending — [#1](https://github.com/mikbalt/FIDO-Apps/issues/1) | T7 PC recorder is optional and done |
| [02 CTAP + PIN](briefs/02-ctap-pin.md) | Done (T1–T10), on `main` | Pending — [#2](https://github.com/mikbalt/FIDO-Apps/issues/2) | Change PIN, Set PIN, Reset |
| [03 Register + Authenticate](briefs/03-register-authenticate.md) | Not started | — | Blocked on #2 — tracking [#7](https://github.com/mikbalt/FIDO-Apps/issues/7) |
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
- Each Lab screen keeps its last 10 runs in memory only; persistence comes with brief 03 T7.
