#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_SCRIPT="$SCRIPT_DIR/build-hyprglass-local-base.sh"
TMP_SCRIPT="$SCRIPT_DIR/.build-hyprglass-control-mask-prototype.$$.sh"

cleanup() {
    rm -f -- "$TMP_SCRIPT"
}
trap cleanup EXIT

python3 - "$BASE_SCRIPT" "$TMP_SCRIPT" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1])
target = Path(sys.argv[2])
text = source.read_text(encoding="utf-8")
anchor = '    python3 "$SCRIPT_DIR/patch-hyprglass-layer-damage.py" "$source_dir"\n'
injected = anchor + '    python3 "$SCRIPT_DIR/patch-hyprglass-control-mask-prototype.py" "$source_dir"\n'

if anchor not in text:
    raise SystemExit("prototype builder could not locate the HyprGlass layer-damage patch hook")

target.write_text(text.replace(anchor, injected, 1), encoding="utf-8")
PY

chmod 0700 "$TMP_SCRIPT"
bash "$TMP_SCRIPT" "$@"
