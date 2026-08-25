# K4-11 — Built-in plugin lifecycle

Status: design reopened after failed lifecycle tracer

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

That manual QObject-lifetime design is rejected. K4 QML code must not use `Qt.createComponent()`, `.createObject()` or `.destroy()` to own plugin lifetime. A source regression test now guards that boundary.

Runtime code has been restored exactly to the validated K4-10 static-plugin baseline while the replacement lifecycle design is investigated. This rollback is diagnostic: it does not remove the approved K4-11 outcome.

## Replacement architecture requirements

The next tracer must make lifetime declarative and Qt/QML-owned rather than manually destroying QObjects from JavaScript. A `Loader`/slot-style owner is the primary design candidate, but it must be prototyped through a narrow runnable seam before production migration.

The replacement must preserve stable descriptor metadata independently from the live item/plugin instance without feeding dying QObject references through `Repeater`, `GridView`, or another mutable QML model. Disable, retry, application launch, arbitration publication and shell teardown must each have an explicit state transition.

No production plugin is migrated again until the tracer demonstrates all of these without warnings or native crashes:

1. fresh boot with the tracer enabled;
2. fresh boot with the tracer disabled;
3. repeated enable/disable in one Quickshell PID;
4. application open/close before and after recreation;
5. isolated load failure and retry;
6. clean Quickshell shutdown while the plugin is enabled and while disabled.

## Tracer candidate

`displays` remains the preferred tracer because it is a self-contained application plugin and does not own a global service. Existing static plugins remain unchanged until the replacement tracer passes live validation.
