# k4 Dynamic Island Port — Status

Working branch: `agent/k4-bar-port`
Source spec: `docs/k4-bar-port/SPEC.md`
Tickets: `docs/k4-bar-port/TICKETS.md`
Pinned k4 source: `48993812c88f0af5d0c5345cd273467043b889f1`

## Current phase

`K4-02 — Faithful island shell and idle pill`: implementation and source review complete; real-shell validation pending.

Do not start dependent ticket K4-03 until the K4-02 compositor/visual smoke test passes or any discovered issue is fixed and re-reviewed.

## K4-01 — validated

The user validated K4-01 in the live shell on 2026-08-22.

Observed:
- Bar Settings exposes Standard and k4 Dynamic Island variants.
- k4 Position and Alignment controls are visible while Standard-only settings are hidden.
- k4 mode replaces the Standard bar with the inert checkpoint capsule.
- `node --test tests/k4-bar-variant.test.js` passed 4/4 with zero failures.

K4-01 is closed.

## K4-02 implemented

- k4 visual tokens live in `modules/ii/k4bar/K4Theme.qml`.
- The host uses k4's black surface, 16px wings, 34px collapsed height, and 880px surface ceiling.
- The placeholder rectangle is replaced by the inverse-wing `Shape` silhouette.
- The silhouette is reflected vertically for bottom placement instead of maintaining a second path.
- The shape uses 8x MSAA as upstream does for the concave wing arcs.
- The layer reserves only the 34px collapsed strip.
- Surface height grows immediately and uses the upstream 520ms delayed shrink path.
- Island width/height use the upstream OutBack timings.
- The pointer mask is restricted to the island geometry.
- The collapsed body width is measured from symmetric left/right side reserves so the center remains physically centered.
- Clock uses the k4 24-hour `HH:mm` presentation and k4 typography/colors.
- Workspace dots temporarily replace the clock for 1800ms after a workspace change, with the upstream three-workspace moving window.
- Playing media shows 20px artwork plus the upstream lightweight four-bar visualizer; no new audio-analysis process was added.
- Active ii-vynx screen recording appears as k4's pulsing red dot plus `mm:ss` duration.
- The idle pill uses existing ii-vynx MPRIS, Hyprland workspace, clock, and recording state rather than adding duplicate system owners.
- k4-derived files include source attribution through `licenses/k4-NOTICE.txt`; the repository's MIT text remains in `licenses/MIT.txt`.
- A new liquid-glass dashboard inset introduced by the moving base was made Standard-only so ii corner sidebars do not reserve phantom Standard-bar space in k4 mode.

## K4-02 source review

### Standards

- k4-specific rendering remains under `modules/ii/k4bar/`.
- Existing Standard bar implementation files remain untouched.
- Existing ii services are consumed through their current public state; no duplicate notification, media, workspace, or recording owner was introduced.
- Continuous animation exists only while media is playing or recording is active, matching visible state.
- The k4 idle visualizer is state animation only; it does not launch `cava` or another persistent process.
- Variant-sensitive sidebar reservation is enforced at the integration seam.

### Spec

K4-02 matches the approved ticket for:
- 34px collapsed reservation semantics;
- pixel-faithful inverse wings;
- top/bottom reflection;
- width/height animation shell and delayed shrink;
- input mask scoped to island geometry;
- faithful idle clock/workspace/media composition;
- symmetric side-width measurement;
- all-monitor idle behavior inherited from K4-01;
- k4 attribution before substantial derived rendering code.

Upstream-only right-side indicators that depend on k4-specific subsystems (game, minimized modules, plugin installer state) remain for the tickets that introduce those subsystems. The existing ii screen-recording state is already represented.

## Automated checks

Run from the repository root:

```bash
node --test tests/k4-bar-variant.test.js tests/k4-idle-shell.test.js
```

The implementation environment cannot execute the user's Quickshell/Wayland compositor session, so QML runtime and visual checks remain a live-shell step.

## Required K4-02 manual validation

1. Pull/sync `agent/k4-bar-port`, run both k4 Node tests, and restart Quickshell.
2. Select k4 mode with Position = Top and Alignment = Center.
3. Confirm the capsule is now edge-attached with concave inverse wings rather than a floating rounded rectangle.
4. Switch Top ↔ Bottom and confirm the exact silhouette reflects correctly while text/content stays upright.
5. With no media playing and no recording, confirm the pill is compact and the clock is centered.
6. Start media playback. Confirm the pill widens smoothly, artwork appears left of the four animated bars, and the clock remains centered rather than shifting.
7. Pause playback. Confirm the artwork/bars disappear and the pill returns smoothly to its compact width.
8. Change workspaces. Confirm the clock cross-fades to a moving window of up to three workspace dots, then returns after roughly 1.8 seconds.
9. Start ii-vynx screen recording. Confirm the right side shows the pulsing red recording indicator and duration, with equal space reserved on the left so the clock remains centered.
10. Verify Left/Center/Right alignment and Top/Bottom placement still work with the new silhouette.
11. Open the ii dashboard/sidebar through the configured corner behavior and confirm it does not leave a phantom Standard-bar inset while k4 is selected.
12. Lock/unlock and confirm the k4 surface still yields to the lock screen.

## Next action after validation

Start `K4-03 — Island state + plugin arbitration`: introduce the first-class island state service, plugin interface/lifecycle, active-plugin priority arbitration, per-monitor expanded ownership, transient preemption, hover/focus policy, geometry publication, placement ownership, gestures, and temporary hiding/input suppression.
