#!/usr/bin/env python3
"""Ask pinned libXray to construct (not start) an Xray config.

Uses testXray only. It does not call runXray and does not open a VPN.
The config path is local. Errors are truncated and known example secrets
are redacted before printing.
"""

from __future__ import annotations

import argparse
import ctypes
import json
import os
import sys

EXAMPLE_SECRETS = (
    "sCMyd0MxQEessoya6gphVLM9lOX9-5tuWBMRlskeuwA",
    "00000000-0000-4000-8000-000000000000",
    "11111111-1111-4111-8111-111111111111",
)


def redact(text: str) -> str:
    for secret in EXAMPLE_SECRETS:
        text = text.replace(secret, "•••")
    return text[:400]


def invoke(library: str, payload: dict) -> dict:
    lib = ctypes.CDLL(library)
    lib.CGoInvoke.argtypes = [ctypes.c_char_p]
    lib.CGoInvoke.restype = ctypes.c_void_p
    lib.CGoFree.argtypes = [ctypes.c_void_p]
    lib.CGoFree.restype = None
    raw = json.dumps(payload).encode()
    pointer = lib.CGoInvoke(raw)
    if not pointer:
        raise RuntimeError("CGoInvoke returned null")
    try:
        text = ctypes.cast(pointer, ctypes.c_char_p).value
        if text is None:
            raise RuntimeError("CGoInvoke returned an empty pointer")
        return json.loads(text.decode())
    finally:
        lib.CGoFree(pointer)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lib", required=True, help="Path to libXray.so from the pinned release")
    parser.add_argument("--config", required=True, help="Xray JSON to pass to testXray")
    args = parser.parse_args()

    version = invoke(args.lib, {"apiVersion": 3, "method": "xrayVersion", "payload": {}})
    if not version.get("success"):
        print("xrayVersion failed:", redact(version.get("error") or ""), file=sys.stderr)
        return 1
    reported = (version.get("data") or {}).get("version")
    print(f"libXray version: {reported}")

    config = json.loads(open(args.config, encoding="utf-8").read())
    # Refuse to validate a document that would ask the core to dial out.
    text = json.dumps(config)
    if "runXray" in text:
        print("refusing a document that names runXray", file=sys.stderr)
        return 2
    result = invoke(
        args.lib,
        {"apiVersion": 3, "method": "testXray", "payload": {"xrayJson": text}},
    )
    if not result.get("success"):
        print("testXray failed:", redact(result.get("error") or ""), file=sys.stderr)
        return 1
    state = invoke(args.lib, {"apiVersion": 3, "method": "getXrayState", "payload": {}})
    running = (state.get("data") or {}).get("running")
    if running:
        print("refusing to leave a running core; this script must only testXray", file=sys.stderr)
        return 3
    print("testXray accepted the config; core is not running")
    os.environ.setdefault("VPN_LIBXRAY_CHECKED", "1")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
