//@ pragma UseQApplication

import Quickshell
import qs.core
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

    // Single centered launcher on the primary monitor; triggered via
    //   quickshell ipc call launcher toggle
    AppLauncher {
        screen: {
            var s = Quickshell.screens;
            for (var i = 0; i < s.length; i++)
                if (root.primaryScreens.indexOf(s[i].name) >= 0)
                    return s[i];
            return s.length > 0 ? s[0] : null;
        }
    }
}
