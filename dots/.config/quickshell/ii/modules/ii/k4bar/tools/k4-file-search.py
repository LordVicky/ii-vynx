#!/usr/bin/env python3
"""On-demand K4 file search, adapted from k4ditano/k4 tools/buscar.py (MIT)."""

import argparse
import json
import os
import shutil
import subprocess
import time

EXCLUDES = [
    "node_modules", ".git", ".cache", "__pycache__", ".venv", "venv",
    ".npm", ".cargo/registry", ".rustup", ".local/share/Trash", ".steam",
]
SYSTEM_ROOTS = ["/usr", "/etc", "/opt", "/srv", "/var/log"]
SEARCH_TIMEOUT_SECONDS = 8


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


def excluded(path, root):
    try:
        relative = os.path.relpath(path, root).replace(os.sep, "/")
    except ValueError:
        return False
    parts = relative.split("/")
    for rule in EXCLUDES:
        normalized = rule.strip("/")
        if "/" in normalized:
            if relative == normalized or relative.startswith(normalized + "/"):
                return True
        elif normalized in parts:
            return True
    return False


def search_with_fd(binary, roots, query, type_filter, max_results):
    command = [
        binary, "--hidden", "--no-ignore", "--absolute-path", "--ignore-case",
        "--max-results", str(max_results),
    ]
    for exclude in EXCLUDES:
        command += ["--exclude", exclude]
    if type_filter == "dir":
        command += ["--type", "directory"]
    elif type_filter == "file":
        command += ["--type", "file"]
    command.append(query)
    command += roots

    try:
        proc = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=SEARCH_TIMEOUT_SECONDS,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    return [line.rstrip("/") or "/" for line in proc.stdout.splitlines() if line.strip()]


def search_with_python(roots, query, type_filter, max_results, deadline):
    matches = []
    wanted = query.lower()

    for requested_root in roots:
        root = os.path.abspath(os.path.expanduser(requested_root))
        if not os.path.isdir(root):
            continue

        for current, dirs, files in os.walk(
            root,
            topdown=True,
            onerror=lambda _error: None,
            followlinks=False,
        ):
            if time.monotonic() >= deadline:
                return matches

            dirs[:] = [
                name for name in dirs
                if not excluded(os.path.join(current, name), root)
            ]

            names = []
            if type_filter != "file":
                names.extend(dirs)
            if type_filter != "dir":
                names.extend(files)

            for name in names:
                if wanted not in name.lower():
                    continue
                path = os.path.abspath(os.path.join(current, name))
                if excluded(path, root):
                    continue
                matches.append(path)
                if len(matches) >= max_results:
                    return matches

    return matches


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

    roots = SYSTEM_ROOTS if args.scope == "system" else [os.path.expanduser("~")]
    max_results = max(1, args.limit * 4)
    started = time.monotonic()

    # fd is the preferred upstream-compatible fast path. Fedora packages the
    # same binary as fdfind; if neither exists, keep Files functional with a
    # bounded Python traversal rather than silently returning zero results.
    fd_binary = shutil.which("fd") or shutil.which("fdfind")
    paths = None
    if fd_binary:
        paths = search_with_fd(fd_binary, roots, query, args.type, max_results)
    if paths is None:
        paths = search_with_python(
            roots,
            query,
            args.type,
            max_results,
            started + SEARCH_TIMEOUT_SECONDS,
        )

    results = [row for row in (describe(path, query) for path in paths) if row]
    results.sort(key=lambda row: (-row["score"], -row["modified"]))
    print(json.dumps({
        "query": query,
        "results": results[: args.limit],
        "ms": round((time.monotonic() - started) * 1000),
    }))


if __name__ == "__main__":
    main()
