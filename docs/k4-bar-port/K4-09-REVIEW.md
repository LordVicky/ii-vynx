# K4-09 — Capture/Recording Review

Branch: `agent/k4-bar-port`

Ticket: `K4-09 — Capture/record/editor toolchain`

Implementation base: `0bd797c970c7ad61f4bbce118333728cb14a105c` (K4-08 closure)

Scope decision: `7d24c076ed27ffed31edc4397880eab994a526fe`

Final code review point: `5c55f697b7d2fdacc71c7508525cf794f6fd7a20`

Pinned k4 source: `48993812c88f0af5d0c5345cd273467043b889f1`

Authoritative plan: `docs/k4-bar-port/SPEC.md` + `docs/k4-bar-port/TICKETS.md` + `docs/k4-bar-port/K4-09-DESIGN.md`

## State

**Validated and closed on 2026-08-24.**

K4-09 deliberately implements the useful K4 capture/recording shell surface as a thin island application over ii-vynx's existing capture owners. The heavyweight upstream editor/transcription/render stack is intentionally excluded by the approved K4-09 scope decision rather than silently omitted.

The final local K4 regression gate passes **111/111** tests with zero failures. The complete live capture/recording matrix also passes.

## Delivered surface

The K4 Applications grid now includes a Capture application with:

- Screenshot region;
- Screenshot screen to clipboard;
- Record region with sound;
- Record screen with sound;
- current recording duration from existing persistent recording state;
- Stop recording while an ii-vynx recording is active;
- keyboard navigation and Escape/close behavior;
- temporary island suppression before screenshot acquisition.

While a recording is already active, the two start-recording actions are disabled and no-op. The dedicated Stop recording action is the only recording-lifecycle command exposed in that state.

## Ownership and dependency boundary

No second capture or recording owner was introduced.

K4 delegates to existing facilities:

- region screenshot and region recording use the existing `region` IPC target / RegionSelector;
- recording uses the existing `Directories.recordScriptPath` / `record.sh` owner;
- `wf-recorder` lifecycle remains owned by the existing recording script;
- recording active/time state comes from `Persistent.states.screenRecord`;
- fullscreen screenshot uses the same already-installed `grim - | wl-copy` primitive used by the existing Recorder UI;
- `IslandState.hidden` remains the host-owned suppression seam.

No new daemon, service singleton, long-lived process, Python capture tool, editor subsystem, transcription stack, `gpu-screen-recorder` dependency, or package dependency was added.

## Source validation — 2026-08-24

User-run full K4 source gate:

- tests: 111
- pass: 111
- fail: 0
- cancelled: 0
- skipped: 0
- todo: 0

The new focused regression is `tests/k4-capture.test.js`, and all accumulated K4-01 through K4-08 regressions remain green.

Node emits existing `MODULE_TYPELESS_PACKAGE_JSON` reparsing warnings for several ESM-style test files. They do not fail the suite and are not introduced by K4-09 runtime code.

## Live validation — 2026-08-24

The complete live matrix passed:

1. Capture appears in Applications and opens/closes correctly.
2. Region screenshot works through the existing frozen RegionSelector and the K4 island is absent from the acquired screenshot.
3. Fullscreen screenshot works and temporarily suppresses the K4 island before acquisition.
4. Region recording with sound works; `pgrep -a wf-recorder` showed exactly one recorder process.
5. Existing recording state/timer remains authoritative; reopening Capture during recording shows elapsed time, disables start actions, and exposes Stop recording.
6. Stop recording finalizes through the existing owner and returns recording state inactive.
7. Fullscreen recording works through the existing `record.sh` focused-monitor path.
8. The runtime log contains no K4-09-specific QML load, binding, process-ownership, or capture errors.

The supplied runtime log still contains warnings/errors from pre-existing shared areas including RegionSelector toolbar binding, FloatingActionButton/Revealer, ToolbarPairedFab, NotesWidget, Persistent `popupRect`, translation/extensions, desktop-entry parsing, media artwork/MPRIS, Bluetooth connection retries, QuickSliders, and tray DBus state. K4-09 does not modify those files/owners, and the affected capture paths pass live. They are therefore not K4-09 blockers.

## Standards review

No blocking findings at fixed code review point `5c55f697b7d2fdacc71c7508525cf794f6fd7a20`.

- The implementation is a narrow island-facing adapter rather than a duplicate global capture subsystem.
- The K4 plugin/view are local to `modules/ii/k4bar/`; existing RegionSelector and recorder implementations are unchanged.
- Recording state has one owner and one timer source.
- The plugin only releases `IslandState.hidden` when it acquired suppression itself, avoiding interference with another suppression owner.
- Pending screenshot suppression is released on normal timers and plugin destruction.
- Start-recording actions are guarded while a recording is active, avoiding accidental toggle/stop behavior through `record.sh`.
- The K4 registry change is limited to adding the Capture application.
- Standard bar, Liquid Glass, notification ownership, audio ownership, and existing recorder UI are not modified.
- The implementation adds no new package/dependency requirement.

One accepted implementation tradeoff is that screenshot suppression release uses bounded timers because the existing cross-IPC RegionSelector/fullscreen screenshot paths do not expose a completion callback to the K4 plugin. Live acquisition tests validate the current timings. A future shared capture API could replace this timing seam if ii-vynx introduces one, but adding such infrastructure solely for K4-09 would be broader than the approved scope.

## Spec review

K4-09 satisfies the approved scoped interpretation of the ticket:

- capture/region/recording workflow is available from the K4 island;
- screenshot acquisition temporarily hides the island and removes its input through the existing host suppression seam;
- preview/editor/file-dialog functionality is not invented where the approved lightweight scope has no consuming workflow;
- recording lifecycle and state reuse ii-vynx's existing owner;
- dependency ownership was explicitly inspected and no new dependency was required;
- no competing `wf-recorder` or screenshot service exists;
- source and real-shell validation both pass.

The original ticket's editor/toolchain bullets were decomposed after inspection as explicitly permitted by `TICKETS.md`. The approved `K4-09-DESIGN.md` records the intentional exclusion of the upstream image/video editor, project/timeline/layer system, transcription/render helpers, editor file dialogs, camera editing, and `gpu-screen-recorder` dual-track path. Those application-sized subsystems are not deferred implementation debt for K4-09; they are outside the approved port scope unless separately reconsidered by the user.

## Closure

K4-09 is closed.

Next ticket: `K4-10 — Remaining bundled k4 plugins/features`.

K4-10 must begin with inventory/alignment before implementation. For each remaining upstream bundled feature, classify it as: adapt an existing ii owner, port a genuinely K4-local feature, or explicitly document an unavailable/unwanted dependency. Any heavyweight subsystem or new dependency must stop at the decision boundary for explicit user approval before implementation.