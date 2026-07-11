pragma Singleton

import QtQuick

// Tracks the currently-open top-level popup so opening a new one closes the
// previous. (X11 PopupWindow has no reliable click-outside dismiss, so this +
// click-to-toggle + Escape are how popups are dismissed.)
QtObject {
    id: mgr
    property var current: null

    function opened(p) {
        if (current && current !== p && current.visible)
            current.visible = false;
        current = p;
    }
    function closed(p) {
        if (current === p)
            current = null;
    }
}
