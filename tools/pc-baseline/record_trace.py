#!/usr/bin/env python3
"""Record SELECT_FIDO + GET_INFO traces over PC/SC, in the FIDOSims trace format.

Same sequence and chaining rules as FIDODiagnostics in the app (61xx, 6Cxx, 9100).
See docs/trace-format.md.
"""

from __future__ import annotations

import argparse
import json
import math
import platform
import sys
import time
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

APP = {"name": "fidosims-pc-baseline", "version": "0.1.0", "build": "1"}
FIDO_AID = bytes.fromhex("A0000006472F0001")
KNOWN_VERSIONS = {"U2F_V2", "FIDO_2_0"}
SW_SUCCESS = 0x9000
SW_INS_NOT_SUPPORTED = 0x6D00
SW_STATUS_UPDATE = 0x9100
NFCCTAP_GETRESPONSE = bytes.fromhex("8011000000")


class ChannelError(Exception):
    pass


# --- APDU encoding (mirrors CardCore.CommandAPDU) ---------------------------------------------


def encode_apdu(cla: int, ins: int, p1: int, p2: int, data: bytes = b"", le: int | None = None,
                form: str = "short") -> bytes:
    max_lc, max_le = (255, 256) if form == "short" else (65535, 65536)
    if len(data) > max_lc:
        raise ValueError(f"data of {len(data)} bytes does not fit {form} form")
    if le is not None and not 1 <= le <= max_le:
        raise ValueError(f"Le {le} out of range for {form} form")
    out = bytearray([cla, ins, p1, p2])
    if form == "short":
        if data:
            out += bytes([len(data)]) + data
        if le is not None:
            out.append(le & 0xFF)  # 256 -> 00
    else:
        if data:
            out += b"\x00" + len(data).to_bytes(2, "big") + data
        if le is not None:
            if not data:
                out.append(0x00)
            out += (le & 0xFFFF).to_bytes(2, "big")  # 65536 -> 00 00
    return bytes(out)


# --- Card connections -----------------------------------------------------------------------


class PcscConnection:
    """A pyscard connection. pyscard is imported lazily so --simulate works without it."""

    def __init__(self, reader):
        self.reader = reader
        self.connection = reader.createConnection()

    @property
    def name(self) -> str:
        return str(self.reader)

    def connect(self) -> None:
        self.connection.connect()

    def transmit(self, command: bytes) -> tuple[bytes, int]:
        data, sw1, sw2 = self.connection.transmit(list(command))
        return bytes(data), (sw1 << 8) | sw2

    def disconnect(self) -> None:
        try:
            self.connection.disconnect()
        except Exception:  # noqa: BLE001 - best effort on teardown
            pass


class SimulatedFido2Card:
    """A scripted FIDO2 card for producing sample traces without a reader. Not a real card."""

    name = "Simulated reader"
    # SELECT -> FIDO_2_0; GET_INFO -> status 00 + a small CBOR map, returned through a 61xx chain.
    _getinfo = bytes.fromhex("00A10182665532465F5632684649444F5F325F30")

    def __init__(self) -> None:
        self._pending = b""

    def connect(self) -> None:
        time.sleep(0.05)

    def transmit(self, command: bytes) -> tuple[bytes, int]:
        time.sleep(0.008)
        if command == encode_apdu(0x00, 0xA4, 0x04, 0x00, FIDO_AID, 256):
            return b"FIDO_2_0", SW_SUCCESS
        if command[:2] == b"\x80\x10":
            self._pending = self._getinfo
            return self._next_chunk(8)
        if command[:2] == b"\x00\xC0":
            return self._next_chunk(command[4] or 256)
        return b"", SW_INS_NOT_SUPPORTED

    def _next_chunk(self, size: int) -> tuple[bytes, int]:
        chunk, self._pending = self._pending[:size], self._pending[size:]
        if self._pending:
            return chunk, 0x6100 | min(len(self._pending), 0xFF)
        return chunk, SW_SUCCESS

    def disconnect(self) -> None:
        pass


# --- Recording ------------------------------------------------------------------------------


