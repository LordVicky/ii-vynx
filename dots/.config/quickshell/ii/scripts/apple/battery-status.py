#!/usr/bin/env python3
"""Minimal Apple Find My battery bridge for Vynx.

`login` performs interactive authentication once and persists only pyicloud's
trusted session state plus the Apple Account identifier. `status` is fully
non-interactive: it reuses that session, emits a small normalized JSON payload,
and exits.

Secrets are never accepted on command arguments or written into the repository.
"""

from __future__ import annotations

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
STATE_DIR = Path(
    os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state")
) / "ii-vynx" / "apple"
ACCOUNT_FILE = STATE_DIR / "account"


class DependencyError(RuntimeError):
    pass


def parse_version(value: str) -> tuple[int, ...]:
    result: list[int] = []
    for part in value.split("."):
        digits = "".join(ch for ch in part if ch.isdigit())
        if not digits:
            break
        result.append(int(digits))
    return tuple(result)


def pyicloud_service():
    try:
        installed = version("pyicloud")
    except PackageNotFoundError as exc:
        raise DependencyError("pyicloud >= 2.6.5 is required") from exc
    if parse_version(installed) < MIN_PYICLOUD_VERSION:
        raise DependencyError(f"pyicloud {installed} is too old; need >= 2.6.5")

    try:
        from pyicloud import PyiCloudService
    except ImportError as exc:
        raise DependencyError("pyicloud could not be imported") from exc

    return PyiCloudService


def ensure_state_dir() -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
    try:
        STATE_DIR.chmod(0o700)
    except OSError:
        pass


def read_account() -> str | None:
    try:
        value = ACCOUNT_FILE.read_text(encoding="utf-8").strip()
    except OSError:
        return None
    return value or None


def write_account(apple_id: str) -> None:
    ensure_state_dir()
    ACCOUNT_FILE.write_text(apple_id.strip() + "\n", encoding="utf-8")
    try:
        ACCOUNT_FILE.chmod(0o600)
    except OSError:
        pass


def stable_id(raw_id: str) -> str:
    digest = hashlib.sha256(raw_id.encode("utf-8")).hexdigest()[:16]
    return f"icloud:{digest}"


def normalize_level(value: Any) -> float | None:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    value = float(value)
    return round(value, 4) if 0 <= value <= 1 else None


def normalize_charging(value: Any) -> tuple[bool, bool]:
    if not isinstance(value, str):
        return False, False
    state = value.strip().lower().replace(" ", "")
    if state in {"charging", "charged", "full", "fullycharged"}:
        return True, True
    if state in {"notcharging", "unplugged", "discharging"}:
        return False, True
    return False, False


def service(apple_id: str, password: str | None):
    ensure_state_dir()
    return pyicloud_service()(
        apple_id,
        password,
        cookie_directory=str(STATE_DIR),
        with_family=False,
        refresh_interval=3600,
    )


def login() -> int:
    apple_id = input("Apple Account email: ").strip()
    if not apple_id:
        print("Apple Account email is required.", file=sys.stderr)
        return 2

    password = getpass.getpass("Apple Account password: ")
    try:
        api = service(apple_id, password)
        if api.requires_2fa:
            security_keys = getattr(api, "security_key_names", None)
            if security_keys:
                print(
                    "Security-key 2FA is not handled by this minimal helper; "
                    "use pyicloud's `icloud auth login` CLI for this account.",
                    file=sys.stderr,
                )
                return 3

            if not api.request_2fa_code():
                print("Unable to complete this Apple 2FA method.", file=sys.stderr)
                return 3
            code = getpass.getpass("Apple verification code: ").strip()
            if not api.validate_2fa_code(code):
                print("Verification code rejected.", file=sys.stderr)
                return 3

        if not api.is_trusted_session and not api.trust_session():
            print("Apple session could not be marked as trusted.", file=sys.stderr)
            return 3

        write_account(apple_id)
        print("Apple session saved.")
        return 0
    except DependencyError as exc:
        print(str(exc), file=sys.stderr)
        return 5
    finally:
        # Python cannot guarantee zeroization of immutable strings, but dropping
        # references promptly avoids retaining secrets beyond authentication.
        password = ""


def normalize_device(device: Any, observed_at: int) -> dict[str, Any] | None:
    data = device.status(
        additional=["id", "batteryStatus", "deviceClass", "deviceModel", "rawDeviceModel"]
    )
    raw_id = data.get("id")
    percentage = normalize_level(data.get("batteryLevel"))
    if raw_id is None or percentage is None:
        return None

    raw_battery_status = data.get("batteryStatus")
    charging, charging_known = normalize_charging(raw_battery_status)
    name = data.get("name") or data.get("deviceDisplayName") or "Apple device"
    return {
        "id": stable_id(str(raw_id)),
        "name": str(name),
        "deviceClass": data.get("deviceClass"),
        "deviceModel": data.get("deviceModel") or data.get("rawDeviceModel"),
        "deviceStatus": data.get("deviceStatus"),
        "batteryStatusRaw": raw_battery_status,
        "percentage": percentage,
        "charging": charging,
        "chargingKnown": charging_known,
        "observedAt": observed_at,
    }


def emit(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, separators=(",", ":")))


def state_for_exception(exc: Exception) -> str:
    name = type(exc).__name__
    if name in {
        "PyiCloudAuthRequiredException",
        "PyiCloudFailedLoginException",
        "PyiCloudPasswordException",
        "PyiCloud2FARequiredException",
    }:
        return "authenticationRequired"
    if name == "PyiCloudAcceptTermsException":
        return "termsRequired"
    return "error"


def status() -> int:
    apple_id = read_account()
    if not apple_id:
        emit({"state": "notConfigured", "devices": []})
        return 2

    observed_at = int(time.time() * 1000)
    try:
        api = service(apple_id, None)
        if api.requires_2fa:
            emit({"state": "authenticationRequired", "devices": []})
            return 3

        devices = []
        for device in api.devices:
            normalized = normalize_device(device, observed_at)
            if normalized is not None:
                devices.append(normalized)

        emit({
            "state": "connected",
            "observedAt": observed_at,
            "devices": devices,
        })
        return 0
    except DependencyError as exc:
        emit({
            "state": "dependencyMissing",
            "error": str(exc),
            "devices": [],
        })
        return 5
    except Exception as exc:
        emit({
            "state": state_for_exception(exc),
            "error": type(exc).__name__,
            "devices": [],
        })
        return 4


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] not in {"login", "status"}:
        print("usage: battery-status.py login | status", file=sys.stderr)
        return 2

    if sys.argv[1] == "login":
        return login()
    return status()


if __name__ == "__main__":
    raise SystemExit(main())
