/* Thin Xlib helpers kept in one TU so Xlib macros don't leak into Qt code. */
#ifndef DWMQS_X11UTIL_H
#define DWMQS_X11UTIL_H

#include <QtGlobal>

namespace X11Util {

/* Mark a (created) native window as a dock: _NET_WM_WINDOW_TYPE_DOCK +
 * _NET_WM_STATE_ABOVE. dwm-qs leaves DOCK windows unmanaged. */
void setDock(quintptr wid);

/* Keyboard grab for popup windows (quickshell PopupWindow grabFocus). */
bool grabKeyboard(quintptr wid);
void ungrabKeyboard();

} /* namespace X11Util */

#endif
