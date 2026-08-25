# K4-11 — Built-in plugin lifecycle

Status: loader-owned Displays lifecycle validated; failure/retry slice pending

## Decision

K4-11 implements lifecycle resilience for the K4 plugins shipped inside ii-vynx. It does not implement upstream k4's external-plugin ecosystem.

Approved behavior remains:

- built-in plugins may be loaded independently through a host-owned lifecycle seam;
- a disabled managed plugin is not instantiated;
- enabling recreates the plugin from its built-in QML entry;
- one plugin component/load failure is recorded without preventing the rest of the K4 bar from loading;
- Settings continues to show disabled and failed plugins even when no live plugin instance exists;
- failed built-ins can be retried from the same Settings lifecycle seam;
- cross-plugin references are distributed by the host after lifecycle changes rather than depending on catalog order;
- persisted enablement remains in the existing `Config.options.bar.k4.disabledPlugins` setting.

Explicitly out of scope:

- user/external plugin directories;
- plugin manifests or permission declarations;
- public plugin API compatibility;
- plugin store/registry;
- install/update/remove tooling;
- Python plugin helpers;
- filesystem watchers;
- hot-reload staging directories;
- package management or background updater services.

These exclusions follow the project's no-bloat/no-new-service rule and are intentional product decisions rather than deferred K4-11 work.

## Failed tracer and rollback

The first `displays` tracer used `Qt.createComponent()`, `Component.createObject()` and manual `QObject.destroy()` from a JavaScript lifecycle manager. Disabling the plugin produced transient null references in Settings/controller bindings and then a native Quickshell crash. Stabilizing the Settings/Apps metadata models did not eliminate the crash.

The later crash report reached `libQt6QmlModels`, `QQmlIncubatorPrivate::incubate()` and `QQmlEnginePrivate::incubate()`. The same implementation also called its shutdown path from `Component.onDestruction`, which could manually destroy a dynamically-created plugin while the QML engine itself was tearing down.

That manual QObject-lifetime design is rejected. K4 QML code must not use `Qt.createComponent()`, `.createObject()` or `.destroy()` to own plugin lifetime. A source regression test guards that boundary.

The rollback restored the validated K4-10 runtime. Live validation confirmed the shell and the original static Displays toggle were stable again, isolating the regression to the K4-11 manual QObject lifecycle.

## Loader prototype evidence

A throwaway probe tested one question independently of the registry, Settings, Apps, arbitration and persisted enablement: can Qt-owned `Loader.active` repeatedly create and release a non-visual `K4Plugin` safely on the target Quickshell/Qt runtime?

The live stress run completed 21 create/release cycles in one Quickshell process:

- final probe state: `enabled=false`, `loaded=false`, `generation=21`;
- 21 `Component.onCompleted` observations;
- 21 `Component.onDestruction` observations;
- no `Segmentation fault`, `QEventLoop`, `TypeError`, `QtQmlModels` or `QQmlIncubator` matches.

That is sufficient runnable evidence for Loader-owned implementation lifetime.

## Accepted production lifecycle architecture

The production tracer does **not** recreate the registry object.

A stable `K4ManagedPlugin` proxy permanently occupies the normal built-in registry slot. Settings, Apps, arbitration and the island host always reference that durable proxy. Only the plugin implementation behind it is ephemeral:

`stable K4ManagedPlugin proxy -> Loader.active -> K4DisplaysPlugin implementation`

The proxy carries stable catalog metadata (`name`, `title`, application metadata, enablement and load error) and projects the implementation's runtime properties (`active`, geometry, view and keyboard/hover policy) while it is loaded.

Important invariants:

- `K4PluginController.plugins` is not rebuilt when Displays is enabled/disabled;
- Settings/App delegates never receive a dying plugin QObject;
- persisted-disabled state gates Loader activation directly, so a disabled plugin does not briefly instantiate during startup;
- Loader owns implementation creation and release; no K4 code manually destroys the implementation;
- the existing controller, Apps model, K4 host and Displays implementation remain unchanged for this tracer.

`K4Plugin.instantiated` is `true` for ordinary static plugins. The managed proxy overrides it from `Loader.item`, allowing Settings to show `Loaded`, `Loading`, `Disabled` or `Error` without dereferencing the ephemeral implementation.

## Displays lifecycle validation

The real Displays tracer passed the lifecycle gate:

1. fresh boot enabled — pass;
2. disable — pass, with `k4.displays` returning `Target not found`, proving the implementation and its IPC handler were unloaded;
3. re-enable — pass, IPC and Displays functionality returned;
4. 20-cycle enable/disable stress — pass without the previous native crash;
5. fresh boot persisted disabled — pass;
6. fresh boot re-enabled — pass;
7. clean shutdown enabled and disabled — pass;
8. no new managed-lifecycle crash signatures were reported.

This validates the stable-proxy + Loader-owned implementation seam for K4-11. The failed manager/descriptor-array architecture remains permanently rejected.

## Failure/retry slice

The next slice adds load-failure isolation without changing the accepted ownership model.

Requirements:

- a forced bad source unloads only the implementation; the stable proxy remains in Settings, Apps and arbitration metadata;
- Loader failure sets the proxy `loadError` while the plugin remains logically enabled;
- Settings shows `Error` and clicking the failed row retries the managed implementation rather than toggling enablement;
- restoring the real source leaves the implementation gated off until Retry, so the Settings retry path is actually exercised;
- the fault harness changes only Loader source/gate state and never registry membership or QObject ownership;
- successful retry restores `Loaded`, the `k4.displays` IPC target and normal Displays behavior;
- no `K4PluginManager`, registry rebuild, `createObject()` or `.destroy()` path is reintroduced.

No other built-in migrates until this failure/retry slice is live-validated.
