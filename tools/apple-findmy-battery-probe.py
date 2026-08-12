#!/usr/bin/env python3
"""Read-only feasibility probe for Apple Find My battery data.

This tool is intentionally separate from the Vynx runtime. It performs one
Find My fetch, prints a privacy-safe summary, then exits. It never writes raw
Find My responses, device IDs, coordinates, Apple IDs, passwords, or cookies
into the report.
"""

from __future__ import annotations

import argparse
import getpass
import hashlib
import json
import os
import sys
from importlib.metadata import PackageNotFoundError, version
from pathlib import Path
from typing import Any

MIN_PYICLOUD_VERSION = (2, 6, 5)
DEFAULT_COOKIE_DIR = Path(
    os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")
) / "ii-vynx" / "apple-findmy-probe"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Probe Find My battery fields without exposing private Find My data."
    )
    parser.add_argument("apple_id", help="Apple Account email; used only for this login")
    parser.add_argument(
        "--cookie-dir",
        type=Path,
        default=DEFAULT_COOKIE_DIR,
        help=f"Session cache directory (default: {DEFAULT_COOKIE_DIR})",
    )
    parser.add_argument(
        "--no-family",
        action="store_true",
        help="Probe only devices owned directly by this Apple Account",
    )
    return parser.parse_args()


def parse_version(value: str) -> tuple[int, ...]:
    parts: list[int] = []
    for chunk in value.split("."):
        digits = "".join(ch for ch in chunk if ch.isdigit())
        if not digits:
            break
        parts.append(int(digits))
    return tuple(parts)


def device_key(device_id: str) -> str:
    """Return a stable, non-secret pseudonym suitable for comparing probe runs."""
    digest = hashlib.sha256(device_id.encode("utf-8")).hexdigest()
    return f"device-{digest[:12]}"


def normalized_level(value: Any) -> float | None:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    level = float(value)
    if level < 0 or level > 1:
        return None
    return round(level, 4)


def probe_device(device: Any) -> dict[str, Any]:
    # AppleDevice.status() intentionally returns an allowlisted subset. Do not
    # switch this probe to device.data/raw payload output.
    status = device.status(
        additional=["id", "batteryStatus", "deviceClass", "deviceModel", "rawDeviceModel"]
    )
    level = normalized_level(status.get("batteryLevel"))
    raw_id = status.get("id")
    key = device_key(str(raw_id)) if raw_id else "device-unknown"

    return {
        "key": key,
        "deviceClass": status.get("deviceClass"),
        "deviceDisplayName": status.get("deviceDisplayName"),
        "deviceModel": status.get("deviceModel"),
        "rawDeviceModel": status.get("rawDeviceModel"),
        "deviceStatus": status.get("deviceStatus"),
        "batteryLevel": level,
        "batteryPercent": round(level * 100) if level is not None else None,
        "batteryStatus": status.get("batteryStatus"),
    }


def main() -> int:
    args = parse_args()

    try:
        installed = version("pyicloud")
    except PackageNotFoundError:
        print("error: pyicloud is not installed (need >= 2.6.5)", file=sys.stderr)
        return 2

    if parse_version(installed) < MIN_PYICLOUD_VERSION:
        print(
            f"error: pyicloud {installed} is too old; need >= 2.6.5",
            file=sys.stderr,
        )
        return 2

    try:
        from pyicloud import PyiCloudService
    except ImportError as exc:
        print(f"error: failed to import pyicloud: {exc}", file=sys.stderr)
        return 2

    args.cookie_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    try:
        args.cookie_dir.chmod(0o700)
    except OSError:
        pass

    password = getpass.getpass("Apple Account password (not stored by this probe): ")
    try:
        api = PyiCloudService(
            args.apple_id,
            password,
            cookie_directory=str(args.cookie_dir),
            with_family=not args.no_family,
        )

        if api.requires_2fa:
            if not api.request_2fa_code():
                print(
                    "error: this account requires a 2FA method the probe cannot complete",
                    file=sys.stderr,
                )
                return 3
            code = input("Apple verification code: ").strip()
            if not api.validate_2fa_code(code):
                print("error: verification code was rejected", file=sys.stderr)
                return 3

        manager = api.devices
        devices = [probe_device(device) for device in manager]
    except KeyboardInterrupt:
        print("\nCancelled.", file=sys.stderr)
        return 130
    except Exception as exc:  # diagnostic tool: surface library/service failures concisely
        print(f"error: Find My probe failed: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 4
    finally:
        password = ""

    report = {
        "schemaVersion": 1,
        "pyicloudVersion": installed,
        "deviceCount": len(devices),
        "batteryReadableCount": sum(d["batteryLevel"] is not None for d in devices),
        "devices": devices,
    }
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
