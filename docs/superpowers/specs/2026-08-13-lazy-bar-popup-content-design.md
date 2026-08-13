# Lazy Bar Popup Content Optimization Design

## Objective

Reduce idle Quickshell RAM and startup work by preventing heavy closed popup content from being instantiated until the popup is opened. Apply this only to the audited Illogical Impulse weather, vertical clock, and system-tray overflow popups.

The measured delegate-attribution ranges are approximately 6.3–11.0 MiB PSS for weather, 5.6–7.3 MiB PSS for clock, and 8.5–9.5 MiB PSS plus 4.4–7.4 MiB VRAM for the complete system-tray delegate. These are attribution bounds, not guaranteed lazy-content savings because visible controls and tray icons remain loaded.

## Stability constraints

- Work only on local branch `dev` in `/home/lordvicky/.git/ii-vynx`; do not push.
- Keep design, shared popup capability, individual consumers, and measurement records independently revertible.
- Preserve default `StyledPopup` behavior for every caller that does not opt in.
- Preserve visible weather, clock, and tray controls.
- Preserve popup geometry, animation, sticky hover, pointer travel, focus grabs, tray item menus, pinning, drag/drop, and click behavior.
- Do not modify persistent user configuration during automated validation.
- Do not combine hidden-entry or malformed `system_monitor_bar` cleanup with this work.

## Approaches considered

### 1. Change all `StyledPopup` content globally

Make the existing `contentItem` property lazy for every popup. This could broaden savings, but it changes lifecycle semantics for network, battery, resource, indicator, and extension popups that were not audited.

### 2. Add opt-in lazy content to `StyledPopup` — selected

Keep the existing eager `contentItem` API unchanged and add a separate component-valued `lazyContent` API. Only audited callers opt in. This centralizes window/content ownership without changing unrelated popup behavior.

### 3. Wrap each caller in its own loader

Place a loader around each `StyledPopup`. This duplicates hover/sticky lifecycle logic and risks breaking the references `StyledPopup` uses to position and animate content.

Approach 2 has the narrowest regression surface and a single reusable boundary.

## Shared popup capability

`StyledPopup.qml` gains an optional `Component lazyContent`. Its existing default `Item contentItem` remains supported and retains current behavior.

When `lazyContent` is null, `StyledPopup` behaves exactly as it does today.

When `lazyContent` is provided:

1. The popup's existing `active` state remains the lifecycle trigger.
2. A content loader creates the component when the popup becomes active.
3. The popup window receives the loaded item through the same content-placement and animation path used by eager content.
4. Closing destroys the loaded item after the existing hover grace has completed and the popup becomes inactive.
5. Reopening creates fresh content and re-establishes its bindings.

The loaded content item must be accessible through one internal effective-content property so sizing, hero-item discovery, reparenting, and animations do not branch between eager and lazy modes.

## Weather popup

`WeatherBar.qml` continues displaying the compact current-weather icon and temperature from `Weather.data`.

`WeatherPopup.qml` moves its heavy `ColumnLayout`, forecast arrays, computed hourly model, `Process`, and forecast request lifecycle into a dedicated content component instantiated through `lazyContent`.

Forecast fetching occurs when lazy content is created, not when the shell starts. City changes while the popup is closed do not create content or run a forecast request; the next opening reads the current city and fetches current data. Manual right-click refresh of the compact `Weather` service remains unchanged.

Closing the popup terminates ownership of its fetch process with the content item. A late result must not update a destroyed content object.

## Clock popup

The compact vertical clock, its `LocalSend` highlighting, drag/drop target, and click/hover target remain loaded.

`ClockWidgetPopup.qml` moves its calendar/todo/timer/LocalSend popup layout and derived popup-only properties into lazy content. Sticky-hover behavior remains owned by `StyledPopup`; content survives while the pointer crosses from the bar target into the popup and is destroyed only after the popup becomes inactive.

## System-tray overflow

Pinned tray icons, the overflow button, system tray models, item activation, and per-item right-click menus remain unchanged.

Only the overflow `GridLayout` and its unpinned-item delegates become `lazyContent` of the existing `StyledPopup`. Opening the overflow creates those delegates; closing it destroys them. The focus-grab window reference must tolerate the content being absent and continue closing cleanly.

Because the complete tray delegate attribution includes visible icons and service bindings, only part of its measured 8.5–9.5 MiB PSS is expected to be recoverable from overflow-content laziness.

## Failure-safe behavior

- Never allow both eager and lazy content simultaneously; eager content wins only when no lazy component is supplied.
- Treat a missing or failed lazy component as zero-sized content while retaining a closable popup window.
- Clear internal item references when the loader unloads so sizing bindings never reference destroyed objects.
- Preserve the existing 100 ms sticky-hover grace timer.
- Do not start weather fetches while the popup is inactive.
- Do not destroy tray item menus opened from pinned icons; they use the existing independent per-item loader.
- Ensure focus-grab window lists tolerate null overflow content/window references.

## Test seams

Automated seams:

- `StyledPopup` default eager API remains present.
- `lazyContent` stays unloaded while inactive, loads while active, and releases when inactive.
- Effective content is used by popup sizing, hero discovery, and reparenting.
- Weather forecast startup exists only inside lazy content.
- Clock heavy content is supplied through `lazyContent` while compact-clock interactions stay outside it.
- Tray overflow content is lazy while pinned tray and item-menu loaders remain unchanged.

Runtime seams:

- Weather popup opens, renders all cards, fetches once per content lifetime, closes, and reopens.
- Clock popup opens, pointer crosses into sticky popup without premature destruction, closes, and reopens.
- Clock drag/drop and LocalSend highlighting still work with popup closed.
- Tray pinned icons activate; right-click menus open and close; overflow opens, supports item menus, and closes through focus loss.
- No new QML type, reference, binding-loop, or destroyed-object warnings.

## Resource verification

Use fresh equal-age A/B processes from exact commits. Alternate at least three baseline and three candidate runs with all target popups closed. Record PSS, RSS, VRAM, CPU, warning output, and weather child processes/network fetch evidence.

Then open and close each popup separately and verify its allocation appears only while open and falls after closing. Compare against run-to-run variance; do not add overlapping per-popup deltas as if independent.

Accept only if all runtime seams pass and the closed-popup candidate produces a repeatable improvement. The conservative target is 8–15 MiB lower idle PSS; missing that target triggers review rather than automatic retention.

## Commit boundaries

1. Design and implementation-plan documentation.
2. Shared opt-in `StyledPopup.lazyContent` capability with tests, unused by production callers.
3. Weather popup adoption with focused runtime checks.
4. Clock popup adoption with focused runtime checks.
5. System-tray overflow adoption with focused runtime checks.
6. A/B measurement record and accept/reject decision.

Each consumer can be reverted without reverting the shared capability or other consumers.
