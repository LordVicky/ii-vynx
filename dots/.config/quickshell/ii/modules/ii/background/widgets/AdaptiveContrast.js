function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, value));
}

function linearSrgb(channel) {
    const value = clamp(channel, 0, 255) / 255;
    return value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4);
}

function relativeLuminance(red, green, blue) {
    return 0.2126 * linearSrgb(red) + 0.7152 * linearSrgb(green) + 0.0722 * linearSrgb(blue);
}

function averageLuminance(data) {
    if (!data || data.length < 4)
        return -1;

    let total = 0;
    let count = 0;
    for (let index = 0; index + 3 < data.length; index += 4) {
        total += relativeLuminance(data[index], data[index + 1], data[index + 2]);
        count += 1;
    }
    return count > 0 ? total / count : -1;
}

function automaticScrimOpacity(luminance) {
    const start = 0.35;
    const end = 0.65;
    const maximum = 0.32;
    const progress = clamp((luminance - start) / (end - start), 0, 1);
    const smooth = progress * progress * (3 - 2 * progress);
    return maximum * smooth;
}

function effectiveLuminance(luminance, scrimOpacity) {
    return clamp(luminance, 0, 1) * (1 - clamp(scrimOpacity, 0, 1));
}

function shouldUseDarkText(luminance, currentlyDark) {
    return currentlyDark ? luminance >= 0.44 : luminance >= 0.48;
}

function coverSourceRect(displayRect, displayWidth, displayHeight, sourceWidth, sourceHeight) {
    if (!displayRect || displayWidth <= 0 || displayHeight <= 0 || sourceWidth <= 0 || sourceHeight <= 0)
        return { x: 0, y: 0, width: 0, height: 0 };

    const left = clamp(displayRect.x, 0, 1) * displayWidth;
    const top = clamp(displayRect.y, 0, 1) * displayHeight;
    const right = clamp(displayRect.x + displayRect.width, 0, 1) * displayWidth;
    const bottom = clamp(displayRect.y + displayRect.height, 0, 1) * displayHeight;
    const scale = Math.max(displayWidth / sourceWidth, displayHeight / sourceHeight);
    const cropX = (sourceWidth * scale - displayWidth) / 2;
    const cropY = (sourceHeight * scale - displayHeight) / 2;

    return {
        x: clamp((left + cropX) / scale, 0, sourceWidth),
        y: clamp((top + cropY) / scale, 0, sourceHeight),
        width: Math.max(0, Math.min((right - left) / scale, sourceWidth)),
        height: Math.max(0, Math.min((bottom - top) / scale, sourceHeight))
    };
}
