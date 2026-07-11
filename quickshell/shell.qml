//@ pragma UseQApplication

import Quickshell
import qs.panel
import qs.state

ShellRoot {
    id: root

    property var primaryScreens: ["eDP-1", "DisplayPort-1"]

    DwmState {
        id: dwmState
    }

    SystemClock {
        id: systemClock
        precision: SystemClock.Seconds
    }

    Variants {
        model: Quickshell.screens

        DwmPanel {
            state: dwmState
            clock: systemClock
            primaryNames: root.primaryScreens
        }
    }
}
