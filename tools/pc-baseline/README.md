# PC/SC baseline recorder

Records `SELECT_FIDO` + `GET_INFO` against a FIDO card on a PC/SC reader and writes one trace per run,
in the same format as the app ([`docs/trace-format.md`](../../docs/trace-format.md)), with transport
`pcsc`. Use it as a baseline for the iPhone NFC timings.

The command sequence and chaining rules match the app: short-form command chaining, `61xx` GET
RESPONSE, a single `6Cxx` resend and `9100` NFCCTAP polling. Each `transmit` is timed with
`time.perf_counter_ns()`. `sessionStarted` is taken before `connect()` and `cardDetected` after it.

## Install

Python 3.10 or newer.

```sh
cd tools/pc-baseline
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
```

On Linux, pyscard needs `pcscd` and the `libpcsclite-dev` headers. On macOS, PC/SC is built in.

## List readers

```sh
python3 record_trace.py --list
# 0: ACS ACR1252 Dual Reader PICC 0
# 1: ACS ACR1252 Dual Reader SAM 0
```

## Record

Put the card on the reader, then:

```sh
python3 record_trace.py --reader PICC --label "Lab card A" --runs 10 --length-form short --out traces/
```

`--reader` takes an index from `--list` or a name substring that matches exactly one reader.
Other options: `--length-form extended` and `--get-response-supported` (NFCCTAP_MSG with P1 = `80`).

Output: one JSON per run in `traces/`, then a per-label summary of the logical command RTT (the sum of
its physical exchanges):

```
label        count  min ms  mean ms  p95 ms  max ms
SELECT_FIDO     10   8.240    9.418  10.021  10.021
GET_INFO        10  18.182   18.513  18.943  18.943
```

p95 uses the nearest-rank method.

## Without a reader

`--simulate` replaces the reader with a built-in scripted FIDO2 card (`FIDO_2_0`, GetInfo through a
`61xx` chain). `FIDOKit/Tests/CardCoreTests/Fixtures/synthetic/synthetic-pcsc-recorder.json` was
produced this way. It is synthetic, **not** a real card trace.

```sh
python3 record_trace.py --simulate --runs 1 --label "Synthetic PC/SC sample" --out /tmp/traces
```

Any trace written by this script can be replayed in the app or tests through `MockTransport`.
