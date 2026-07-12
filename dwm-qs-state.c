/* dwm-qs-state — bridge dwm-qs's EWMH root-window state to the QuickShell
 * panel. Native C replacement for the original shell script: one persistent
 * X connection instead of forking xprop/sed/awk per event, and window titles
 * pass through as raw UTF-8 with no escaping layer to fight.
 *
 * dwm-qs publishes _NET_CURRENT_DESKTOP / _NET_NUMBER_OF_DESKTOPS /
 * _NET_DESKTOP_NAMES / _NET_ACTIVE_WINDOW / _DWM_* on the root window, and
 * the classic status text via the root WM_NAME. This tool reads those and
 * emits `key=value` blocks (blank-line separated) that DwmState.qml parses.
 *
 *   dwm-qs-state state              print one state block and exit
 *   dwm-qs-state watch              stream a block on every relevant change
 *   dwm-qs-state switch <mon> <tag> switch <mon> to <tag> (both 0-based)
 */
#include <locale.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>

#define LENGTH(X) (sizeof(X) / sizeof(X[0]))

enum {
	NetCurrentDesktop, NetNumberOfDesktops, NetDesktopNames,
	NetActiveWindow, NetClientList, NetWMName,
	DwmOccupiedTags, DwmLayout, DwmMonitors, DwmViewRequest,
	Utf8String, AtomLast
};

static const char *atomnames[AtomLast] = {
	[NetCurrentDesktop]   = "_NET_CURRENT_DESKTOP",
	[NetNumberOfDesktops] = "_NET_NUMBER_OF_DESKTOPS",
	[NetDesktopNames]     = "_NET_DESKTOP_NAMES",
	[NetActiveWindow]     = "_NET_ACTIVE_WINDOW",
	[NetClientList]       = "_NET_CLIENT_LIST",
	[NetWMName]           = "_NET_WM_NAME",
	[DwmOccupiedTags]     = "_DWM_OCCUPIED_TAGS",
	[DwmLayout]           = "_DWM_LAYOUT",
	[DwmMonitors]         = "_DWM_MONITORS",
	[DwmViewRequest]      = "_DWM_VIEW_REQUEST",
	[Utf8String]          = "UTF8_STRING",
};

static Display *dpy;
static Window root;
static Atom atoms[AtomLast];

/* The state block is assembled here (not printed directly) so watch mode can
 * skip re-emitting when a property burst leaves the block unchanged. */
static char statebuf[8192];
static size_t stateoff;

static void
emit(const char *fmt, ...)
{
	va_list ap;
	int n;

	if (stateoff >= sizeof statebuf - 1)
		return;
	va_start(ap, fmt);
	n = vsnprintf(statebuf + stateoff, sizeof statebuf - stateoff, fmt, ap);
	va_end(ap);
	if (n > 0)
		stateoff += (size_t)n < sizeof statebuf - stateoff
			? (size_t)n : sizeof statebuf - stateoff - 1;
}

/* The active window can vanish between reading _NET_ACTIVE_WINDOW and
 * querying its title; every request here is a read, so ignoring errors is
 * always safe and keeps the panel's state feed alive. */
static int
xerror(Display *d, XErrorEvent *ee)
{
	(void)d; (void)ee;
	return 0;
}

static long
getcardinal(Window w, Atom prop, long fallback)
{
	Atom type;
	int fmt;
	unsigned long n, after;
	unsigned char *data = NULL;
	long v = fallback;

	if (XGetWindowProperty(dpy, w, prop, 0L, 1L, False, AnyPropertyType,
			&type, &fmt, &n, &after, &data) == Success && data) {
		if (n > 0 && fmt == 32)
			v = *(long *)data;
		XFree(data);
	}
	return v;
}

/* dwm's gettextprop, plus a direct-copy path for UTF8_STRING so titles
 * survive even under a non-UTF-8 locale. */
