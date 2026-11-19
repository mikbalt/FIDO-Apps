# Trace format (schema version 1)

**[CONTRACT]** Owned by Ikbal. Implemented by `CardCore/Trace` (Swift) and
`tools/pc-baseline/record_trace.py` (Python). Change only after agreement.

A trace records one card session: metadata plus ordered events. The same format is used for app
exports, PC/SC baseline recordings and `MockTransport` fixtures.

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
| `schemaVersion` | int | `1` |
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
| `exchange` | `index`, `commandIndex`, `label`, `tx`, `rx`, `sw`, `tStart`, `tEnd`, `sensitive` |
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

`reason` values written today: `completed`, `selectFailed`, `ctap1Only` (GetInfo returned `6D00`),
`getInfoFailed`, `cancelled`, `error`. Readers must accept unknown values.

### Redaction

Exports redact sensitive exchanges by default (`redactSensitive = true`). In a redacted export the
`tx` and `rx` of a sensitive exchange are written as `"<redacted N bytes>"`, where N is the byte count.
`sw` and the times are kept. Redacted traces decode, but `MockTransport` refuses to replay them.

## Metrics (provisional, pending the BU's answer)

| Metric | Definition |
|---|---|
| `cardWait` | `cardDetected − sessionStarted` |
| `apduTotal` | Σ (`tEnd − tStart`) over all exchanges |
| `sessionTotal` | `tEnd` of the last exchange − `sessionStarted` (includes waiting for the card) |
| `hostOverhead` | `sessionTotal − cardWait − apduTotal` (app processing + stack time between exchanges) |
| Per logical command | Σ RTT of its physical exchanges, plus the exchange count |

Values are displayed in milliseconds with 3 decimals, e.g. `12.400 ms` (rounded to the microsecond).
`sessionEnded.t` is not used by any metric.

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
- An empty response is shown as `RX - | SW 6A82`. A metric that cannot be computed is shown as `-`.
- `1 exchange` is singular.
- In Safe mode and in redacted exports, sensitive bytes are shown as `<redacted N bytes>`.
- The format is pinned by `FIDOKit/Tests/CardCoreTests/Fixtures/golden/`.
