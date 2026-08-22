# k4 Dynamic Island Port — Status

Working branch: `agent/k4-bar-port`
Source spec: `docs/k4-bar-port/SPEC.md`
Tickets: `docs/k4-bar-port/TICKETS.md`
Pinned k4 source: `48993812c88f0af5d0c5345cd273467043b889f1`

## Current phase

`K4-02 — Faithful island shell and idle pill`: implementation and source review complete; first real-shell validation found two integration bugs, both fixed and awaiting retest.

Do not start dependent ticket K4-03 until the K4-02 lifecycle/recording retest passes or any remaining issue is fixed and re-reviewed.

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
- Media player selection now follows upstream k4 directly from live `Mpris.players.values`, including disappearance and later reappearance of the last MPRIS player.
- Active ii-vynx screen recording appears as k4's pulsing red dot plus `mm:ss` duration through the existing `Persistent.states.screenRecord` state.
- The idle pill uses existing ii-vynx MPRIS, Hyprland workspace, clock, and recording state rather than adding duplicate system owners.
- k4-derived files include source attribution through `licenses/k4-NOTICE.txt`; the repository's MIT text remains in `licenses/MIT.txt`.
- A new liquid-glass dashboard inset introduced by the moving base was made Standard-only so ii corner sidebars do not reserve phantom Standard-bar space in k4 mode.

## K4-02 live validation — round 1

Validated on the real shell on 2026-08-22:

- inverse-wing silhouette: passed;
- Top/Bottom reflection: passed;
- compact clock-only idle state: passed;
- workspace transition/cross-fade: passed;
- lock/unlock ownership: passed.

Findings:

1. **Media lifecycle regression** — media rendered when already active at shell startup, but after the last player exited and the pill returned to clock-only, starting media again did not restore artwork/visualizer. Diagnosis found the port was reading ii-vynx's mutable `MprisController.activePlayer`, while upstream k4 derives the active player directly from the live MPRIS player list. Fixed in `59ee919e` by restoring upstream live-player selection.
2. **Recording indicator regression** — recording state never appeared. Diagnosis found `K4IdlePill.qml` referenced `Persistent.states.screenRecord` without importing `qs.modules.common`, unlike ii-vynx's working Standard recording indicator. Fixed in `4a1e5abb` without changing recorder ownership or adding polling.
3. **Three workspace indicators** — not a bug. Upstream k4 intentionally displays a moving viewport of at most three workspaces even when four or more exist; preserve this until a later customization stage.
4. **Sidebar acceptance clarified** — in k4 mode the ii sidebar must not be displaced by an empty top/bottom strip reserved for the inactive Standard bar. The k4 island and ii sidebar remain independent surfaces; visual overlap behind the center island is acceptable at this stage.

Regression source coverage for both fixes was added in `6affea6b`.

The branch was then synced with liquid-glass base `2bc82dbec3428547866f6cd75e1dfc069c6dde1c`; that base change only forces the dashboard glass surface to repaint after inset geometry changes.

## K4-02 source review

### Standards

- k4-specific rendering remains under `modules/ii/k4bar/`.
- Existing Standard bar implementation files remain untouched.
- Existing ii services are consumed through their current public state; no duplicate notification, media, workspace, or recording owner was introduced.
- Continuous animation exists only while media is playing or recording is active, matching visible state.
- The k4 idle visualizer is state animation only; it does not launch `cava` or another persistent process.
- Variant-sensitive sidebar reservation is enforced at the integration seam.
- The two round-1 runtime regressions were fixed at their demonstrated integration seams rather than by adding timers or duplicated services.

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

The K4-01 source test previously passed 4/4. The K4-02 lifecycle regression assertions were added after round-1 validation and still require execution in the user's checkout.

The implementation environment cannot execute the user's Quickshell/Wayland compositor session, so QML runtime and visual checks remain a live-shell step.

## Required K4-02 retest

1. Pull/sync `agent/k4-bar-port`, run both k4 Node tests, and restart Quickshell.
2. Start with no MPRIS player. Launch a media app and begin playback; confirm the pill expands and shows artwork plus four bars.
3. Quit the media app completely; confirm the pill returns to clock-only.
4. Launch a media app again and begin playback; confirm media content returns without restarting Quickshell.
5. Pause and resume playback; confirm the pill contracts and expands correctly.
6. Start ii-vynx screen recording; confirm the pulsing red dot and `mm:ss` appear, and stop recording to confirm they disappear.
7. Trigger the existing ii sidebar from the configured corner; confirm there is no phantom full-width Standard-bar inset at the top/bottom while k4 is selected.
8. Treat the three-workspace moving viewport as expected upstream behavior for this stage.

## Next action after validation

Start `K4-03 — Island state + plugin arbitration`: introduce the first-class island state service, plugin interface/lifecycle, active-plugin priority arbitration, per-monitor expanded ownership, transient preemption, hover/focus policy, geometry publication, placement ownership, gestures, and temporary hiding/input suppression.
