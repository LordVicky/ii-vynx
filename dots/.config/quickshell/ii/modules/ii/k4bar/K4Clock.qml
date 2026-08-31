pragma Singleton

import QtQuick
import Quickshell
import qs.services

// k4 clock contract backed by ii-vynx's existing DateTime/Translation services.
Singleton {
    readonly property date date: DateTime.clock.date
    readonly property var locale: Qt.locale(Translation.languageCode)
}
