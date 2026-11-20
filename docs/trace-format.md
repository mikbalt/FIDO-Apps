# Trace format (schema version 2)

**[CONTRACT]** Owned by Ikbal. Implemented by `CardCore/Trace` (Swift) and
`tools/pc-baseline/record_trace.py` (Python). Change only after agreement.

A trace records one card session: metadata plus ordered events. The same format is used for app
exports, PC/SC baseline recordings and `MockTransport` fixtures.

**Versions.** The app writes `schemaVersion: 2` (brief 02, T9). Version 2 only *adds* optional fields and
one event type to version 1, listed in [Version 2 additions](#version-2-additions). Readers accept 1 and 2
and refuse anything else with a clear error. v1 traces (including the PC recorder's) decode unchanged,
and the metrics are the same for both versions.

## Example

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

## Fields

| Field | Type | Notes |
|---|---|---|
| `schemaVersion` | int | `2` (`1` for older traces and the PC recorder) |
| `id` | UUID string | Unique per trace |
| `createdAt` | ISO 8601 string | Wall-clock time in UTC, whole seconds. **Display only**, never used for timing |
| `app` | `{name, version, build}` | Producer. The PC recorder writes `fidosims-pc-baseline` |
| `transport` | `nfc` \| `mock` \| `pcsc` | |
| `device` | `{model, os}` | iPhone hardware identifier and OS. For `pcsc`: reader name and host OS |
| `card.label` | string | Free text entered by the tester |
| `card.initialSelectedAID` | hex string or `null` | AID the OS selected during discovery (see the note below). `null` for PC/SC |
| `options` | `{lengthForm, getResponseSupported}` | `lengthForm` is `short` or `extended` |
| `events` | array | Ordered; see below |

### Events

All times (`t`, `tStart`, `tEnd`) are **monotonic nanoseconds since `sessionStarted`** (Int64), taken
from `ContinuousClock` on iOS and `time.perf_counter_ns()` on the PC.

| `type` | Fields |
|---|---|
| `sessionStarted` | `t` (always `0`) |
| `cardDetected` | `t` |
| `exchange` | `index`, `commandIndex`, `label`, `tx`, `rx`, `sw`, `tStart`, `tEnd`, `sensitive`; when redacted also `txLength`, `rxLength`, `redacted` |
| `warning` | `t`, `code`, `message` (v2) |
| `sessionEnded` | `t`, `reason` |

`exchange` fields:

- `index`: 1-based; counts **physical** APDUs in the session.
- `commandIndex`, `label`: the **logical** command the exchange belongs to, e.g. `SELECT_FIDO`, `GET_INFO`.
  A logical command spans several exchanges with chaining, `61xx` GET RESPONSE, `6Cxx` resend or
  `9100` NFCCTAP polling.
- `tx`: the exact bytes sent. `rx`: response data without the status word. `sw`: the status word.
  Hex strings are uppercase with no spaces. An empty `rx` is `""`.
- `tStart` / `tEnd`: taken by the transport immediately before and after the I/O call.
- `sensitive`: the exchange carries secrets (ClientPIN, from brief 02 on).
- `ctapStatus` (v2, optional): the CTAP status byte as two hex digits, e.g. `"00"` or `"31"`. Set only on
  the exchange that completes a CTAP command, i.e. the last exchange of an NFCCTAP_MSG command whose final
  SW is `9000`.

#### GET RESPONSE is always short form

The follow-up commands the channel sends on its own, `GET RESPONSE` (`00 C0 00 00 xx`, after `61xx`)
and `NFCCTAP_GETRESPONSE` (`80 11 00 00 00`, after `9100`), are **always sent in short form**, whatever
`options.lengthForm` the run uses. `lengthForm` applies to the logical commands only (`SELECT_FIDO` is
also always short). Both the app and the PC recorder follow this rule, so their traces replay against
each other.

#### `sessionEnded.reason`

A closed set. Each `CardError` case maps to exactly one value.

| `reason` | Meaning |
|---|---|
| `completed` | The scenario ran to the end |
| `selectFailed` | SELECT did not return `9000` with a known version string; later commands skipped |
| `ctap1Only` | GetInfo returned `6D00` (CTAP1/U2F-only card) |
| `getInfoFailed` | GetInfo returned another SW, or a non-zero CTAP status byte |
| `cancelled` | The run's task was cancelled (the app's Cancel button) |
| `userCancelled` | `CardError.userCancelled`: the user dismissed the system NFC sheet |
| `sessionTimeout` | `CardError.sessionTimeout`: the system ended the reader session (iOS 60 s limit) |
| `tagConnectionLost` | `CardError.tagConnectionLost` |
| `nfcUnavailable` | `CardError.nfcUnavailable` |
| `invalidAPDU` | `CardError.invalidAPDU`: the command bytes could not be wrapped as an APDU |
| `notConnected` | `CardError.notConnected` |
| `transportError` | `CardError.underlying`: any other transport error |
| `error` | Any other error: channel protocol errors (chaining, `9100` timeout), `MockTransport` mismatch |

In the brief 02 scenarios (Set PIN, Change PIN, Reset), a card that answers with a non-zero CTAP status
(e.g. `0x31` wrong PIN) or a PIN refused before sending ends the session as `completed`: the session itself
worked. The failure is in `outcome`.

The PC recorder writes only `completed`, `selectFailed`, `ctap1Only`, `getInfoFailed` and `error`.
**Readers must accept unknown values**, so later versions can add some without breaking older readers.
The Swift decoder keeps them as `SessionEndReason.unknown(raw)` and writes them back unchanged.

### Redaction

JSON exports redact sensitive exchanges by default (`redactSensitive = true`). A redacted exchange has
`"tx": null` and `"rx": null`, the byte counts in `txLength` and `rxLength`, and `"redacted": true`.
`sw`, the times and `sensitive` are kept. A non-redacted exchange has no `txLength`, `rxLength` or
`redacted` field. JSON never contains the `<redacted N bytes>` placeholder: that is only for the text
log and the Safe view.

```json
{ "type": "exchange", "index": 3, "commandIndex": 3, "label": "CLIENT_PIN",
  "tx": null, "rx": null, "txLength": 85, "rxLength": 2, "redacted": true,
  "sw": "9000", "tStart": 1530100000, "tEnd": 1561300000, "sensitive": true }
```

Redacted traces decode, so they can be inspected and their metrics computed, but `MockTransport` refuses
to replay a trace with any redacted exchange (`MockTransportError.redactedTrace`), because the bytes to
compare and answer with are missing.

## Version 2 additions

All fields are optional for readers; the app always writes them in v2 traces.

| Field | Type | Notes |
|---|---|---|
| `scenario` | string | `diagnostics`, `setPIN`, `changePIN`, `reset`, `register`, `authenticate`. Readers keep unknown values |
| `outcome` | `{status, error?}` | `status` is `success`, `failure` or `cancelled`. `error` is present for `failure` |
| `outcome.error` | `{domain, code, name, message}` | See below |
| `card.aaguid` | UUID string | From GetInfo, uppercase, e.g. `2FC0579F-8113-47EA-B116-BB5A8DB9202A` |
| `card.versions` | array of strings | From GetInfo, e.g. `["FIDO_2_0", "FIDO_2_1"]` |
| `card.firmwareVersion` | int | From GetInfo, when the card reports it |
| `exchange.ctapStatus` | hex string | See `exchange` fields above |
| `warning` event | `{t, code, message}` | Something worth reporting that did not stop the scenario |

The `card` fields are written only after GetInfo succeeded, and omitted otherwise.

**`outcome.error`.** `domain` says which layer failed; `code` is a string whose form depends on it; `name`
is a stable symbolic name; `message` is human-readable.

| `domain` | `code` | `name` example |
|---|---|---|
| `transport` | the `sessionEnded.reason`, e.g. `tagConnectionLost` | `TAG_CONNECTION_LOST` |
| `iso7816` | the status word, e.g. `6A82` | `FILE_NOT_FOUND` |
| `ctap` | the status byte, e.g. `0x31` | `CTAP2_ERR_PIN_INVALID` |
| `validation` | an identifier, e.g. `pinTooShort` | `PIN_TOO_SHORT` |
| `rp` | an identifier (brief 03) | |
| `internal` | an identifier, e.g. `unexpectedCommand` | `MOCK_UNEXPECTED_COMMAND` |

**Warning codes.** An open set; readers keep unknown codes.

| `code` | Meaning |
|---|---|
| `EXTENDED_FORM_CHAINED` | The card answered an extended-form command with `61xx` instead of returning all data at once |

### v2 example

```json
{
  "schemaVersion": 2,
  "id": "6F1C2D3E-0000-4000-8000-0000000000C2",
  "createdAt": "2026-11-20T00:00:00Z",
  "app": { "name": "FIDOSims", "version": "0.2.0", "build": "1" },
  "transport": "nfc",
  "device": { "model": "iPhone16,2", "os": "iOS 26.1" },
  "scenario": "changePIN",
  "outcome": { "status": "failure",
               "error": { "domain": "ctap", "code": "0x31", "name": "CTAP2_ERR_PIN_INVALID",
                          "message": "The PIN is wrong. 7 retries left." } },
  "card": { "label": "Lab card A", "initialSelectedAID": "A0000006472F0001",
            "aaguid": "2FC0579F-8113-47EA-B116-BB5A8DB9202A", "versions": ["FIDO_2_0", "FIDO_2_1"] },
  "options": { "lengthForm": "short", "getResponseSupported": false },
  "events": [
    { "type": "sessionStarted", "t": 0 },
    { "type": "cardDetected", "t": 1503000000 },
    { "type": "exchange", "index": 5, "commandIndex": 5, "label": "CLIENT_PIN_CHANGE",
      "tx": null, "rx": null, "txLength": 150, "rxLength": 1, "redacted": true,
      "sw": "9000", "tStart": 1600100000, "tEnd": 1702300000, "sensitive": true, "ctapStatus": "31" },
    { "type": "sessionEnded", "t": 1750000000, "reason": "completed" }
  ]
}
```

(Exchanges 1–4 are omitted for brevity.) `sessionEnded.reason` describes the card session; `outcome`
describes the scenario as the user saw it. A wrong PIN is a completed session with a failed outcome.

## Metrics

| Metric | Definition |
|---|---|
| `cardWait` | `cardDetected − sessionStarted` |
| `apduTotal` | Σ (`tEnd − tStart`) over all exchanges |
| `sessionTotal` | `tEnd` of the last exchange − `sessionStarted` (includes waiting for the card) |
| `hostOverhead` | `sessionTotal − cardWait − apduTotal` (app processing + stack time between exchanges) |
| Per logical command | Σ RTT of its physical exchanges, plus the exchange count |

Values are displayed in milliseconds with 3 decimals, e.g. `12.400 ms` (rounded to the microsecond).
`sessionEnded.t` is not used by any metric. `sessionTotal` deliberately ends at the last exchange: ending
at `sessionEnded` would include the iOS "Done" alert and the sheet dismissal, which are not part of the
transaction. These definitions are fixed; the BU only chooses which one is the headline "transaction
total". Session close will get its own segment, `postSession`, in trace v2 (brief 02).

> **iOS note.** CoreNFC sends its own SELECT for the first matching AID from
> `com.apple.developer.nfc.readersession.iso7816.select-identifiers` during discovery, before handing
> the tag to the app. That time falls inside `cardWait`, not inside any exchange. This is why
> `initialSelectedAID` is recorded. The app's own `SELECT_FIDO` is a second SELECT and is timed normally.

## Text log

```
FIDOSims trace <id> | <transport> | <device model> <os> | <card label>
01 SELECT_FIDO
TX 00 A4 04 00 08 A0 00 00 06 47 2F 00 01 00
RX 46 49 44 4F 5F 32 5F 30 | SW 9000
RTT 12.400 ms
...
Session total 1842.700 ms | Card wait 1503.000 ms | APDU total 319.500 ms | Host 20.200 ms | 8 exchanges
```

- One block per **physical** exchange; the number is the exchange `index` (two digits minimum).
- v2: the header ends with `| <scenario> <outcome status>`, plus `<domain> <error name>` on failure.
  An exchange with `ctapStatus` is followed by `CTAP status XX`. Each warning is a line
  `WARN <code>: <message>`, in event order.
- An empty response is shown as `RX - | SW 6A82`. A metric that cannot be computed is shown as `-`.
- `1 exchange` is singular.
- In Safe mode and in redacted exports, sensitive bytes are shown as `<redacted N bytes>`.
- The format is pinned by `FIDOKit/Tests/CardCoreTests/Fixtures/golden/`.
