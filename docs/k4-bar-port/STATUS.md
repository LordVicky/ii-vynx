# K4 Dynamic Island Port — Current Status

Working branch: `agent/k4-bar-port`
Base branch: `dev`
Source spec: `docs/k4-bar-port/SPEC.md`
Tickets: `docs/k4-bar-port/TICKETS.md`
Selected v1 design: `docs/k4-bar-port/K4-V1-SYNC-DESIGN.md`
Original K4 implementation reference: `48993812c88f0af5d0c5345cd273467043b889f1`
Selected K4 v1.0 reference: `adcf4216038f7881c4a589baafaaaec841377ad5`

## State

The selected K4 port is implemented and its requested live validation matrix is accepted.

The branch has been reconstructed directly on `dev` for a clean merge. The abandoned parent-project history and implementation are not part of the rewritten K4 ancestry or runtime tree. Historical point-in-time review documents tied to the old commit graph were removed during reconstruction; the durable spec, selected-v1 design, ticket plan and this status document remain authoritative.

## Delivered scope

K4 provides a mutually exclusive second bar implementation with Standard/K4 variant switching, top/bottom placement, 15/50/85 alignment, four space modes, idle/media/workspace/Clock/Volume behavior, notifications, Control Center, daily-driver utilities, in-island Settings, thin capture/record presentation, lean Displays, Player track-change peek, asymmetric measured sizing and active/requested-screen routing.

Built-ins remain directly/declaratively owned by `K4BuiltinPlugins.qml`; the managed plugin-lifecycle experiment is withdrawn and is not part of current architecture.

## Ownership invariants

- one owner per global desktop facility;
- no new daemon or persistent helper service;
- no duplicate MPRIS, audio, notification, network, clipboard, session, workspace or monitor owner;
- Displays remains monitor-layout only and does not own dynamic workspace routing;
- capture remains a thin adapter over existing shell capture/record facilities;
- K4 retains its own dark visual language and does not absorb unrelated Standard-bar surface experiments.

## Stabilization evidence

The accepted stabilization work includes viewport-owned hover tracking for Wi-Fi/Bluetooth and Launcher, immediate Sound-row hover feedback, fullscreen launcher routing, removal of the obsolete K4-03 demo/debug host harness, and a targeted Hyprland `no_anim` rule for the `quickshell:k4bar` layer that resolved the bottom passive-hover double-spawn regression while leaving K4's QML animation ownership intact.

Issue #22 remains open as a tracker unless explicitly closed later; the runtime regression itself is accepted as fixed.

## Validation status

The requested K4 source/live validation bundle and final manual matrix were accepted before the clean-history reconstruction.

The reconstruction preserves the selected K4 implementation while removing abandoned-parent ancestry and unrelated runtime code. The final reconstruction audit verifies that `dev` is the merge base, only selected K4 integration/runtime/test/docs files differ from `dev`, abandoned-parent runtime/workflow/data artifacts are absent, retired surface-backend dependencies are absent from K4 integration seams, and Standard/K4 ownership boundaries remain intact.

This agent environment cannot clone the public repository directly, so post-reconstruction Node execution is recorded as unavailable rather than fabricated. A focused source/runtime smoke after pulling the rewritten branch remains the final merge-side confidence check.

## Deferred debt

- Issue #22 may be closed only by an explicit issue-closure decision.
- Reverse workspace animation can still skip the preferred shrink/grow sequence on some reverse transitions; it remains non-blocking presentation debt.
- Real multi-monitor Displays relative placement/per-monitor fullscreen behavior remains hardware-dependent when multi-monitor hardware is unavailable.
