#!/usr/bin/env python3
"""Write CTAP2 canonical CBOR test vectors, encoded with python-fido2's CBOR module.

Output: FIDOKit/Tests/CTAPTests/Fixtures/vectors/cbor.json, a list of {name, hex, diag}.
`diag` is RFC 8949 diagnostic notation in the exact style of the Swift CBORDiagnostic printer
(", " and ": " separators, uppercase hex, JSON string escapes), so Swift can compare it too.

Run from a clean venv (pip install -r tools/requirements.txt); the output must not change.
python-fido2's encoder has no `null`, so null is covered by the Swift unit tests only.
"""

from __future__ import annotations

import json
from pathlib import Path

from fido2 import cbor

OUT = Path(__file__).resolve().parents[2] / "FIDOKit/Tests/CTAPTests/Fixtures/vectors/cbor.json"

COSE_EC2_KEY = {
    1: 2,  # kty: EC2
    3: -7,  # alg: ES256
    -1: 1,  # crv: P-256
    -2: bytes(range(0x00, 0x20)),  # x
    -3: bytes(range(0x20, 0x40)),  # y
}

GETINFO_RESPONSE = {
    1: ["FIDO_2_0", "FIDO_2_1"],
    3: bytes.fromhex("2FC0579F811347EAB116BB5A8DB9202A"),
    4: {"rk": True, "up": True, "plat": False, "clientPin": False},
    5: 1200,
    6: [2, 1],
    10: [{"alg": -7, "type": "public-key"}],
}


def cases() -> list[tuple[str, object]]:
    result: list[tuple[str, object]] = []
    for value in [0, 23, 24, 255, 256, 65535, 65536, 2**32 - 1, 2**32, 2**64 - 1]:
        result.append((f"uint_{value}", value))
    for value in [-1, -24, -25, -256, -257, -(2**64)]:
        result.append((f"nint_{-value}", value))
    for length in [0, 23, 24, 255, 256]:
        result.append((f"bytes_len_{length}", bytes(i % 256 for i in range(length))))
    for length in [0, 23, 24, 255, 256]:
        result.append((f"text_len_{length}", "".join("abcdefghijklmnopqrstuvwxyz"[i % 26] for i in range(length))))
    result += [
        ("true", True),
        ("false", False),
        ("text_escapes", 'quote " backslash \\ newline \n tab \t'),
        ("text_non_ascii", "Zürich ✓"),
        ("array_empty", []),
        ("array_nested", [1, [2, 3], [[4]], []]),
        ("map_empty", {}),
        ("map_nested", {1: {2: {3: "deep"}}, 2: [True, False]}),
        ("map_mixed_int_text_keys", {"b": 1, 10: 2, "a": 3, -1: 4, 1: 5, "aa": 6}),
        ("map_rk_up_uv", {"uv": False, "up": True, "rk": True}),
        ("cose_ec2_key", COSE_EC2_KEY),
        # authenticatorGetInfo has no parameters: the whole request is the command byte 0x04,
        # which read as CBOR is the unsigned integer 4.
        ("getinfo_request", 4),
        ("getinfo_response", GETINFO_RESPONSE),
    ]
    return result


def diag(value: object) -> str:
    if value is True:
        return "true"
    if value is False:
        return "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, bytes):
        return f"h'{value.hex().upper()}'"
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, list):
        return "[" + ", ".join(diag(item) for item in value) + "]"
    if isinstance(value, dict):
        # Diagnostic notation follows the encoded (canonical) order.
        encoded = cbor.encode(value)
        ordered = cbor.decode(encoded)
        return "{" + ", ".join(f"{diag(k)}: {diag(v)}" for k, v in ordered.items()) + "}"
    raise TypeError(f"unsupported value {value!r}")


def main() -> None:
    vectors = [{"name": name, "hex": cbor.encode(value).hex().upper(), "diag": diag(value)} for name, value in cases()]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(vectors, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(vectors)} vectors to {OUT}")


if __name__ == "__main__":
    main()
