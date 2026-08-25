# K4-11 — Built-in plugin lifecycle

Status: accepted architecture; Displays and Keys validated; low-coupling batch committed; temporarily paused for selected K4 v1 sync

## Decision

K4-11 implements lifecycle resilience for K4 plugins shipped inside ii-vynx. It does not implement upstream K4's external-plugin ecosystem.

Approved behavior:

- built-in plugins may be independently loaded/unloaded through a host-owned lifecycle seam;
- a disabled managed plugin is not instantiated;
- enabling recreates the built-in implementation;
- one component/load failure is recorded without preventing the rest of the bar from loading;
- Settings and Apps keep stable metadata/status even when no implementation exists;
- failed built-ins expose Retry independently from enable/disable;
- persisted enablement remains in `Config.options.bar.k4.disabledPlugins`;
- lifecycle changes must not rebuild the plugin registry or hand delegates dying QObject references.

Explicitly out of scope:

- external/user plugin directories;
- plugin manifests and permission declarations;
- public plugin API compatibility as an installable ecosystem;
- plugin store/registry;
- install/update/remove/publishing tooling;
- Python plugin helpers;
- filesystem watchers;
- hot-reload staging directories;
- package management/background updater services.

These are explicit product decisions and remain rejected after reviewing K4 v1.0.

## Rejected manual QObject lifecycle

The first Displays tracer used `Qt.createComponent()`, `Component.createObject()` and manual `QObject.destroy()` from a JavaScript lifecycle manager. Disabling the plugin caused transient null references in Settings/controller bindings and then a native Quickshell crash reaching QtQmlModels/QQmlIncubator code.

Additional attempts to stabilize metadata models did not eliminate the crash. Calling shutdown/destruction paths while the QML engine itself was tearing down further increased lifetime risk.

That architecture is permanently rejected. K4 plugin lifetime code must not use:

- `Qt.createComponent()`;
- `.createObject()`;
- manual `.destroy()`.

Source regression coverage guards this boundary.

Upstream K4 v1.0 still uses manual dynamic creation/destruction in its PluginManager. U12 approval is therefore **ideas only**: borrow failure-isolation/status semantics if useful, never its QObject ownership mechanism.

## Loader prototype evidence

A throwaway probe isolated one question from the registry, Settings, Apps, arbitration and persistence: can Qt-owned `Loader.active` safely create/release a non-visual K4Plugin repeatedly on the target Qt/Quickshell runtime?

Live result:

- final `enabled=false`, `loaded=false`, `generation=21`;
- 21 `Component.onCompleted` observations;
- 21 `Component.onDestruction` observations;
- no `Segmentation fault`, `QEventLoop`, `TypeError`, `QtQmlModels` or `QQmlIncubator` signatures.

That established declarative Loader ownership as the production direction.

## Accepted production architecture

A stable `K4ManagedPlugin` proxy permanently occupies its built-in registry slot:

```text
stable K4ManagedPlugin proxy
        -> Loader.active
        -> plugin implementation
```

The proxy carries durable catalog metadata and user-visible lifecycle state, while projecting runtime properties from `Loader.item` only when the implementation exists.

Invariants:

- `K4PluginController.plugins` is not rebuilt on enable/disable/failure;
- Settings/App delegates always reference the stable proxy;
- persisted-disabled state gates Loader activation directly, preventing startup flash-instantiation;
- Loader owns implementation creation/release;
- the implementation's own IPC handlers/services disappear when unloaded;
- `K4Plugin.instantiated`/proxy state lets Settings display Loaded, Loading, Disabled or Error without dereferencing a destroyed implementation.

## Displays validation

The real Displays tracer passed:

1. enabled boot;
2. disable with `k4.displays` returning `Target not found`, proving the implementation/IPC owner was absent;
3. re-enable with IPC and normal functionality restored;
4. 20-cycle enable/disable stress without the previous crash;
5. persisted-disabled fresh boot;
6. re-enabled fresh boot;
7. clean shutdown enabled and disabled;
8. no managed-lifecycle crash signatures.

## Failure isolation and Retry validation

The stable proxy was then tested against a deliberately missing QML source.

Validated behavior:

- forced load failure leaves the proxy present and logically enabled;
- Settings shows Error plus an explicit Retry control and independent enable switch;
- implementation IPC target disappears while failed;
- Retry while the forced fault remains active fails safely and returns to Error;
- disabling while failed produces Disabled without removing the row;
- re-enabling while faulted returns to Error;
- restoring the correct source does not silently recreate the implementation;
- explicit Retry after restore returns to Loaded and restores the implementation IPC target;
- the only expected runtime warnings are the deliberately missing `__K4MissingManagedPlugin.qml` file during fault injection.

No registry mutation or manual QObject lifetime was reintroduced.

## Keys generalization validation

Keys/Shortcuts was migrated as the second real managed built-in using the same stable-proxy/Loader seam.

Live validation passed normal load, disable/unload, re-enable, stress and forced-failure/recovery. The only reported warnings were the expected missing-file warnings from deliberate fault injection.

This demonstrates the architecture is not Displays-specific.

## Low-coupling utility batch

The next batch changes only the registry entries for:

- System;
- Windows;
- Session.

Commit anchor: `f1cf5eb714a73cd230faa25d7ac25e7040d9c750` (`feat(k4): manage low-coupling utilities through loader proxies`).

These plugins were selected because they are ordinary application utilities that delegate real desktop ownership to existing ii-vynx services and do not participate as ambient Clock/Player/Toast owners.

**Current state:** the batch is committed but was interrupted by the K4 v1.0 upstream review before real-shell validation. Do not mark this batch complete until its normal disable/re-enable and failure/recovery matrix is run.

## Pause for selected K4 v1 sync

K4-11 migration is temporarily paused while approved K4 v1.0 changes modify:

- host reservation/Hidden behavior;
- per-monitor fullscreen resolution;
- Player ambient activation;
- Idle/Clock geometry;
- active-screen API documentation/tests.

This avoids simultaneously changing plugin lifetime and the core host/ambient-plugin behaviors that lifecycle tests depend on.

The selected sync is specified in `docs/k4-bar-port/K4-V1-SYNC-DESIGN.md` and ticketed as K4-V1-01 through K4-V1-05.

## Resume order

After K4-V1-05 closes:

1. live-validate the already committed System/Windows/Session batch;
2. migrate remaining low-coupling ordinary applications in small risk-ordered slices;
3. keep ambient/cross-plugin owners such as Volume, Clock, Player and Toast static until ordinary lifecycle coverage is broad enough;
4. migrate higher-coupling owners only when their stable-proxy forwarding/reference requirements are explicit and source-covered;
5. finish with Standards + Spec review before K4-12.

## Completion criteria

K4-11 is complete when all selected built-ins that benefit from unloadable lifecycle use the stable-proxy/Loader seam, protected/core exceptions are explicitly documented, failure/retry remains stable, no manual QObject lifetime returns, and the external plugin ecosystem remains absent unless a future product decision changes scope.