static int
gettextprop(Window w, Atom atom, char *text, unsigned int size)
{
	char **list = NULL;
	int n;
	XTextProperty name;

	if (!text || size == 0)
		return 0;
	text[0] = '\0';
	if (!XGetTextProperty(dpy, w, &name, atom) || !name.nitems)
		return 0;
	if (name.encoding == XA_STRING || name.encoding == atoms[Utf8String]) {
		strncpy(text, (char *)name.value, size - 1);
	} else if (XmbTextPropertyToTextList(dpy, &name, &list, &n) >= Success
			&& n > 0 && *list) {
		strncpy(text, *list, size - 1);
		XFreeStringList(list);
	}
	text[size - 1] = '\0';
	XFree(name.value);
	return 1;
}

/* Flatten CR/LF/TAB to spaces, collapse runs, trim — same normalisation the
 * shell bridge's clean_line applied, so record framing can't be corrupted. */
static void
clean(char *s)
{
	char *r, *w;
	int sp = 1; /* trims leading space */

	for (r = w = s; *r; r++) {
		char c = (*r == '\n' || *r == '\r' || *r == '\t') ? ' ' : *r;
		if (c == ' ') {
			if (!sp)
				*w++ = ' ';
			sp = 1;
		} else {
			*w++ = c;
			sp = 0;
		}
	}
	while (w > s && w[-1] == ' ')
		w--;
	*w = '\0';
}

/* _NET_DESKTOP_NAMES is a NUL-separated UTF8_STRING list; join with '|'.
 * Falls back to "1|2|...|count" when unset, like the shell bridge. */
static void
desktopnames(char *out, size_t size, long count)
{
	Atom type;
	int fmt;
	unsigned long n, after, i;
	unsigned char *data = NULL;
	size_t off = 0;
	long k;

	out[0] = '\0';
	if (XGetWindowProperty(dpy, root, atoms[NetDesktopNames], 0L, 4096L,
			False, AnyPropertyType, &type, &fmt, &n, &after, &data) == Success
			&& data && fmt == 8 && n > 0) {
		for (i = 0; i < n && off + 1 < size; i++) {
			if (data[i] == '\0') {
				if (i + 1 < n && off + 1 < size)
					out[off++] = '|';
			} else {
				out[off++] = (char)data[i];
			}
		}
		out[off] = '\0';
		/* a trailing NUL in the property leaves a dangling '|' */
		if (off > 0 && out[off - 1] == '|')
			out[off - 1] = '\0';
	}
	if (data)
		XFree(data);
	if (out[0])
		return;
	for (k = 1; k <= count && off + 4 < size; k++)
		off += snprintf(out + off, size - off, "%s%ld", k > 1 ? "|" : "", k);
}

/* _DWM_MONITORS is one newline-terminated record per monitor; re-emit each
 * as a "monitor\t..." line. dwm already flattens embedded whitespace. */
static void
printmonitors(void)
{
	Atom type;
	int fmt;
	unsigned long n, after, i, start;
	unsigned char *data = NULL;

	if (XGetWindowProperty(dpy, root, atoms[DwmMonitors], 0L, 4096L,
			False, XA_STRING, &type, &fmt, &n, &after, &data) != Success
			|| !data)
		return;
	if (fmt == 8) {
		for (start = 0, i = 0; i <= n; i++) {
			if (i == n || data[i] == '\n') {
				if (i > start)
					emit("monitor\t%.*s\n", (int)(i - start), data + start);
				start = i + 1;
			}
		}
	}
	XFree(data);
}

/* Assemble the full state block into statebuf. */
static void
buildstate(void)
{
	char layout[64], names[1024], title[512], status[1024], awin[32];
	long current, count, occupied;
	Window active;

	stateoff = 0;
	statebuf[0] = '\0';
	current = getcardinal(root, atoms[NetCurrentDesktop], 0);
	count = getcardinal(root, atoms[NetNumberOfDesktops], 9);
	occupied = getcardinal(root, atoms[DwmOccupiedTags], 0);
	gettextprop(root, atoms[DwmLayout], layout, sizeof layout);
	desktopnames(names, sizeof names, count);
	gettextprop(root, XA_WM_NAME, status, sizeof status);
	clean(status);

	active = (Window)getcardinal(root, atoms[NetActiveWindow], 0);
	title[0] = '\0';
	awin[0] = '\0';
	if (active) {
		snprintf(awin, sizeof awin, "%lu", (unsigned long)active);
		if (!gettextprop(active, atoms[NetWMName], title, sizeof title))
			gettextprop(active, XA_WM_NAME, title, sizeof title);
		clean(title);
	}
	if (!title[0])
		strcpy(title, "Desktop");

	emit("current=%ld\n", current);
	emit("count=%ld\n", count);
	emit("occupied=%ld\n", occupied);
	emit("layout=%s\n", layout);
	emit("names=%s\n", names);
	emit("active_window=%s\n", awin);
	emit("title=%s\n", title);
	emit("status=%s\n", status);
	printmonitors();
}

