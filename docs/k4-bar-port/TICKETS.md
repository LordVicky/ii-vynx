# k4 Dynamic Island Port — Tracer Tickets

Source spec: `docs/k4-bar-port/SPEC.md`
Working branch: `agent/k4-bar-port`

Each ticket must be reviewed against the spec before the next dependent ticket starts. Prefer one behavior-bearing commit per vertical slice; when a slice necessarily spans several mechanical commits, review the aggregate diff at the ticket boundary.

## K4-01 — Variant ownership seam

**Goal:** prove that ii-vynx can switch bar ownership without changing the standard bar implementation.

Deliver end-to-end:
- add `Config.options.bar.variant`, default `standard`;
- add minimal `bar.k4.position` and `bar.k4.alignment` config;
- gate every standard horizontal/vertical bar surface and Liquid Glass bar helper surface behind `variant === "standard"`;
- add a minimal `modules/ii/k4bar/K4Bar.qml` host and load it only for `variant === "k4"`;
- add a top-level Bar Settings variant selector;
- expose k4 top/bottom and alignment settings while k4 is selected;
- hide standard-only Bar Settings when k4 is selected;
- do not add k4 functional plugins yet.

**Acceptance:** Standard is unchanged by default; selecting k4 leaves exactly one inert k4 surface per eligible monitor; selecting Standard restores the existing bar and its saved configuration.

**Checks:** QML parse/load, Standard top/bottom smoke test, variant switch smoke test, no simultaneous standard+k4 panel surfaces.

## K4-02 — Faithful island shell and idle pill

**Goal:** replace the inert surface with the real k4 edge-attached shell and collapsed content.

Deliver end-to-end:
- upstream 34px collapsed reservation semantics;
- pixel-faithful inverse wings and reflected bottom geometry;
- width/height animation shell and delayed surface shrink;
- input mask scoped to island geometry;
- active/focused screen helpers needed for later expansion;
- idle pill with centered clock, temporary workspace indicator, media artwork/visualizer, and right indicators supported by existing data;
- symmetric side-width measurement;
- multi-monitor idle pill behavior;
- k4 MIT attribution/license entry before substantially copied code lands.

**Acceptance:** idle appearance and top/bottom geometry visually match pinned k4; standard bar still unaffected.

## K4-03 — Island state + plugin arbitration

**Goal:** establish the deep host/state/plugin seam before adding complex views.

Deliver end-to-end:
- ii-owned `IslandState` singleton with upstream semantics;
- base island plugin interface;
- enabled lifecycle and safe view loading;
- highest-priority active plugin wins;
- idle fallback;
- requested/active monitor routing;
- open/expanded publication;
- transient preemption;
- hover-exit timer policy;
- Escape/focus policy;
- temporary placement ownership and physical gesture requests;
- geometry publication per monitor;
- temporary hidden/input suppression mechanism.

**Acceptance:** a small test/demo plugin can open, resize the island, close to idle, route to the correct monitor, and preempt a transient without breaking another plugin.

## K4-04 — Core media/clock/volume parity

**Goal:** make the island behave like k4 during ordinary desktop use.

Deliver end-to-end:
- service adapters for ii media/audio/clock/workspaces;
- k4 player expansion and transport/seek behavior;
- k4 clock hover view behavior;
- k4 external-volume-change HUD semantics;
- artwork and visualizer behavior;
- preserve k4 activation defaults.

**Acceptance:** no media, paused, playing, track changes, seek, external volume changes, and hover transitions match k4 behavior.

## K4-05 — Notifications and transient arbitration

**Goal:** make notifications a first-class island feature without creating a second notification owner.

Deliver end-to-end:
- explicit notification ownership decision using ii's existing server/state where possible;
- adapter model required by k4 toast/history UI;
- k4 toast island plugin;
- actions/dismissal/history behaviors required by the panel;
- transient timing/hover hold behavior;
- explicit user-opened plugin preempts transient toast;
- no competing `NotificationServer` instance.

