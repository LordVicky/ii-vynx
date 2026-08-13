# Vertical Bar Lifecycle Optimization Design

## Objective

Reduce the idle RAM used by the Illogical Impulse vertical bar without changing normal always-visible behavior or making the auto-hidden bar unreliable. The change applies only when `Config.options.bar.autoHide.enable` is true.

The measured opportunity is approximately 50–75 MiB PSS and 11–20 MiB VRAM while the full bar is unloaded. The result must be validated experimentally; these figures are targets, not acceptance assumptions.

## Stability constraints

- Work only on the local `dev` branch in `/home/lordvicky/.git/ii-vynx`.
- Keep each independently reversible behavior change in its own commit.
- Do not change the horizontal bar, Waffle panel family, sidebar lifecycle, background, widgets, or startup services in this work.
- Preserve existing bar IPC and global shortcut behavior.
- Preserve multi-monitor filtering through `Config.options.bar.screenList`.
- Preserve screen locking, wrapped-frame reloads, left/right placement, exclusive-zone behavior, Super-key reveal, pointer reveal, and focus-grab registration.
- When auto-hide is disabled, retain the existing always-loaded behavior.
- Do not modify the user's persistent `~/.config/illogical-impulse/config.json` during automated validation.

## Approaches considered

### 1. Unload only `VerticalBarContent`

Keep the existing full-width `PanelWindow` alive and unload its delegates after hiding. This is the smallest change, but it cannot recover the measured window/controller allocation and therefore misses the primary optimization target.

### 2. Persistent edge trigger plus unloadable full bar — selected

For each configured screen, keep a narrow transparent Wayland trigger surface alive while auto-hide is enabled. Instantiate the existing full `PanelWindow` only for reveal and its delayed grace period. This targets both the window and content allocations while preserving reliable pointer activation.

### 3. Destroy the entire vertical-bar scope

Unload `VerticalBar.qml` at the panel-family level and use a separate global activation subsystem. This has the broadest potential saving but duplicates monitor/configuration logic across modules and carries more regression risk.

Approach 2 provides the best balance of measurable savings, locality, and rollback safety.

## Component design

`IllogicalImpulseFamily.qml` continues loading `VerticalBar.qml` whenever vertical mode is selected. This keeps the public bar IPC handlers and global shortcuts stable.

Inside `VerticalBar.qml`, each screen variant becomes a lifecycle controller with two surfaces:

1. A persistent edge-trigger `PanelWindow`, active only while auto-hide is enabled, the bar is globally open, and the screen is unlocked. Its input region is limited to the configured hover width, with a minimum usable width of 2 logical pixels.
2. The existing full bar `PanelWindow`, moved behind a `LazyLoader`. It remains active whenever auto-hide is disabled or the controller is in its revealed/grace-period state.

The trigger surface must remain transparent, use no exclusive zone, and avoid loading `VerticalBarContent`, bar delegates, shadows, or decorators.

## Lifecycle and data flow

When auto-hide is disabled, the full bar loads immediately and remains loaded. The trigger surface is inactive.

When auto-hide is enabled:

1. Entering the edge trigger requests reveal and loads the full bar.
2. The full bar owns the existing slide-in animation and remains loaded while its hover region contains the pointer.
3. Leaving both trigger and full-bar hover regions starts a 20-second unload timer.
4. Re-entering either region cancels the timer.
5. When the timer expires, the full bar is destroyed and only the trigger remains.
6. Pressing Super follows the existing configured reveal delay, loads the full bar, and keeps it revealed while Super remains held.
7. IPC `bar close` and the close shortcut disable both surfaces through `GlobalStates.barOpen`; `bar open` restores the appropriate auto-hide or always-visible state.
8. Locking the screen destroys both surfaces. Unlocking recreates the appropriate state.

The lifecycle controller, not the unloadable full window, owns the unload timer and Super-key state. This prevents destruction from erasing the state needed to reveal the bar again.

## Failure-safe behavior

- Clamp the activation width to at least 2 logical pixels so a malformed zero/negative hover-width setting cannot make the bar unreachable.
- Cancel pending unload whenever auto-hide is disabled, the pointer returns, or Super reveal becomes active.
- Never unload while the full bar reports pointer hover or Super reveal.
- Configuration changes that move the bar or alter the screen list continue to flow through the existing QML bindings and `Variants` model.
- If lazy creation fails, the trigger remains available and repeated pointer entry can retry loading; no persistent setting is changed.

## Test seams

The public seams for automated regression checks are:

- Static QML contract: the controller keeps activation and unload state outside the full-window loader.
- State policy: always-visible mode keeps the full bar loaded; auto-hide mode loads on pointer/Super demand and unloads only after the grace period.
- Existing public control surface: IPC handler names `toggle`, `close`, and `open`, plus shortcuts `barToggle` and `barOpen`, remain present.

Runtime acceptance checks exercise the real shell rather than QML internals:

- Pointer reveal and delayed hide on every configured monitor.
- Super-key reveal with the configured delay.
- IPC open, close, and toggle.
- Screen lock/unlock.
- Switching auto-hide off and on at runtime.
- Left/right vertical-bar placement.
- No QML warnings or errors introduced during the test sequence.

## Resource verification

Use equal-age A/B runs from the same `dev` revision apart from the optimization commit. Alternate baseline and candidate order and run at least three samples per state.

Record:

- Process RSS and PSS from `/proc/<pid>/smaps_rollup`.
- Allocated VRAM and per-process GPU utilization from `nvtop` snapshots.
- CPU utilization while idle and during five identical reveal/hide cycles.
- Memory while the full bar is revealed and after the 20-second unload deadline.

The optimization is accepted only if behavior checks pass and the unloaded state shows a repeatable PSS reduction outside normal sample variance. If the result is unstable or materially regresses reveal behavior, revert the implementation commit while retaining the measurement record.

## Commit boundaries

1. Design and implementation plan documentation.
2. Regression test for the lifecycle policy and preserved public controls.
3. Minimal lifecycle implementation.
4. Measurement record only after repeatable A/B validation.

Each boundary can be reverted independently. No later optimization is combined with this work.
