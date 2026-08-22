#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

LABEL="current"
RUNS=3
DURATION=30
INTERVAL=1
WARMUP=10
COOLDOWN=3
RESTART_SHELL=false
OUTPUT=""

usage() {
    cat <<'USAGE'
Usage: tests/vynx-resource-benchmark.sh [options]

Measures the running ii-vynx shell plus Hyprland so compositor-side effects
(such as HyprGlass) are included in CPU/GPU measurements.

Options:
  --label NAME        Label used in the summary/CSV (default: current)
  --runs N            Number of measurement runs (default: 3)
  --duration SEC      Measurement time per run (default: 30)
  --interval SEC      Sampling interval in whole seconds (default: 1)
  --warmup SEC        Warm-up before every run (default: 10)
  --cooldown SEC      Delay between runs (default: 3)
  --restart-shell     Restart only the main `qs -c ii` process before each run
  --output PATH       CSV output path (default: /tmp/vynx-resource-bench-*.csv)
  -h, --help          Show this help

CPU percentages use top-style semantics: 100% means one fully busy CPU core.
GPU_SYS is system-wide GPU busy when a supported device metric is available.
HYPR_GPU is Hyprland's DRM client engine-active percentage when drm fdinfo stats
are exported by the driver. HYPR_GPU may exceed 100% if multiple engines are
busy in parallel.
USAGE
}

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

