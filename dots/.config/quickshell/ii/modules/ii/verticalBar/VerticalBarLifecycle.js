function activationWidth(configuredWidth) {
    return Math.max(2, Number(configuredWidth) || 0);
}

function shouldKeepTrigger(autoHideEnabled, barOpen, screenLocked) {
    return autoHideEnabled && barOpen && !screenLocked;
}

function shouldLoadFullBar(autoHideEnabled, revealRequested, barOpen, screenLocked) {
    return barOpen && !screenLocked && (!autoHideEnabled || revealRequested);
}
