#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_INSTALLER="$ROOT/sdata/liquid-glass/install-hyprglass.sh"
SOURCE_LICENSE="$ROOT/licenses/HyprGlass-BSD-3-Clause.txt"
HYPRLAND_VERSION="0.56.1"
FEDORA_COMMIT="5c9377c15f85c50648f35ca5a213754f95b93ca0"
ABI_SUFFIX="_aq_0.14_hu_0.14_hg_0.5_hc_0.1_hlg_0.6"
ABI_HASH="${FEDORA_COMMIT}${ABI_SUFFIX}"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ii-vynx-glass-test.XXXXXX")"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

mkdir -p \
    "$TMP_ROOT/repo/sdata/liquid-glass" \
    "$TMP_ROOT/repo/licenses" \
    "$TMP_ROOT/bin" \
    "$TMP_ROOT/home"

cp "$SOURCE_INSTALLER" "$TMP_ROOT/repo/sdata/liquid-glass/install-hyprglass.sh"
cp "$SOURCE_LICENSE" "$TMP_ROOT/repo/licenses/HyprGlass-BSD-3-Clause.txt"
printf '%s\tv0.7.0\thttps://example.invalid/hyprglass.so\n' "$ABI_SUFFIX" \
    > "$TMP_ROOT/repo/sdata/liquid-glass/hyprglass-compat.tsv"

cat > "$TMP_ROOT/bin/hyprctl" <<EOF
#!/usr/bin/env sh
printf '%s\\n' '{"version":"$HYPRLAND_VERSION","commit":"$FEDORA_COMMIT","abiHash":"$ABI_HASH"}'
EOF

cat > "$TMP_ROOT/bin/curl" <<'EOF'
#!/usr/bin/env sh
output=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --output)
            output="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done
printf '\177ELFii-vynx-test' > "$output"
EOF

cat > "$TMP_ROOT/bin/ldd" <<'EOF'
#!/usr/bin/env sh
exit 0
EOF

chmod +x "$TMP_ROOT/bin/hyprctl" "$TMP_ROOT/bin/curl" "$TMP_ROOT/bin/ldd"

TEST_HOME="$TMP_ROOT/home"
TEST_PATH="$TMP_ROOT/bin:/usr/bin:/bin"
INSTALLER="$TMP_ROOT/repo/sdata/liquid-glass/install-hyprglass.sh"
TARGET="$TEST_HOME/.local/lib/ii-vynx/hyprglass/$ABI_SUFFIX/hyprglass.so"
LICENSE_TARGET="$TEST_HOME/.local/share/licenses/ii-vynx/HyprGlass-BSD-3-Clause.txt"

HOME="$TEST_HOME" PATH="$TEST_PATH" bash "$INSTALLER"
test -f "$TARGET"
test -f "$LICENSE_TARGET"

first_mtime="$(stat -c %Y "$TARGET")"
sleep 1
HOME="$TEST_HOME" PATH="$TEST_PATH" bash "$INSTALLER"
second_mtime="$(stat -c %Y "$TARGET")"

if [ "$first_mtime" != "$second_mtime" ]; then
    echo "Installer replaced an already valid managed binary." >&2
    exit 1
fi

rm -f "$TARGET"
cat > "$TMP_ROOT/bin/ldd" <<'EOF'
#!/usr/bin/env sh
printf '%s\n' 'libaquamarine.so.12 => not found'
exit 0
EOF

set +e
HOME="$TEST_HOME" PATH="$TEST_PATH" bash "$INSTALLER" >/dev/null 2>&1
status=$?
set -e

if [ "$status" -ne 4 ]; then
    echo "Installer did not reject an unresolved runtime dependency." >&2
    exit 1
fi

if [ -e "$TARGET" ]; then
    echo "Installer kept a binary with unresolved runtime dependencies." >&2
    exit 1
fi

cat > "$TMP_ROOT/bin/hyprctl" <<EOF
#!/usr/bin/env sh
printf '%s\\n' '{"version":"$HYPRLAND_VERSION","commit":"$FEDORA_COMMIT","abiHash":"${FEDORA_COMMIT}_aq_0.13_hu_0.14_hg_0.5_hc_0.1_hlg_0.6"}'
EOF
cat > "$TMP_ROOT/bin/ldd" <<'EOF'
#!/usr/bin/env sh
exit 0
EOF

set +e
HOME="$TEST_HOME" PATH="$TEST_PATH" bash "$INSTALLER" >/dev/null 2>&1
status=$?
set -e

if [ "$status" -ne 2 ]; then
    echo "Installer did not reject an unregistered dependency ABI." >&2
    exit 1
fi

printf '%s\n' "Liquid Glass installer test passed."