static int
relevant(XEvent *ev)
{
	Atom a;

	if (ev->type != PropertyNotify || ev->xproperty.window != root)
		return 0;
	a = ev->xproperty.atom;
	return a == atoms[NetCurrentDesktop] || a == atoms[NetNumberOfDesktops]
		|| a == atoms[NetDesktopNames] || a == atoms[DwmOccupiedTags]
		|| a == atoms[DwmLayout] || a == atoms[DwmMonitors]
		|| a == atoms[NetActiveWindow] || a == atoms[NetClientList]
		|| a == XA_WM_NAME;
}

static void
watch(void)
{
	static char last[sizeof statebuf];
	XEvent ev;
	int dirty;

	XSelectInput(dpy, root, PropertyChangeMask);
	buildstate();
	fputs(statebuf, stdout);
	printf("\n");
	fflush(stdout);
	memcpy(last, statebuf, sizeof last);
	for (;;) {
		XNextEvent(dpy, &ev);
		dirty = relevant(&ev);
		/* coalesce bursts (tag switch fires several properties at once)
		 * into a single re-emit */
		while (XPending(dpy)) {
			XNextEvent(dpy, &ev);
			dirty |= relevant(&ev);
		}
		if (!dirty)
			continue;
		buildstate();
		/* a burst can span several wakeups; only emit real changes */
		if (strcmp(last, statebuf) == 0)
			continue;
		memcpy(last, statebuf, sizeof last);
		fputs(statebuf, stdout);
		printf("\n");
		fflush(stdout);
	}
}

static int
numeric(const char *s)
{
	if (!s || !*s)
		return 0;
	for (; *s; s++)
		if (*s < '0' || *s > '9')
			return 0;
	return 1;
}

/* dwm-qs watches this root property and views <tag> on <monitor>. */
static int
switchworkspace(const char *mon, const char *tag)
{
	char buf[64];

	if (!numeric(mon) || !numeric(tag)) {
		fprintf(stderr, "usage: dwm-qs-state switch <monitor> <tag>\n");
		return 2;
	}
	snprintf(buf, sizeof buf, "%s %s", mon, tag);
	XChangeProperty(dpy, root, atoms[DwmViewRequest], XA_STRING, 8,
		PropModeReplace, (unsigned char *)buf, strlen(buf));
	XSync(dpy, False);
	return 0;
}

int
main(int argc, char *argv[])
{
	const char *cmd = argc > 1 ? argv[1] : "state";
	int ret = 0;

	if (strcmp(cmd, "state") && strcmp(cmd, "watch") && strcmp(cmd, "switch")) {
		fprintf(stderr, "usage: %s [state|watch|switch <monitor> <tag>]\n",
			argv[0]);
		return 2;
	}
	setlocale(LC_CTYPE, "");
	if (!(dpy = XOpenDisplay(NULL))) {
		fprintf(stderr, "dwm-qs-state: cannot open display\n");
		return 1;
	}
	XSetErrorHandler(xerror);
	root = DefaultRootWindow(dpy);
	XInternAtoms(dpy, (char **)atomnames, AtomLast, False, atoms);

	if (!strcmp(cmd, "watch"))
		watch(); /* no return */
	else if (!strcmp(cmd, "switch"))
		ret = switchworkspace(argc > 2 ? argv[2] : NULL,
			argc > 3 ? argv[3] : NULL);
	else {
		buildstate();
		fputs(statebuf, stdout);
	}

	XCloseDisplay(dpy);
	return ret;
}
