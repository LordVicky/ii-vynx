# K4-09 — Capture/Recording Scope and Ownership

Branch: `agent/k4-bar-port`

Pinned k4 source: `48993812c88f0af5d0c5345cd273467043b889f1`

Decision date: 2026-08-24

## Goal

Port the useful K4 capture/recording **shell experience** without creating a second screenshot, region-selection, recording, or media-processing owner inside ii-vynx.

K4 is a presentation/reference source here, not a requirement to import every application bundled upstream.

## Hard ownership rule

Global desktop facilities keep their existing ii-vynx/Quickshell owner. K4-09 may add only a narrow island-facing adapter/controller over those owners.

Before adding any external dependency, daemon, persistent process owner, or heavyweight application subsystem that ii-vynx does not already provide, stop implementation and request explicit user approval.

## Existing facilities to reuse

### Region screenshot / selection

`modules/ii/regionSelector/RegionSelector.qml` already owns the Quickshell region-selection entry point and exposes the `region` IPC target.

Its current actions include:
- `region screenshot`;
- `region record`;
- `region recordWithSound`.

The underlying RegionSelection path already owns its frozen-screen selection UI and screenshot/record command construction.

### Full-screen screenshot

The existing Recorder overlay already performs a full-screen clipboard screenshot with `grim - | wl-copy`. K4 may invoke the same installed primitive; it must not create a second screenshot daemon or long-lived service.

### Recording

`scripts/videos/record.sh` remains the recording owner used by the shell. It already provides:
- fullscreen recording;
- explicit-region recording;
- optional system audio;
- `wf-recorder` lifecycle;
- active recording state/timer publication through `Persistent.states.screenRecord`.

K4 must not launch or manage its own competing `wf-recorder` service.

### Island suppression

`IslandState.hidden` remains the host-owned temporary rendering/input suppression seam. Screenshot actions may borrow it briefly so K4 is not baked into the captured frame.

## K4-09 scoped feature

The K4 Applications grid gains a Capture utility with the K4 visual language and actions for:
- screenshot region;
- screenshot screen to clipboard;
- record region with sound;
- record screen with sound;
- stop the currently active ii-vynx recording.

The utility reads `Persistent.states.screenRecord` for recording state rather than introducing another timer/state owner.

## Explicit non-goals

Do **not** port these upstream Captura areas in K4-09:
- image/video editor;
- timeline/layers/audio-track editor;
- transcription;
- video project files;
- editor render/analysis Python tooling;
- upstream file-dialog flows that exist only for the editor;
- `gpu-screen-recorder` dual-track path;
- camera/webcam editing features.

The upstream editor/process stack (`Editor.qml`, `EditorProcesos.qml`, `tools/editar.py`, `tools/transcribir.py`, and related Captura editor views) is intentionally excluded as heavyweight application functionality.

System-dialog suppression remains available in `IslandState`, but K4-09 does not add a new system file-dialog workflow because the approved capture/recording scope does not need one.

## Dependency gate

The approved first implementation requires no new external dependency. It reuses tools already exercised by ii-vynx: Quickshell RegionSelector, `grim`, `wl-copy`, `wf-recorder`, `pactl`, and the existing recording script/state path.

If later K4 work encounters an editor, wallpaper browser/manager, plugin store, transcription stack, or similar application-sized subsystem, stop before implementation and present the dependency/ownership cost for approval.

## Acceptance boundary

K4-09 is complete when the in-island Capture utility can launch the existing screenshot/recording workflows, temporary screenshot suppression works, recording state/stop behavior follows ii-vynx's existing owner, no duplicate capture/recording owner exists, no new dependency is introduced, and the live shell/regression matrix passes.
