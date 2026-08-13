# Vertical Bar Lifecycle A/B Results

Date: 2026-08-13

## Scope

- Baseline A: `1a2a3ac4` (original vertical-bar QML)
- Candidate B: `11f01673` (unloadable auto-hidden vertical bar)
- Display: `DP-3`, 5120×1440 at scale 1
- Configuration: II family, vertical left bar, auto-hide enabled, 2 px hover region
- Warm-up: 30 seconds per fresh process, exceeding the 20-second unload delay
- Run order: A1, B1, B2, A2, A3, B3
- Config SHA-256 before/after: `28e16f6816256cd7f9ea23771aa62106f46612458fafe913b5009df1927eb9e6`

## Raw idle samples

| Sample | PSS (MiB) | RSS (MiB) | VRAM (MiB) | Lifetime CPU (%) |
|---|---:|---:|---:|---:|
| A1 | 460.3 | 630.8 | 316.5 | 11.9 |
| B1 | 452.9 | 621.8 | 308.5 | 12.8 |
| B2 | 452.5 | 612.8 | 308.5 | 12.6 |
| A2 | 463.6 | 633.4 | 318.5 | 12.0 |
| A3 | 461.7 | 634.3 | 316.5 | 12.6 |
| B3 | 450.4 | 619.1 | 310.5 | 12.6 |

## Medians

| Metric | Baseline A | Candidate B | Candidate change |
|---|---:|---:|---:|
| PSS | 461.7 MiB | 452.5 MiB | **−9.2 MiB** |
| RSS | 633.4 MiB | 619.1 MiB | **−14.3 MiB** |
| VRAM | 316.5 MiB | 308.5 MiB | **−8.0 MiB** |
| Lifetime CPU | 12.0% | 12.6% | +0.6 percentage points |

Lifetime CPU includes startup and is not an idle-only measurement. The difference is within observed run variation and does not establish a CPU regression or improvement.

`nvtop --snapshot` reported process GPU utilization as either `0%` or `null`; NVIDIA `pmon` did not expose a usable per-process SM value for this graphics client. VRAM allocation was available and repeatable.

## Lifecycle observation

1. After 30 seconds, only `quickshell:verticalBarTrigger` existed.
2. Moving the pointer to `(1, 720)` created `quickshell:verticalBar` while retaining the trigger.
3. Revealed resources were 465.6 MiB PSS, 637.5 MiB RSS, and 318.8 MiB VRAM.
4. Returning the pointer to `(2964, 1351)` and waiting 22 seconds removed the full-bar layer.
5. Re-unloaded resources were 452.0 MiB PSS, 612.2 MiB RSS, and 308.5 MiB VRAM.

The within-process reveal-to-unload reduction was 13.6 MiB PSS, 25.3 MiB RSS, and 10.3 MiB VRAM.

## Runtime and regression checks

- Edge reveal: pass
- Delayed unload after pointer exit: pass
- Repeat reveal after unloading: pass
- Full bar absent while unloaded: pass
- Minimal trigger remains while unloaded: pass
- QML configuration load: pass
- Candidate versus exact-baseline warnings: no new warning after preserving `barLoader.monitorIndex`
- Automated suite: 48 pass, 0 fail
- Persistent configuration unchanged: pass
- Production `qs -c ii` restored: pass, PID `3532201`, PPID 1
- Super-key reveal: not exercised in the A/B sequence
- IPC open/close/toggle: preserved statically; not exercised against the temporary candidate
- Lock/unlock: not exercised against the temporary candidate
- Runtime auto-hide off/on: not exercised to avoid persistent configuration writes

## Decision

The pointer lifecycle works and the reduction is repeatable, but the median saving is much smaller than the projected 50–75 MiB PSS. The candidate adds a second Wayland trigger surface and approximately 110 net lines of lifecycle code for 9.2 MiB median PSS and 8.0 MiB median VRAM savings.

Final status: **rejected after user review**. With stability as the primary goal, the measured 9.2 MiB PSS and 8.0 MiB VRAM savings do not justify the additional Wayland surface, lifecycle state, and untested behavior paths. Revert implementation commit `11f01673`; retain this record, the design, and the lifecycle-policy tests for future reference.
