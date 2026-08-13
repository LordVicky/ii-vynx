const layoutOrder = ["card", "spindle", "icon"];

function normalizeLayout(value) {
    return layoutOrder.includes(value) ? value : "spindle";
}

function nextLayout(value) {
    const index = layoutOrder.indexOf(normalizeLayout(value));
    return layoutOrder[(index + 1) % layoutOrder.length];
}

function widgetBaseWidth(mode, iconExpanded, spindleWidth) {
    const normalizedMode = normalizeLayout(mode);
    if (normalizedMode === "card")
        return 300;
    if (normalizedMode === "icon" && !iconExpanded)
        return 72;
    return spindleWidth;
}

function widgetBaseHeight(mode) {
    return normalizeLayout(mode) === "card" ? 218 : 72;
}

function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, value));
}

var iconWidthAnimationDuration = 300;

function iconWidthAtTime(fromWidth, toWidth, scale, elapsedMs) {
    const progress = clamp(elapsedMs / iconWidthAnimationDuration, 0, 1);
    return (fromWidth + (toWidth - fromWidth) * progress) * scale;
}

function iconInteractionEnabled(revealProgress) {
    return revealProgress >= 1;
}

function iconRevealProgress(
    currentWidth,
    collapsedWidth,
    expandedWidth,
    trailingFootprint,
    trailingMargin
) {
    const widthRange = expandedWidth - collapsedWidth;
    if (widthRange <= 0)
        return 0;
    const revealStartWidth = collapsedWidth + widthRange * 0.35;
    const fullRevealWidth = collapsedWidth + trailingMargin + trailingFootprint;
    if (currentWidth - revealStartWidth <= 1e-12)
        return 0;
    if (fullRevealWidth - currentWidth <= 1e-12)
        return 1;
    return clamp(
        (currentWidth - revealStartWidth) / (fullRevealWidth - revealStartWidth),
        0,
        1
    );
}

function spindleMinimumWidth(metrics) {
    return metrics.padding * 2
        + metrics.prominentFootprint
        + metrics.applyFootprint
        + metrics.outerSpacing * 2
        + metrics.minimumSelectorWidth;
}

function spindleBaseWidth(labelWidth, metrics) {
    return clamp(
        Math.max(spindleMinimumWidth(metrics), metrics.labelOverhead + labelWidth),
        metrics.minimumWidth,
        metrics.maximumWidth
    );
}

function pixelScaled(value, scale) {
    return Math.max(1, Math.round(value * scale));
}

function centeredContentY(containerHeight, itemHeight, padding) {
    return Math.round((containerHeight - itemHeight) / 2) - padding;
}
