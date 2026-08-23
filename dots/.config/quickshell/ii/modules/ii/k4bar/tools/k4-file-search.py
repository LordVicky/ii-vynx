#!/usr/bin/env python3
"""On-demand K4 file search, adapted from k4ditano/k4 tools/buscar.py (MIT)."""

import argparse
import json
import os
import subprocess
import time

EXCLUDES = [
    "node_modules", ".git", ".cache", "__pycache__", ".venv", "venv",
    ".npm", ".cargo/registry", ".rustup", ".local/share/Trash", ".steam",
]
SYSTEM_ROOTS = ["/usr", "/etc", "/opt", "/srv", "/var/log"]


def score(path, query):
    name = os.path.basename(path).lower()
    q = query.lower()
    if name == q:
        base = 1000
    elif os.path.splitext(name)[0] == q:
        base = 900
    elif name.startswith(q):
        base = 700
    elif q in name:
        base = 500
    else:
        base = 200
    return base - min(200, path.count("/") * 8)


def describe(path, query):
    try:
        stat = os.lstat(path)
    except OSError:
        return None
    is_dir = os.path.isdir(path)
    return {
        "path": path,
        "name": os.path.basename(path) or path,
        "directory": os.path.dirname(path),
        "isDirectory": is_dir,
        "extension": "" if is_dir else os.path.splitext(path)[1].lstrip(".").lower(),
        "bytes": 0 if is_dir else stat.st_size,
        "modified": stat.st_mtime,
        "score": score(path, query),
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("query")
    parser.add_argument("--scope", choices=("home", "system"), default="home")
    parser.add_argument("--limit", type=int, default=60)
    parser.add_argument("--type", choices=("file", "dir"), default="")
    args = parser.parse_args()

    query = args.query.strip()
    if len(query) < 2:
        print(json.dumps({"query": query, "results": [], "ms": 0}))
        return

    command = [
        "fd", "--hidden", "--no-ignore", "--absolute-path", "--ignore-case",
        "--max-results", str(args.limit * 4),
    ]
    for exclude in EXCLUDES:
        command += ["--exclude", exclude]
    if args.type == "dir":
        command += ["--type", "directory"]
    elif args.type == "file":
        command += ["--type", "file"]
    command.append(query)
    command += SYSTEM_ROOTS if args.scope == "system" else [os.path.expanduser("~")]

    started = time.time()
    try:
        proc = subprocess.run(command, capture_output=True, text=True, timeout=8)
        paths = [line.rstrip("/") or "/" for line in proc.stdout.splitlines() if line.strip()]
    except Exception:
        paths = []

    results = [row for row in (describe(path, query) for path in paths) if row]
    results.sort(key=lambda row: (-row["score"], -row["modified"]))
    print(json.dumps({
        "query": query,
        "results": results[: args.limit],
        "ms": round((time.time() - started) * 1000),
    }))


if __name__ == "__main__":
    main()
