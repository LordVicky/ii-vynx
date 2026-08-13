const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const sourcePath = path.join(__dirname, "../dots/.config/quickshell/ii/services/OpenRgbEffects.js");
const source = fs.readFileSync(sourcePath, "utf8");
const effects = {};
vm.createContext(effects);
vm.runInContext(source, effects, { filename: sourcePath });

function native(value) {
    return JSON.parse(JSON.stringify(value));
}

function item(id, label, children = []) {
    return {
        type: "(ia{sv}av)",
        data: [id, { label: { type: "s", data: label } }, children]
    };
}

function menuPayload(effectItems) {
    return JSON.stringify({
        type: "u(ia{sv}av)",
        data: [52, [0, {}, [
            item(2, "Profiles", [item(14, "Standard")]),
            item(33, "Effects", [
                item(34, "Start all effects"),
                item(35, "Stop all effects"),
                item(36, "Profiles", effectItems)
            ])
        ]]]
    });
}

test("extracts only effect profiles from the nested Effects menu", () => {
    const result = effects.parseMenuLayout(menuPayload([
        item(37, "AudioParty"),
        item(43, "Sakura")
    ]));

    assert.deepEqual(native(result), [
        { name: "AudioParty", menuId: 37 },
        { name: "Sakura", menuId: 43 }
    ]);
});

test("returns no effects for malformed JSON", () => {
    assert.deepEqual(native(effects.parseMenuLayout("not json")), []);
});

test("returns no effects when the plugin submenu is absent", () => {
    const payload = JSON.stringify({
        type: "u(ia{sv}av)",
        data: [1, [0, {}, [item(2, "Profiles", [item(14, "Standard")])]]]
    });

    assert.deepEqual(native(effects.parseMenuLayout(payload)), []);
});

test("a fresh payload replaces removed effects and discovers new effects", () => {
    const first = effects.parseMenuLayout(menuPayload([item(37, "AudioParty"), item(43, "Sakura")]));
    const refreshed = effects.parseMenuLayout(menuPayload([item(43, "Sakura"), item(51, "NewEffect")]));

    assert.deepEqual(native(first.map(value => value.name)), ["AudioParty", "Sakura"]);
    assert.deepEqual(native(refreshed.map(value => value.name)), ["Sakura", "NewEffect"]);
});

test("discovers the current Stop all effects menu action", () => {
    assert.equal(effects.parseStopMenuId(menuPayload([item(37, "AudioParty")])), 35);
    assert.equal(effects.parseStopMenuId("not json"), -1);
});