is_positive_int() {
    [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

is_nonnegative_int() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --label)
            [[ $# -ge 2 ]] || fail "--label requires a value"
            LABEL="$2"
            shift 2
            ;;
        --runs)
            [[ $# -ge 2 ]] || fail "--runs requires a value"
            RUNS="$2"
            shift 2
            ;;
        --duration)
            [[ $# -ge 2 ]] || fail "--duration requires a value"
            DURATION="$2"
            shift 2
            ;;
        --interval)
            [[ $# -ge 2 ]] || fail "--interval requires a value"
            INTERVAL="$2"
            shift 2
            ;;
        --warmup)
            [[ $# -ge 2 ]] || fail "--warmup requires a value"
            WARMUP="$2"
            shift 2
            ;;
        --cooldown)
            [[ $# -ge 2 ]] || fail "--cooldown requires a value"
            COOLDOWN="$2"
            shift 2
            ;;
        --restart-shell)
            RESTART_SHELL=true
            shift
            ;;
        --output)
            [[ $# -ge 2 ]] || fail "--output requires a value"
            OUTPUT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "unknown option: $1"
            ;;
    esac
done

is_positive_int "$RUNS" || fail "--runs must be a positive integer"
is_positive_int "$DURATION" || fail "--duration must be a positive integer"
is_positive_int "$INTERVAL" || fail "--interval must be a positive integer"
is_nonnegative_int "$WARMUP" || fail "--warmup must be a non-negative integer"
is_nonnegative_int "$COOLDOWN" || fail "--cooldown must be a non-negative integer"

command -v awk >/dev/null 2>&1 || fail "awk is required"
command -v ps >/dev/null 2>&1 || fail "ps is required"
command -v getconf >/dev/null 2>&1 || fail "getconf is required"

CLK_TCK="$(getconf CLK_TCK)"
SAMPLES=$(((DURATION + INTERVAL - 1) / INTERVAL))
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/vynx-resource-bench.XXXXXX")"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

if [[ -z "$OUTPUT" ]]; then
    SAFE_LABEL="$(printf '%s' "$LABEL" | tr -cs 'A-Za-z0-9._-' '_')"
    OUTPUT="${TMPDIR:-/tmp}/vynx-resource-bench-${SAFE_LABEL}-$(date +%Y%m%d-%H%M%S).csv"
fi

mkdir -p "$(dirname -- "$OUTPUT")"
printf '%s\n' 'label,run,sample,timestamp,qs_pid,hyprland_pid,qs_pss_kb,qs_uss_kb,qs_pss_anon_kb,qs_pss_file_kb,qtqml_pss_kb,hypr_pss_kb,hypr_uss_kb,qs_cpu_pct,hypr_cpu_pct,gpu_sys_pct,hypr_gpu_pct' > "$OUTPUT"

find_qs_pids() {
    ps -eo pid=,comm=,args= | awk '
        $2 == "qs" && $0 ~ /(^|[[:space:]])-c[[:space:]]+ii([[:space:]]|$)/ { print $1 }
    '
}

resolve_single_qs_pid() {
    local pids
    pids="$(find_qs_pids)"
    [[ -n "$pids" ]] || fail "no main Quickshell process found; start it with: qs -c ii"

    local count
    count="$(printf '%s\n' "$pids" | awk 'NF { n++ } END { print n + 0 }')"
    if [[ "$count" -ne 1 ]]; then
        printf 'Found %s main ii Quickshell processes:\n%s\n' "$count" "$pids" >&2
        fail "benchmark requires exactly one main qs -c ii process"
    fi

    printf '%s\n' "$pids"
}

resolve_hyprland_pid() {
    local pid
    pid="$(ps -eo pid=,comm= | awk '$2 == "Hyprland" { print $1; exit }')"
    [[ -n "$pid" ]] || fail "Hyprland process not found"
    printf '%s\n' "$pid"
}

restart_shell() {
    local pids
    pids="$(find_qs_pids)"
    if [[ -n "$pids" ]]; then
        while read -r pid; do
            [[ -n "$pid" ]] || continue
            kill "$pid" 2>/dev/null || true
        done <<< "$pids"

        for _ in {1..50}; do
            [[ -z "$(find_qs_pids)" ]] && break
            sleep 0.1
        done
    fi

    nohup qs -c ii > "$TMP_ROOT/qs-restart.log" 2>&1 &

    for _ in {1..100}; do
        if [[ -n "$(find_qs_pids)" ]]; then
            resolve_single_qs_pid >/dev/null
            return
        fi
        sleep 0.1
    done

    cat "$TMP_ROOT/qs-restart.log" >&2 || true
    fail "Quickshell did not restart within 10 seconds"
}

process_ticks() {
    local pid="$1"
    [[ -r "/proc/$pid/stat" ]] || return 1
    awk '{ print $14 + $15 }' "/proc/$pid/stat"
}

process_memory() {
    local pid="$1"
    local rollup="/proc/$pid/smaps_rollup"
    [[ -r "$rollup" ]] || return 1

    local values
    values="$(awk '
        /^Pss:/           { pss = $2 }
        /^Private_Clean:/ { private_clean = $2 }
        /^Private_Dirty:/ { private_dirty = $2 }
        /^Pss_Anon:/      { anon = $2; have_breakdown = 1 }
        /^Pss_File:/      { file = $2; have_breakdown = 1 }
        END {
            printf "%d %d %d %d %d\n", pss + 0, private_clean + private_dirty, anon + 0, file + 0, have_breakdown + 0
        }
    ' "$rollup")"

    local pss uss anon file have_breakdown
    read -r pss uss anon file have_breakdown <<< "$values"

    if [[ "$have_breakdown" -eq 0 && -r "/proc/$pid/status" ]]; then
        read -r anon file < <(awk '
            /^RssAnon:/ { anon = $2 }
            /^RssFile:/ { file = $2 }
            END { printf "%d %d\n", anon + 0, file + 0 }
        ' "/proc/$pid/status")
    fi

    printf '%s %s %s %s\n' "$pss" "$uss" "$anon" "$file"
}

qtqml_pss_kb() {
    local pid="$1"
    local smaps="/proc/$pid/smaps"
    [[ -r "$smaps" ]] || {
        printf '0\n'
        return
    }

    awk '
        /^[0-9a-f]+-[0-9a-f]+ / {
            wanted = ($0 ~ /libQt6(Qml|Quick)/ || $0 ~ /\/quickshell/)
            next
        }
        wanted && /^Pss:/ { sum += $2 }
        END { print sum + 0 }
    ' "$smaps"
}

hyprglass_state() {
    if command -v hyprctl >/dev/null 2>&1 && hyprctl plugin list 2>/dev/null | grep -qi 'hyprglass'; then
        printf 'loaded\n'
    else
        printf 'not-loaded\n'
    fi
}

surface_style() {
    local config="$HOME/.config/illogical-impulse/config.json"
    [[ -r "$config" ]] || {
        printf 'unknown\n'
        return
    }

    local style
    style="$(sed -n 's/.*"surfaceStyle"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$config" | head -n 1)"
    printf '%s\n' "${style:-unknown}"
}

GPU_SYS_BACKEND="none"
GPU_SYS_PATH=""

select_gpu_sys_backend() {
    local hypr_pid="$1"
    local target node candidate

    for fd in "/proc/$hypr_pid/fd/"*; do
        [[ -e "$fd" ]] || continue
        target="$(readlink -f "$fd" 2>/dev/null || true)"
        case "$target" in
            /dev/dri/card*|/dev/dri/renderD*)
                node="$(basename -- "$target")"
                candidate="/sys/class/drm/$node/device/gpu_busy_percent"
                if [[ -r "$candidate" ]]; then
                    GPU_SYS_BACKEND="sysfs-gpu_busy_percent"
                    GPU_SYS_PATH="$candidate"
                    return
                fi
                ;;
        esac
    done

    for candidate in /sys/class/drm/card*/device/gpu_busy_percent; do
        [[ -r "$candidate" ]] || continue
        GPU_SYS_BACKEND="sysfs-gpu_busy_percent"
        GPU_SYS_PATH="$candidate"
        return
    done

    if command -v nvidia-smi >/dev/null 2>&1; then
        GPU_SYS_BACKEND="nvidia-smi"
    fi
}

gpu_sys_sample() {
    local value=""
    case "$GPU_SYS_BACKEND" in
        sysfs-gpu_busy_percent)
            value="$(cat "$GPU_SYS_PATH" 2>/dev/null || true)"
            ;;
        nvidia-smi)
            value="$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -n 1 | tr -d '[:space:]')"
            ;;
        *)
            return 1
            ;;
    esac

    [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]] || return 1
    printf '%s\n' "$value"
}

has_hypr_drm_engine_stats() {
    local pid="$1"
    grep -h -q '^drm-engine-[^:]*:[[:space:]]*[0-9]' "/proc/$pid/fdinfo/"* 2>/dev/null
}

hypr_drm_engine_ns() {
    local pid="$1"
    local info client pdev engine_ns key
    local total=0
    declare -A seen_clients=()

    for info in "/proc/$pid/fdinfo/"*; do
        [[ -r "$info" ]] || continue
        IFS=$'\t' read -r client pdev engine_ns < <(awk '
            /^drm-client-id:/ { client = $2 }
            /^drm-pdev:/      { pdev = $2 }
            /^drm-engine-[^:]*:/ { engines += $2 }
            END {
                if (client == "") client = "-"
                if (pdev == "") pdev = "-"
                printf "%s\t%s\t%.0f\n", client, pdev, engines + 0
            }
        ' "$info")

        [[ "$engine_ns" =~ ^[0-9]+$ ]] || continue

        # Multiple fds can refer to the same DRM client. The kernel fdinfo
        # contract requires userspace to avoid double-accounting those stats.
        if [[ "$client" != "-" ]]; then
            key="${pdev}:$client"
        else
            key="fd:$info"
        fi
        [[ -z "${seen_clients[$key]+x}" ]] || continue
        seen_clients[$key]=1
        total=$((total + engine_ns))
    done

    printf '%s\n' "$total"
}

percent_from_ticks() {
    local delta_ticks="$1"
    local elapsed_ns="$2"
    awk -v ticks="$delta_ticks" -v hz="$CLK_TCK" -v ns="$elapsed_ns" '
        BEGIN {
            if (ns <= 0 || hz <= 0) { print ""; exit }
            printf "%.4f", ticks * 100.0 * 1000000000.0 / (hz * ns)
        }
    '
}

percent_from_busy_ns() {
    local delta_busy_ns="$1"
    local elapsed_ns="$2"
    awk -v busy="$delta_busy_ns" -v ns="$elapsed_ns" '
        BEGIN {
            if (ns <= 0) { print ""; exit }
            printf "%.4f", busy * 100.0 / ns
        }
    '
}

mean_file() {
    local path="$1"
    awk 'NF { sum += $1; n++ } END { if (n) printf "%.4f", sum / n; else print "nan" }' "$path"
}

p95_file() {
    local path="$1"
    local count
    count="$(awk 'NF { n++ } END { print n + 0 }' "$path")"
    if [[ "$count" -eq 0 ]]; then
        printf 'nan\n'
        return
    fi

    local index=$(((count * 95 + 99) / 100))
    sort -n "$path" | awk -v idx="$index" 'NR == idx { printf "%.4f", $1; exit }'
}

max_file() {
    local path="$1"
    awk 'NF { if (!seen || $1 > max) max = $1; seen = 1 } END { if (seen) printf "%.4f", max; else print "nan" }' "$path"
}

mib() {
    awk -v kb="$1" 'BEGIN { printf "%.2f", kb / 1024.0 }'
}

fmt_pct() {
    if [[ "$1" == "nan" || -z "$1" ]]; then
        printf 'N/A'
    else
        printf '%.2f%%' "$1"
    fi
}

HYPR_PID="$(resolve_hyprland_pid)"
select_gpu_sys_backend "$HYPR_PID"
HYPR_DRM_STATS=false
if has_hypr_drm_engine_stats "$HYPR_PID"; then
    HYPR_DRM_STATS=true
fi

GIT_SHA="$(git -C "$ROOT" rev-parse --short=12 HEAD 2>/dev/null || printf 'unknown')"
INITIAL_STYLE="$(surface_style)"

printf '===== VYNX RESOURCE BENCHMARK =====\n'
printf 'label=%s\n' "$LABEL"
printf 'git_sha=%s\n' "$GIT_SHA"
printf 'surfaceStyle=%s\n' "$INITIAL_STYLE"
printf 'hyprglass=%s\n' "$(hyprglass_state)"
printf 'runs=%s duration=%ss interval=%ss warmup=%ss restart_shell=%s\n' "$RUNS" "$DURATION" "$INTERVAL" "$WARMUP" "$RESTART_SHELL"
printf 'gpu_sys_backend=%s' "$GPU_SYS_BACKEND"
[[ -n "$GPU_SYS_PATH" ]] && printf ' (%s)' "$GPU_SYS_PATH"
printf '\n'
printf 'hypr_drm_fdinfo=%s\n' "$HYPR_DRM_STATS"
printf 'csv=%s\n\n' "$OUTPUT"

SUMMARY="$TMP_ROOT/summary.tsv"
printf '%s\n' $'run\tqs_pss\tqs_uss\tanon\tfile\tqtqml\thypr_pss\thypr_uss\tqs_cpu\thypr_cpu\tgpu_sys\thypr_gpu' > "$SUMMARY"

for ((run = 1; run <= RUNS; run++)); do
    [[ "$(surface_style)" == "$INITIAL_STYLE" ]] || fail "surfaceStyle changed during benchmark"

    if [[ "$RESTART_SHELL" == true ]]; then
        printf '[run %d/%d] restarting Quickshell...\n' "$run" "$RUNS"
        restart_shell
    fi

    QS_PID="$(resolve_single_qs_pid)"
    HYPR_PID="$(resolve_hyprland_pid)"

    if [[ "$WARMUP" -gt 0 ]]; then
        printf '[run %d/%d] warmup %ss...\n' "$run" "$RUNS" "$WARMUP"
        sleep "$WARMUP"
    fi

    RUN_DIR="$TMP_ROOT/run-$run"
    mkdir -p "$RUN_DIR"
    for metric in qs_pss qs_uss anon file qtqml hypr_pss hypr_uss qs_cpu hypr_cpu gpu_sys hypr_gpu; do
        : > "$RUN_DIR/$metric"
    done

    prev_qs_ticks="$(process_ticks "$QS_PID")" || fail "Quickshell exited before run $run"
    prev_hypr_ticks="$(process_ticks "$HYPR_PID")" || fail "Hyprland exited before run $run"
    prev_hypr_gpu_ns=""
    if [[ "$HYPR_DRM_STATS" == true ]]; then
        prev_hypr_gpu_ns="$(hypr_drm_engine_ns "$HYPR_PID" || true)"
    fi
    prev_time_ns="$(date +%s%N)"

    printf '[run %d/%d] sampling %d x %ss...\n' "$run" "$RUNS" "$SAMPLES" "$INTERVAL"

    for ((sample = 1; sample <= SAMPLES; sample++)); do
        sleep "$INTERVAL"

        now_time_ns="$(date +%s%N)"
        elapsed_ns=$((now_time_ns - prev_time_ns))

        now_qs_ticks="$(process_ticks "$QS_PID")" || fail "Quickshell exited during run $run"
        now_hypr_ticks="$(process_ticks "$HYPR_PID")" || fail "Hyprland exited during run $run"

        qs_cpu="$(percent_from_ticks "$((now_qs_ticks - prev_qs_ticks))" "$elapsed_ns")"
        hypr_cpu="$(percent_from_ticks "$((now_hypr_ticks - prev_hypr_ticks))" "$elapsed_ns")"

        read -r qs_pss qs_uss qs_anon qs_file < <(process_memory "$QS_PID") || fail "cannot read Quickshell memory"
        qtqml="$(qtqml_pss_kb "$QS_PID")"
        read -r hypr_pss hypr_uss _ _ < <(process_memory "$HYPR_PID") || fail "cannot read Hyprland memory"

        gpu_sys=""
        if value="$(gpu_sys_sample 2>/dev/null)"; then
            gpu_sys="$value"
        fi

        hypr_gpu=""
        if [[ "$HYPR_DRM_STATS" == true && -n "$prev_hypr_gpu_ns" ]]; then
            now_hypr_gpu_ns="$(hypr_drm_engine_ns "$HYPR_PID" || true)"
            if [[ "$now_hypr_gpu_ns" =~ ^[0-9]+$ && "$prev_hypr_gpu_ns" =~ ^[0-9]+$ ]]; then
                if ((now_hypr_gpu_ns >= prev_hypr_gpu_ns)); then
                    hypr_gpu="$(percent_from_busy_ns "$((now_hypr_gpu_ns - prev_hypr_gpu_ns))" "$elapsed_ns")"
                fi
                prev_hypr_gpu_ns="$now_hypr_gpu_ns"
            fi
        fi

        printf '%s\n' "$qs_pss" >> "$RUN_DIR/qs_pss"
        printf '%s\n' "$qs_uss" >> "$RUN_DIR/qs_uss"
        printf '%s\n' "$qs_anon" >> "$RUN_DIR/anon"
        printf '%s\n' "$qs_file" >> "$RUN_DIR/file"
        printf '%s\n' "$qtqml" >> "$RUN_DIR/qtqml"
        printf '%s\n' "$hypr_pss" >> "$RUN_DIR/hypr_pss"
        printf '%s\n' "$hypr_uss" >> "$RUN_DIR/hypr_uss"
        printf '%s\n' "$qs_cpu" >> "$RUN_DIR/qs_cpu"
        printf '%s\n' "$hypr_cpu" >> "$RUN_DIR/hypr_cpu"
        [[ -n "$gpu_sys" ]] && printf '%s\n' "$gpu_sys" >> "$RUN_DIR/gpu_sys"
        [[ -n "$hypr_gpu" ]] && printf '%s\n' "$hypr_gpu" >> "$RUN_DIR/hypr_gpu"

        printf '%s,%d,%d,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
            "$LABEL" "$run" "$sample" "$(date --iso-8601=seconds)" "$QS_PID" "$HYPR_PID" \
            "$qs_pss" "$qs_uss" "$qs_anon" "$qs_file" "$qtqml" "$hypr_pss" "$hypr_uss" \
            "$qs_cpu" "$hypr_cpu" "$gpu_sys" "$hypr_gpu" >> "$OUTPUT"

        prev_qs_ticks="$now_qs_ticks"
        prev_hypr_ticks="$now_hypr_ticks"
        prev_time_ns="$now_time_ns"
    done

    run_qs_pss="$(mean_file "$RUN_DIR/qs_pss")"
    run_qs_uss="$(mean_file "$RUN_DIR/qs_uss")"
    run_anon="$(mean_file "$RUN_DIR/anon")"
    run_file="$(mean_file "$RUN_DIR/file")"
    run_qtqml="$(mean_file "$RUN_DIR/qtqml")"
    run_hypr_pss="$(mean_file "$RUN_DIR/hypr_pss")"
    run_hypr_uss="$(mean_file "$RUN_DIR/hypr_uss")"
    run_qs_cpu="$(mean_file "$RUN_DIR/qs_cpu")"
    run_hypr_cpu="$(mean_file "$RUN_DIR/hypr_cpu")"
    run_gpu_sys="$(mean_file "$RUN_DIR/gpu_sys")"
    run_hypr_gpu="$(mean_file "$RUN_DIR/hypr_gpu")"

    printf '%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$run" "$run_qs_pss" "$run_qs_uss" "$run_anon" "$run_file" "$run_qtqml" \
        "$run_hypr_pss" "$run_hypr_uss" "$run_qs_cpu" "$run_hypr_cpu" "$run_gpu_sys" "$run_hypr_gpu" >> "$SUMMARY"

    if ((run < RUNS && COOLDOWN > 0)); then
        sleep "$COOLDOWN"
    fi
done

printf '\nRUN MEANS\n'
tail -n +2 "$SUMMARY" | while IFS=$'\t' read -r run qs_pss qs_uss anon file qtqml hypr_pss hypr_uss qs_cpu hypr_cpu gpu_sys hypr_gpu; do
    printf '%-18s PSS=%7sM USS=%7sM Anon=%7sM File=%7sM QtQml=%6sM HYPR_PSS=%7sM QS_CPU=%7s HYPR_CPU=%7s GPU_SYS=%7s HYPR_GPU=%7s\n' \
        "${LABEL}_r${run}" \
        "$(mib "$qs_pss")" "$(mib "$qs_uss")" "$(mib "$anon")" "$(mib "$file")" "$(mib "$qtqml")" "$(mib "$hypr_pss")" \
        "$(fmt_pct "$qs_cpu")" "$(fmt_pct "$hypr_cpu")" "$(fmt_pct "$gpu_sys")" "$(fmt_pct "$hypr_gpu")"
done

for metric in qs_pss qs_uss anon file qtqml hypr_pss hypr_uss qs_cpu hypr_cpu gpu_sys hypr_gpu; do
    : > "$TMP_ROOT/all-$metric"
    for ((run = 1; run <= RUNS; run++)); do
        cat "$TMP_ROOT/run-$run/$metric" >> "$TMP_ROOT/all-$metric"
    done
done

printf '\nALL-SAMPLE STATS\n'
printf 'QS_CPU   mean=%s p95=%s max=%s\n' \
    "$(fmt_pct "$(mean_file "$TMP_ROOT/all-qs_cpu")")" \
    "$(fmt_pct "$(p95_file "$TMP_ROOT/all-qs_cpu")")" \
    "$(fmt_pct "$(max_file "$TMP_ROOT/all-qs_cpu")")"
printf 'HYPR_CPU mean=%s p95=%s max=%s\n' \
    "$(fmt_pct "$(mean_file "$TMP_ROOT/all-hypr_cpu")")" \
    "$(fmt_pct "$(p95_file "$TMP_ROOT/all-hypr_cpu")")" \
    "$(fmt_pct "$(max_file "$TMP_ROOT/all-hypr_cpu")")"
printf 'GPU_SYS  mean=%s p95=%s max=%s\n' \
    "$(fmt_pct "$(mean_file "$TMP_ROOT/all-gpu_sys")")" \
    "$(fmt_pct "$(p95_file "$TMP_ROOT/all-gpu_sys")")" \
    "$(fmt_pct "$(max_file "$TMP_ROOT/all-gpu_sys")")"
printf 'HYPR_GPU mean=%s p95=%s max=%s\n' \
    "$(fmt_pct "$(mean_file "$TMP_ROOT/all-hypr_gpu")")" \
    "$(fmt_pct "$(p95_file "$TMP_ROOT/all-hypr_gpu")")" \
    "$(fmt_pct "$(max_file "$TMP_ROOT/all-hypr_gpu")")"
printf 'PSS      mean=%sM p95=%sM max=%sM\n' \
    "$(mib "$(mean_file "$TMP_ROOT/all-qs_pss")")" \
    "$(mib "$(p95_file "$TMP_ROOT/all-qs_pss")")" \
    "$(mib "$(max_file "$TMP_ROOT/all-qs_pss")")"
printf '\nCSV: %s\n' "$OUTPUT"
