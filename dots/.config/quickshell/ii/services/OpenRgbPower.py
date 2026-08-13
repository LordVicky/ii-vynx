#!/usr/bin/env python3

import argparse
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys


DEVICE_HEADER = re.compile(r"^\s*(\d+)\s*:\s*(.+?)\s*$")
DEVICE_FIELD = re.compile(r"^\s*(Description|Location|Serial)\s*:\s*(.*?)\s*$")


def parse_devices(text):
    devices = []
    current = None
    for line in text.splitlines():
        header = DEVICE_HEADER.match(line)
        if header:
            current = {
                "index": int(header.group(1)),
                "name": header.group(2),
                "description": "",
                "location": "",
                "serial": "",
            }
            devices.append(current)
            continue
        field = DEVICE_FIELD.match(line)
        if field and current is not None:
            current[field.group(1).lower()] = field.group(2)
    return devices


def effect_assignments(path):
    payload = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    assignments = []
    for effect in payload.get("Effects", []):
        assignments.extend(effect.get("ControllerZones", []))
    return assignments


def _exact(field, assignment, devices):
    value = assignment.get(field, "")
    return [device for device in devices if value and device.get(field, "") == value]


def match_effect_devices(assignments, devices):
    matched = set()
    for assignment in assignments:
        candidates = _exact("location", assignment, devices)
        if not candidates:
            candidates = _exact("serial", assignment, devices)
        if not candidates:
            name = assignment.get("name", "")
            description = assignment.get("description", "")
            candidates = [
                device for device in devices
                if name and device["name"] == name
                and description and device["description"] == description
            ]
        matched.update(device["index"] for device in candidates)
    return sorted(matched)


def _embedded(profile, value):
    return bool(value) and value.encode("utf-8") in profile


def match_orp_devices(profile, devices):
    name_counts = {}
    for device in devices:
        name_counts[device["name"]] = name_counts.get(device["name"], 0) + 1

    matched = []
    for device in devices:
        if _embedded(profile, device["location"]):
            matched.append(device["index"])
        elif _embedded(profile, device["serial"]):
            matched.append(device["index"])
        elif name_counts[device["name"]] == 1 and _embedded(profile, device["name"]):
            matched.append(device["index"])
    return sorted(set(matched))


def color_command(binary, indices):
    if not indices:
        raise ValueError("No assigned devices matched the current OpenRGB device list")
    command = [binary]
    for index in indices:
        command.extend(["--device", str(index), "--color", "000000"])
    return command


def effect_profile_path(selection):
    candidate = pathlib.Path(selection).expanduser()
    if candidate.is_file():
        return candidate
    config_home = pathlib.Path(os.environ.get("XDG_CONFIG_HOME", pathlib.Path.home() / ".config"))
    return config_home / "OpenRGB" / "plugins" / "settings" / "effect-profiles" / selection


def resolve_indices(kind, selection, devices):
    if kind == "effect":
        return match_effect_devices(effect_assignments(effect_profile_path(selection)), devices)
    return match_orp_devices(pathlib.Path(selection).read_bytes(), devices)


def stop_effects(args):
    if not args.service or not args.menu_path or args.stop_id < 0:
        raise RuntimeError("Effects Plugin stop action is unavailable")
    subprocess.run([
        "busctl", "--user", "call", args.service, args.menu_path,
        "com.canonical.dbusmenu", "Event", "isvu", str(args.stop_id),
        "clicked", "v", "i", "0", "0",
    ], check=True)


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("resolve", "off"))
    parser.add_argument("--kind", choices=("profile", "effect"), required=True)
    parser.add_argument("--selection", required=True)
    parser.add_argument("--service", default="")
    parser.add_argument("--menu-path", default="")
    parser.add_argument("--stop-id", type=int, default=-1)
    args = parser.parse_args(argv)

    binary = shutil.which("openrgb") or shutil.which("OpenRGB")
    if not binary:
        raise RuntimeError("OpenRGB not found")
    result = subprocess.run([binary, "--list-devices"], check=True, capture_output=True, text=True)
    devices = parse_devices(result.stdout)
    indices = resolve_indices(args.kind, args.selection, devices)
    command = color_command(binary, indices)

    if args.action == "resolve":
        print(json.dumps({"indices": indices, "devices": [device for device in devices if device["index"] in indices]}))
        return 0

    if args.kind == "effect":
        stop_effects(args)
    subprocess.run(command, check=True)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError, json.JSONDecodeError) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1)
