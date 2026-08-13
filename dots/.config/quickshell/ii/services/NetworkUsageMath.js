.pragma library

function calculateSpeeds(totalRx, totalTx, previousStats, seconds, noiseThreshold) {
    const rawDownload = (totalRx - previousStats.rx) / seconds;
    const rawUpload = (totalTx - previousStats.tx) / seconds;
    const download = rawDownload < noiseThreshold ? 0 : Math.max(0, rawDownload);
    const upload = rawUpload < noiseThreshold ? 0 : Math.max(0, rawUpload);

    return {
        download: download,
        upload: upload,
        total: download + upload
    };
}
