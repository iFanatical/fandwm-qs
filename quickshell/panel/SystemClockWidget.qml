import Quickshell

SystemClock {
    id: clock
    precision: SystemClock.Seconds
}

Text {
    text: Qt.formatDateTime(clock.date, "hh:mm:ss")
}