@dataclass
class Recorder:
    session_started_ns: int
    events: list[dict] = field(default_factory=list)
    exchange_count: int = 0
    command_count: int = 0

    def offset(self, ns: int) -> int:
        return ns - self.session_started_ns

    def next_command(self) -> int:
        self.command_count += 1
        return self.command_count

    def record(self, command_index: int, label: str, tx: bytes, rx: bytes, sw: int,
               t_start: int, t_end: int) -> None:
        self.exchange_count += 1
        self.events.append({
            "type": "exchange", "index": self.exchange_count, "commandIndex": command_index,
            "label": label, "tx": tx.hex().upper(), "rx": rx.hex().upper(), "sw": f"{sw:04X}",
            "tStart": self.offset(t_start), "tEnd": self.offset(t_end), "sensitive": False,
        })


class Channel:
    """Mirrors CardCore.ISO7816Channel: chaining, 61xx, one 6Cxx resend, 9100 polling."""

    def __init__(self, card, recorder: Recorder, form: str, status_timeout_s: float = 30.0):
        self.card, self.recorder, self.form = card, recorder, form
        self.status_timeout_ns = int(status_timeout_s * 1e9)

    def _exchange(self, command_index: int, label: str, tx: bytes) -> tuple[bytes, int]:
        t_start = time.perf_counter_ns()
        rx, sw = self.card.transmit(tx)
        t_end = time.perf_counter_ns()
        self.recorder.record(command_index, label, tx, rx, sw, t_start, t_end)
        return rx, sw

    def send(self, cla, ins, p1, p2, data: bytes, le: int | None, label: str,
             form: str | None = None) -> tuple[bytes, int]:
        form = form or self.form
        index = self.recorder.next_command()
        if form == "short" and len(data) > 255:
            chunks = [data[i:i + 255] for i in range(0, len(data), 255)]
            for number, chunk in enumerate(chunks[:-1], start=1):
                _, sw = self._exchange(index, label, encode_apdu(cla | 0x10, ins, p1, p2, chunk, None, form))
                if sw != SW_SUCCESS:
                    raise ChannelError(f"chained command failed at chunk {number} with SW {sw:04X}")
            data = chunks[-1]
        rx, sw = self._exchange(index, label, encode_apdu(cla, ins, p1, p2, data, le, form))
        if sw >> 8 == 0x6C:
            le = (sw & 0xFF) or 256
            rx, sw = self._exchange(index, label, encode_apdu(cla, ins, p1, p2, data, le, form))

        result = b""
        deadline = None
        while True:
            if sw >> 8 == 0x61:
                result += rx
                rx, sw = self._exchange(index, label, encode_apdu(0x00, 0xC0, 0x00, 0x00, le=(sw & 0xFF) or 256))
            elif sw == SW_STATUS_UPDATE:
                deadline = deadline or time.perf_counter_ns() + self.status_timeout_ns
                if time.perf_counter_ns() >= deadline:
                    raise ChannelError("card did not finish processing in time (9100)")
                rx, sw = self._exchange(index, label, NFCCTAP_GETRESPONSE)
            else:
                break
        return result + rx, sw


def record_run(card, label: str, form: str, get_response_supported: bool) -> dict:
    session_started = time.perf_counter_ns()
    card.connect()
    card_detected = time.perf_counter_ns()
    recorder = Recorder(session_started)
    recorder.events += [{"type": "sessionStarted", "t": 0},
                        {"type": "cardDetected", "t": recorder.offset(card_detected)}]
    channel = Channel(card, recorder, form)
    try:
        reason = run_select_and_getinfo(channel, get_response_supported)
    except ChannelError as error:
        print(f"  error: {error}", file=sys.stderr)
        reason = "error"
    finally:
        card.disconnect()
    last = max([e["tEnd"] for e in recorder.events if e["type"] == "exchange"], default=0)
    recorder.events.append({"type": "sessionEnded",
                            "t": max(recorder.offset(time.perf_counter_ns()), last), "reason": reason})
    return {
        "schemaVersion": 1,
        "id": str(uuid.uuid4()).upper(),
        "createdAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "app": APP,
        "transport": "pcsc",
        "device": {"model": card.name, "os": host_os()},
        "card": {"label": label, "initialSelectedAID": None},
        "options": {"lengthForm": form, "getResponseSupported": get_response_supported},
        "events": recorder.events,
    }


def run_select_and_getinfo(channel: Channel, get_response_supported: bool) -> str:
    rx, sw = channel.send(0x00, 0xA4, 0x04, 0x00, FIDO_AID, 256, "SELECT_FIDO", form="short")
    if sw != SW_SUCCESS or rx.decode("ascii", "replace") not in KNOWN_VERSIONS:
        return "selectFailed"
    max_le = 256 if channel.form == "short" else 65536
    rx, sw = channel.send(0x80, 0x10, 0x80 if get_response_supported else 0x00, 0x00, b"\x04", max_le, "GET_INFO")
    if sw == SW_INS_NOT_SUPPORTED:
        return "ctap1Only"
    if sw != SW_SUCCESS or not rx or rx[0] != 0x00:
        return "getInfoFailed"
    return "completed"