**Acceptance:** notification arrival while idle and while another plugin is open matches k4 arbitration; ii does not double-deliver notifications.

## K4-06 — k4 control center/panel

**Goal:** bring k4's own panel into the island without substituting ii sidebars.

Deliver end-to-end:
- panel plugin and its controls tab;
- Wi-Fi, Bluetooth, audio/device, media, notification and shortcut surfaces required by upstream panel;
- narrow adapters to ii services where global ownership already exists;
- k4 background-tap behavior opens the k4 panel;
- existing ii screen-corner sidebars remain independently usable.

**Acceptance:** island background interaction opens the faithful k4 panel; corner-triggered ii sidebars still work.

## K4-07 — Launcher and everyday utility plugins

**Goal:** reach daily-driver parity for the most common k4 tools.

Deliver end-to-end as independently reviewable sub-slices:
- launcher/apps;
- clipboard;
- files;
- windows;
- system monitor;
- session/power;
- shortcut viewer;
- weather/tray where not already completed;
- preserve the existing Super launcher binding and make it reach the selected launcher even when the focused client inhibits shortcuts in fullscreen.

Each sub-slice must use existing ii services through adapters where practical and must not broaden unrelated service APIs without evidence.

## K4-08 — k4 settings inside the island

**Goal:** preserve k4's own settings experience for k4 functionality while keeping the ii Bar Settings variant boundary.

Deliver end-to-end:
- k4 Settings plugin/view;
- port settings only alongside behavior that consumes them;
- plugin enable/disable/error status UI;
- top/bottom and alignment remain backed by `Config.options.bar.k4` rather than a second settings file;
- no setting exists that is disconnected from runtime behavior.

## K4-09 — Capture/record/editor toolchain

**Goal:** port k4-specific capture and editor behavior without destabilizing ii's existing shell.

Deliver as staged sub-slices:
- capture/region/recording workflow;
- temporary island hiding during capture;
- system file-dialog hiding/input suppression;
- preview/actions;
- editor services and UI;
- dependency detection and failure states.

This ticket may be decomposed further after inspecting the pinned upstream implementation and ii's existing region/capture facilities.

## K4-10 — Remaining bundled k4 plugins/features

**Goal:** close functional parity gaps not covered by daily-driver slices.

Inventory against pinned upstream before implementation. Candidate areas include SSH/terminal/agents/ask/theme/monitor arrangement/games/Digivice and other bundled plugins present at the source snapshot.

For each item choose: adapt existing ii service, port k4-local service, or explicitly document an unavailable external dependency. Do not silently omit a bundled feature that is part of the agreed full-port scope.

## K4-11 — Plugin lifecycle/extensibility parity

**Goal:** make k4's plugin architecture robust rather than a static collection of copied views.

Deliver end-to-end:
- safe dynamic plugin creation/loading;
- disabled means uninstantiated where upstream relies on that invariant;
- one broken plugin cannot remove the bar;
- cross-plugin reference distribution;
- dependency gating;
- error reporting/retry/reload semantics required by the UI;
- external/installable plugin compatibility where feasible inside ii-vynx;
- plugin API namespace/path decisions documented and stable.

## K4-12 — Parity, performance, Standards + Spec review

**Goal:** finish by evidence, not by feature count.

Deliver:
- compare implementation against pinned upstream behavior and `SPEC.md`;
- run repository checks available in the environment;
- real-shell manual validation matrix from the spec;
- multi-monitor validation;
- resource/performance inspection for idle and expanded states;
- review duplicate polling/processes introduced by adapters;
- licensing/attribution audit;
- code review on two axes: repository standards and spec fidelity;
- document intentional divergences only after explicit approval.

## Dependency graph

`K4-01 → K4-02 → K4-03 → {K4-04, K4-05} → K4-06 → K4-07 → K4-08`

`K4-03 → K4-09`

`K4-03 → K4-10`

`K4-06/K4-08/K4-10 → K4-11`

All parity-bearing work → `K4-12`.