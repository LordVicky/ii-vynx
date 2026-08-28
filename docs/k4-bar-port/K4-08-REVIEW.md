# K4-08 — k4 Settings Inside the Island Review

Branch: `agent/k4-bar-port`

Ticket: `K4-08 — k4 settings inside the island`

Implementation base: `1099df8601af7522129b5eb7ed8b31058ed9839c` (post-K4-07 runtime remediation baseline)

Final code review point: `025bde275a61c8c432dfe7090dcf708da5e7d85e`

Pinned k4 source: `48993812c88f0af5d0c5345cd273467043b889f1`

Authoritative plan: `docs/k4-bar-port/SPEC.md` + `docs/k4-bar-port/TICKETS.md`

## State

**Validated and closed on 2026-08-24.**

> Current-architecture note: the plugin enable/status portion documented below was later withdrawn together with K4-11 managed lifecycle work. The in-island Settings surface, tray/notification behavior, Files fallback, and other unrelated K4-08 fixes remain. See `K4-11-DESIGN.md` and current `SPEC.md`.

K4-08 now has a complete in-island Settings application, persisted K4 runtime preferences, static-registry plugin enable/status controls, focused-notification dismissal, tray-in-pill behavior, and the final Files fallback remediation discovered during live validation.

The final local K4 regression gate passes **110/110** tests with zero failures. Node emits `MODULE_TYPELESS_PACKAGE_JSON` reparsing warnings for the ESM-style source-regression tests; those warnings do not fail the suite and do not affect Quickshell runtime behavior.

## Delivered Settings surface

Implemented inside the K4 island:

- Settings application/plugin at pinned priority/geometry semantics;
- top/bottom position backed by `Config.options.bar.k4.position`;
- left/center/right alignment backed by `Config.options.bar.k4.alignment`;
- `trayInPill` preference;
- `notificationsOnHover` preference;
- `dismissNotificationsOnFocus` preference;
- persisted `disabledPlugins` state;
- plugin rows showing Loaded / Disabled / Error state.

The external ii **Bar Settings** page remains the top-level Standard ↔ K4 variant boundary. K4 Settings does not create a second settings file or persistence owner.

## Plugin lifecycle boundary

K4-08 intentionally keeps the static built-in registry. K4-11 remains responsible for true dynamic instantiation/loading parity.

At this stage:

- disabled plugins stop participating in arbitration;
- persisted disabled state survives restart;
- stateful plugins close/reset before re-enable so stale `open` state cannot cause a spontaneous reopen;
- passive Clock / Player / Volume owners opt out of the base close-on-disable assignment so their bound `active` expressions are not severed;
- loader state is surfaced as plugin error status.

Idle, Settings, Control Center, and Applications remain protected recovery roots during the static-registry stage so users cannot disable every GUI route back to Settings. This is a staged divergence to be revisited with the fuller K4-11 lifecycle model.

## Live remediation discovered during validation

### Collapsed tray width release

The first live tray toggle showed that hiding tray icons did not restore the short idle pill because the containing layout retained the tray row's implicit width.

The idle pill now decomposes the right-side reservation explicitly and counts tray width only while `trayInPill` is active. Live retest confirms enabling expands the pill and disabling immediately returns to the short clock pill.

### Notification dismissal on focused application

The first focus test failed because Quickshell can expose `Hyprland.activeToplevel` directly as a `HyprlandToplevel`, while the initial adapter only handled the Wayland `Toplevel` bridge shape.

`K4Notifications` now accepts both forms and resolves direct Hyprland toplevels through the existing address-indexed `HyprlandData` cache. A Kitty `notify-send` focus test passes in the live shell.

### Files without `fd`

Live validation established that the machine has no `fd` executable. The original helper swallowed that missing dependency and returned an empty result set.

Files now keeps `fd` / `fdfind` as the preferred fast path but falls back to bounded native Python traversal when neither exists. The helper returned real results for `conf` without `fd`, and the actual Files island populated 60 results in the live shell.

## Automated evidence

Final local source gate on 2026-08-24:

- tests: 110
- pass: 110
- fail: 0
- cancelled: 0
- skipped: 0
- todo: 0

Coverage includes all accumulated K4 regression seams plus K4-08 settings persistence, plugin lifecycle/status, tray width release, notification-focus compatibility, and no-`fd` Files fallback.

## Live validation — 2026-08-24

Validated in the real shell:

- Settings opens from the Applications grid and through its IPC route;
- K4 position changes immediately;
- K4 alignment changes immediately;
- position/alignment persist after restart;
- tray-in-pill enables correctly and disabling restores the short pill;
- notification history on hover obeys the setting;
- focus-based notification dismissal works with the setting enabled;
- plugin disable/re-enable works and persists without spontaneous reopening;
- protected utilities are not user-disableable;
- Files backend works without `fd` and Files UI renders real results;
- no new K4/Quickshell runtime warnings were introduced during the validation matrix.

## Standards review

No blocking findings at final code review point `025bde275a61c8c432dfe7090dcf708da5e7d85e`.

- Settings persistence remains in the existing ii `Config` tree rather than adding a second state owner.
- Only settings with live consumers are exposed.
- Global facilities retain existing owners; K4 continues to use narrow adapters.
- Plugin enablement is implemented at the existing controller seam rather than scattered through views.
- Passive bound plugin state is protected from destructive imperative assignment.
- The Files fallback removes an undeclared dependency while keeping work demand-driven.
- Focus dismissal reuses `HyprlandData` rather than introducing a second compositor query owner.
- The tray fix is isolated to idle-pill width accounting.
- Standard bar behavior and Liquid Glass styling are not modified by K4-08.
- Test-maintenance commits after live validation changed tests only; no runtime behavior was altered to make stale assertions pass.

## Spec review

K4-08 satisfies its approved ticket/spec boundary at its historical review point:

- K4 Settings exists inside the island;
- top/bottom and alignment share the existing `Config.options.bar.k4` persistence path;
- K4-specific settings were added only with consuming behavior;
- plugin enable/disable/error status was visible at that review point;
- disabled state persisted and participated correctly in arbitration at that review point;
- the external ii Bar Settings variant boundary remained intact;
- no disconnected capture/editor/game/plugin-store settings were introduced ahead of their consuming tickets.

The plugin enable/status and K4-11 lifecycle portions were later withdrawn; this review remains historical evidence for the other K4-08 behavior.

## Closure

K4-08 is closed. Proceed to `K4-09 — Capture/record/editor toolchain` using grill-with-docs before implementation, because the ticket intentionally requires inspection of pinned upstream capture/editor behavior and ii-vynx's existing capture facilities before decomposition.
