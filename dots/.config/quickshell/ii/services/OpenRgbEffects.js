function menuItemData(node) {
    if (!node)
        return null;
    if (Array.isArray(node) && node.length >= 3)
        return node;
    if (node.type === "(ia{sv}av)" && Array.isArray(node.data))
        return node.data;
    return null;
}

function itemLabel(data) {
    const value = data?.[1]?.label;
    return value?.data ?? "";
}

function itemChildren(data) {
    return Array.isArray(data?.[2]) ? data[2] : [];
}

function childNamed(data, name) {
    const children = itemChildren(data);
    for (let index = 0; index < children.length; index++) {
        const child = menuItemData(children[index]);
        if (child && itemLabel(child) === name)
            return child;
    }
    return null;
}

function parseMenuRoot(text) {
    let payload;
    try {
        payload = JSON.parse(text);
    } catch (error) {
        return null;
    }

    return menuItemData(payload?.data?.[1]);
}

function parseMenuLayout(text) {
    const root = parseMenuRoot(text);
    const effectsMenu = childNamed(root, "Effects");
    const profilesMenu = childNamed(effectsMenu, "Profiles");
    if (!profilesMenu)
        return [];

    return itemChildren(profilesMenu).map(node => {
        const data = menuItemData(node);
        return data ? { name: itemLabel(data), menuId: data[0] } : null;
    }).filter(effect => effect && effect.name.length > 0 && Number.isInteger(effect.menuId));
}

function parseStopMenuId(text) {
    const effectsMenu = childNamed(parseMenuRoot(text), "Effects");
    const stopItem = childNamed(effectsMenu, "Stop all effects");
    const menuId = stopItem?.[0];
    return Number.isInteger(menuId) ? menuId : -1;
}