# --- Summary --------------------------------------------------------------------------------


def summarize(traces: list[dict]) -> str:
    """Per logical command label: count, min, mean, p95 (nearest rank), max RTT in ms."""
    rtts: dict[str, list[int]] = {}
    for trace in traces:
        per_command: dict[int, tuple[str, int]] = {}
        for event in trace["events"]:
            if event["type"] == "exchange":
                label, total = per_command.get(event["commandIndex"], (event["label"], 0))
                per_command[event["commandIndex"]] = (label, total + event["tEnd"] - event["tStart"])
        for label, total in per_command.values():
            rtts.setdefault(label, []).append(total)

    def ms(ns: float) -> str:
        return f"{ns / 1e6:.3f}"

    rows = [("label", "count", "min ms", "mean ms", "p95 ms", "max ms")]
    for label, values in rtts.items():
        values.sort()
        p95 = values[max(math.ceil(0.95 * len(values)) - 1, 0)]
        rows.append((label, str(len(values)), ms(values[0]), ms(sum(values) / len(values)), ms(p95), ms(values[-1])))
    widths = [max(len(row[i]) for row in rows) for i in range(len(rows[0]))]
    return "\n".join("  ".join(cell.ljust(width) if i == 0 else cell.rjust(width)
                               for i, (cell, width) in enumerate(zip(row, widths))) for row in rows)


# --- CLI ------------------------------------------------------------------------------------


def host_os() -> str:
    if platform.system() == "Darwin":
        return f"macOS {platform.mac_ver()[0]}"
    return f"{platform.system()} {platform.release()}"


def pcsc_readers() -> list:
    try:
        from smartcard.System import readers
    except ImportError:
        sys.exit("pyscard is not installed: pip install -r requirements.txt")
    return readers()


def pick_reader(spec: str):
    available = pcsc_readers()
    if not available:
        sys.exit("No PC/SC readers found.")
    if spec.isdigit():
        index = int(spec)
        if index >= len(available):
            sys.exit(f"Reader index {index} out of range (0-{len(available) - 1}).")
        return available[index]
    matches = [r for r in available if spec.lower() in str(r).lower()]
    if len(matches) != 1:
        sys.exit(f"'{spec}' matches {len(matches)} readers; use --list and pass an index.")
    return matches[0]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--list", action="store_true", help="list PC/SC readers and exit")
    parser.add_argument("--reader", help="reader index or name substring (see --list)")
    parser.add_argument("--label", default="Lab card A", help="card label stored in each trace")
    parser.add_argument("--runs", type=int, default=10)
    parser.add_argument("--length-form", choices=["short", "extended"], default="short")
    parser.add_argument("--get-response-supported", action="store_true", help="send NFCCTAP_MSG with P1 = 80")
    parser.add_argument("--out", type=Path, default=Path("traces"))
    parser.add_argument("--simulate", action="store_true",
                        help="use a built-in simulated FIDO2 card instead of a reader (for sample fixtures)")
    args = parser.parse_args()

    if args.list:
        for index, reader in enumerate(pcsc_readers()):
            print(f"{index}: {reader}")
        return
    if not args.simulate and args.reader is None:
        parser.error("--reader is required (or --simulate)")

    reader = None if args.simulate else pick_reader(args.reader)
    args.out.mkdir(parents=True, exist_ok=True)
    traces = []
    for run in range(1, args.runs + 1):
        card = SimulatedFido2Card() if args.simulate else PcscConnection(reader)
        try:
            trace = record_run(card, args.label, args.length_form, args.get_response_supported)
        except Exception as error:  # noqa: BLE001 - report and continue with the next run
            print(f"run {run}: failed: {error}", file=sys.stderr)
            continue
        path = args.out / f"{trace['createdAt'].replace(':', '')}-{run:02d}-{trace['id'][:8]}.json"
        path.write_text(json.dumps(trace, indent=2) + "\n")
        reason = trace["events"][-1]["reason"]
        print(f"run {run}: {reason} -> {path}")
        traces.append(trace)

    if traces:
        print()
        print(summarize(traces))


if __name__ == "__main__":
    main()
