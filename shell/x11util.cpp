#include "x11util.h"

#include <QGuiApplication>

#include <X11/Xatom.h>
#include <X11/Xlib.h>

static Display *xdisplay()
{
    auto *x11 = qGuiApp->nativeInterface<QNativeInterface::QX11Application>();
    return x11 ? x11->display() : nullptr;
}

namespace X11Util {

void setDock(quintptr wid)
{
    Display *dpy = xdisplay();
    if (!dpy || !wid)
        return;
    Atom windowType = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE", False);
    Atom dock = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_DOCK", False);
    XChangeProperty(dpy, (Window)wid, windowType, XA_ATOM, 32, PropModeReplace,
                    (unsigned char *)&dock, 1);
    Atom state = XInternAtom(dpy, "_NET_WM_STATE", False);
    Atom above = XInternAtom(dpy, "_NET_WM_STATE_ABOVE", False);
    XChangeProperty(dpy, (Window)wid, state, XA_ATOM, 32, PropModeReplace,
                    (unsigned char *)&above, 1);
    XFlush(dpy);
}

bool grabKeyboard(quintptr wid)
{
    Display *dpy = xdisplay();
    if (!dpy || !wid)
        return false;
    int r = XGrabKeyboard(dpy, (Window)wid, True, GrabModeAsync, GrabModeAsync,
                          CurrentTime);
    XFlush(dpy);
    return r == GrabSuccess;
}

void ungrabKeyboard()
{
    Display *dpy = xdisplay();
    if (!dpy)
        return;
    XUngrabKeyboard(dpy, CurrentTime);
    XFlush(dpy);
}

quintptr currentInputFocus()
{
    Display *dpy = xdisplay();
    if (!dpy)
        return 0;
    Window prev = None;
    int revert = 0;
    XGetInputFocus(dpy, &prev, &revert);
    return (prev == None || prev == PointerRoot) ? 0 : (quintptr)prev;
}

void restoreInputFocus(quintptr prev)
{
    Display *dpy = xdisplay();
    if (!dpy || !prev)
        return;
    XSetInputFocus(dpy, (Window)prev, RevertToParent, CurrentTime);
    XFlush(dpy);
}

} /* namespace X11Util */
