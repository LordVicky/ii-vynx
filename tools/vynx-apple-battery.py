#!/usr/bin/env python3
"""Minimal Apple Find My battery helper for Vynx.

Two modes are intentionally separated:
- `login`: interactive authentication/2FA, persists the pyicloud session.
- `status`: non-interactive, performs one Find My enumeration and exits.

No daemon, no location history, no raw Find My payload persistence.
"""

from __future__ import annotations

import argparse
import getpass
import hashlib
import json
import os
import sys
import time
from importlib.metadata import PackageNotFoundError, version
from pathlib import Path
from typing import Any

MIN_PYICLOUD_VERSION = (2, 6, 5)
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "ii-vynx" / "apple"


def parse_version(value: str) -> tuple[int, ...]:
    parts: list[int] = []
    for chunk in value.split("."):
        digits = "".join(ch for ch in chunk if ch.isdigit())
        if not digits:
            break
        parts.append(int(digits))
    return tuple(parts)


def require_pyicloud():
    try:
        installed = version("pyicloud")
    except PackageNotFoundError:
        raise RuntimeError("pyicloud >= 2.6.5 is required")

    if parse_version(installed) < MIN_PYICLOUD_VERSION:
        raise RuntimeError(f"pyicloud {installed} is too old; need >= 2.6.5")

    from pyicloud import PyiCloudService

    return PyiCloudService


def ensure_cache_dir() -> None:
    CACHE_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
    try:
        CACHE_DIR.chmod(0o700)
    except OSError:
        pass


def stable_id(raw_id: str) -> str:
    return "icloud:" + hashlib.sha256(raw_id.encode("utf-8")).hexdigest()[:16]


def battery_level(value: Any) -> float | None:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    level = float(value)
    if not 0 <= level <= 1:
        return None
    return round(level, 4)


def charging_state(value: Any) -> tuple[bool, bool]:
    if not isinstance(value, str) or not value.strip():
        return False, False

    state = value.strip().lower().replace(" ", "")
    if state in {"charging", "charged", "full", "fullycharged"}:
        return True, True
    if state in {"notcharging", "unplugged", "discharging"}:
        return False, True
    return False, False


def normalized_device(device: Any, observed_at_ms: int) -> dict[str, Any] | None:
    status = device.status(
        additional=["id", "batteryStatus", "deviceClass", "deviceModel", "rawDeviceModel"]
    )
    level = battery_level(status.get("batteryLevel"))
    raw_id = status.get("id")
    if level is None or raw_id is None:
        return None

    charging, charging_known = charging_state(status.get("batteryStatus"))
    name = status.get("name") or status.get("deviceDisplayName") or "Apple device"

    return {
        "id": stable_id(str(raw_id)),
        "name": str(name),
        "deviceClass": status.get("deviceClass"),
        "deviceModel": status.get("deviceModel") or status.get("rawDeviceModel"),
        "percentage": level,
        "charging": charging,
        "chargingKnown": charging_known,
        "observedAt": observed_at_ms,
    }


def create_service(apple_id: str, password: str | None):
    PyiCloudService = require_pyicloud()
    ensure_cache_dir()
    return PyiCloudService(
        apple_id,
        password,
        cookie_directory=str(CACHE_DIR),
        with_family=False,
    )


def command_login(apple_id: str) -> int:
    password = getpass.getpass("Apple Account password: ")
    try:
        api = create_service(apple_id, password)
        if api.requires_2fa:
            if not api.request_2fa_code():
                print("Unable to complete this Apple 2FA method.", file=sys.stderr)
                return 3
            code = input("Apple verification code: ").strip()
            if not api.validate_2fa_code(code):
                print("Verification code rejected.", file=sys.stderr)
                return 3
        print("Apple session saved.")
        return 0
    finally:
        password = ""


def command_status(apple_id: str) -> int:
    observed_at_ms = int(time.time() * 1000)
    try:
        api = create_service(apple_id, None)
        if api.requires_2fa:
            print(json.dumps({"state": "authenticationRequired", "devices": []}))
            return 3

        devices = []
        for device in api.devices:
            normalized = normalized_device(device, observed_at_ms)
            if normalized is not None:
                devices.append(normalized)

        print(
            json.dumps(
                {
                    "state": "connected",
                    "observedAt": observed_at_ms,
                    "devices": devices,
                },
                separators=(",", ":"),
            )
        )
        return 0
    except Exception as exc:  # helper boundary: return a compact machine-readable failure
        print(
            json.dumps(
                {
                    "state": "error",
                    "error": type(exc).__name__,
                    "devices": [],
                },
                separators=(",", ":"),
            )
        )
        return 4


def main() -> int:
    parser = argparse.ArgumentParser(description="Vynx Apple battery helper")
    parser.add_argument("apple_id", help="Apple Account email")
    parser.add_argument("command", choices=("login", "status"))
    args = parser.parse_args()

    if args.command == "login":
        return command_login(args.apple_id)
    return command_status(args.apple_id)


if __name__ == "__main__":
    raise SystemExit(main())
