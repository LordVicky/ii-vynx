.pragma library

function speedForMode(mode, downloadSpeed, uploadSpeed) {
    if (mode === "download")
        return downloadSpeed;
    if (mode === "upload")
        return uploadSpeed;
    return downloadSpeed + uploadSpeed;
}

function formatSpeed(bytesPerSecond) {
    const speed = Math.max(0, bytesPerSecond);
    if (speed < 1024)
        return `${Math.round(speed)} B/s`;
    if (speed < 1024 * 1024)
        return `${(speed / 1024).toFixed(1)} KB/s`;
    return `${(speed / (1024 * 1024)).toFixed(1)} MB/s`;
}
