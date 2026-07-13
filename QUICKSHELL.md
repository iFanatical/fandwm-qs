# dwm-qs — status bar (`dwm-qs-shell`)

This fork's built-in status bar and system tray have been removed. The bar is
**`dwm-qs-shell`**, a hand-rolled C++/Qt panel (`shell/`) — no QML, no
QuickShell runtime. It is a 1:1 port of the previous QuickShell config (kept
for reference in `quickshell/`): same Tokyo Night theme, same geometry, same
widgets, same helper scripts, pixel-matched against the QML original.

dwm-qs still reserves a strip of screen (so tiled windows never overlap the
panel) and publishes its state over EWMH root-window properties; the panel
reads that state through the `dwm-qs-state` bridge and renders workspaces, the
focused window title, an SNI system tray, optional status text, and a clock.

The window manager binary is named **`dwm-qs`** so it can coexist with a stock
`dwm` install.

## What changed in dwm

- `drawbar`/`drawbars` are no-ops; the systray subsystem is gone.
- `barwin` is created for bookkeeping but never mapped, so it can't paint over
  or steal clicks from the panel.
- Windows with `_NET_WM_WINDOW_TYPE_DOCK` (the panel) are left **unmanaged** —
  dwm-qs maps them as-is instead of tiling them as a client.
- The reserved strip height is `config.h` → `barheight` (default **28**). Keep
  it equal to `Theme::panelHeight` in `shell/theme.h`.
- dwm-qs publishes `_NET_NUMBER_OF_DESKTOPS`, `_NET_DESKTOP_NAMES`,
  `_NET_CURRENT_DESKTOP`, `_NET_DESKTOP_VIEWPORT` (plus the existing
  `_NET_ACTIVE_WINDOW` / `_NET_CLIENT_LIST`).
- dwm-qs handles incoming `_NET_CURRENT_DESKTOP` client messages, so clicking a
  workspace in the panel switches tags.

## Dependencies

- Qt 6 base (`Qt6Widgets`, `Qt6Gui`, `Qt6DBus`, `Qt6Network`) — panel, popups,
  SNI tray
- `libpulse` — native volume/mic control (works against pipewire-pulse)
- `libX11` — dock window type + popup keyboard grabs (already required by dwm)
- A Nerd Font (`JetBrainsMono Nerd Font Propo`) for icons/glyphs

The state bridge (`dwm-qs-state`) is a small C program built and installed by
`make`; it links only against libX11 and replaces the old shell script, so
`xprop`/`xdotool`/`wmctrl` are not needed.

Widget dependencies (only what you use):
- **Volume/mic** — native via libpulse (pipewire-pulse); no script, no extra tool.
- **VPN** — `wg-quick` (WireGuard) + passwordless `sudo` for it. Tunnel `tun1`
  (override with `$DWM_QS_VPN_TUNNEL`).
- **Network** — `nmcli` (NetworkManager) enables the full Wi-Fi manager; without
  it the widget falls back to `iproute2` status + `net-bridge.sh` re-apply.
- **Bluetooth** — `bluetoothctl` (bluez).

## Install

```sh
make clean && make        # builds ./dwm-qs, ./dwm-qs-state, shell/dwm-qs-shell
sudo make install         # installs dwm-qs, dwm-qs-state, dwm-qs-shell, and
                          # the dwm-qs-* helper scripts (vpn, net, bt, ...)
```

> The bridge and helper scripts **must** be on the `PATH` that `dwm-qs-shell`
> inherits. `make install` puts everything in `/usr/local/bin` for exactly this
> reason. If a helper is missing from PATH the panel silently shows defaults
> (9 tags, stuck on tag 1).

Optionally install `dwm-qs.desktop` to `/usr/share/xsessions/` so a display
manager offers a "dwm-qs" session.

## Launch

`dwm-qs-shell` runs as a normal background app; it spawns `dwm-qs-state watch`
itself. Start it from your session before (or after) dwm-qs — e.g. in
`~/.xinitrc`:

```sh
dwm-qs-shell --no-duplicate &
exec dwm-qs
```

## IPC (launcher / runner / dunst)

The panel exposes the same IPC surface the QuickShell config did — update your
`sxhkdrc` bindings from `quickshell ipc call ...` to:

```sh
dwm-qs-shell ipc call launcher toggle   # centered .desktop app launcher
dwm-qs-shell ipc call runner toggle     # $PATH executable runner
dwm-qs-shell ipc call dunst toggle      # pause/unpause notifications
dwm-qs-shell ipc call dunst refresh
```

(`show`/`hide` are also accepted for `launcher` and `runner`.)

The launcher is a fullscreen, WM-managed window titled `fandwm-launcher`; dwm
recognizes it by title (`launchertitle` in config.def.h) and manages it as a
borderless fullscreen floating overlay. Escape or a click outside the box
dismisses it.

## Tuning

- **Bar height / gap:** if the panel and reserved strip don't match, set
  `barheight` in `config.h` and `panelHeight` in `shell/theme.h` to the same
  value, then `make && sudo make install`.
- **Colors / font:** edit `shell/theme.h` (defaults match the Tokyo Night
  palette in `config.h`, same values as the old `quickshell/core/Theme.qml`).
- **Status text:** the panel shows the root `WM_NAME` (dwmblocks/statuscmd
  style) with color markup stripped. If you don't use an external status
  writer, that area stays empty.

## Verifying without a display

```sh
Xvfb :20 -screen 0 1280x800x24 &
DISPLAY=:20 ./dwm-qs &
DISPLAY=:20 ./shell/dwm-qs-shell &
DISPLAY=:20 xprop -root _NET_NUMBER_OF_DESKTOPS _NET_DESKTOP_NAMES _NET_CURRENT_DESKTOP
DISPLAY=:20 ./dwm-qs-state state
DISPLAY=:20 ./dwm-qs-state switch 0 3   # -> _NET_CURRENT_DESKTOP becomes 3
```

## Panel widgets

The panel's right side hosts (in order) Dunst, Network, memory, VPN, Volume,
battery, Bluetooth, the system tray (primary monitor only — see
`primaryScreens` in `shell/theme.h`), and the clock. Each is a pill
(`shell/widgets.cpp` `BarPill`) that opens a themed popup (`shell/popup.cpp`,
Escape to close).

- **Volume/mic** (`shell/volume.cpp`) — native libpulse against
  pipewire-pulse; no script. Scroll = adjust output, right-click = mute,
  click = popup with output/mic sliders + output-device switch.
- **VPN** (`shell/pills.cpp`) — polls `dwm-qs-vpn`; click toggles the
  WireGuard `tun1` tunnel (green shield = up).
- **Network** (`shell/network.cpp`) — driven by `dwm-qs-net`. On
  NetworkManager: Wi-Fi scan/list/connect (inline password)/disconnect +
  Wi-Fi radio toggle. On the bridge desktop: bridge/VLAN link status with
  per-interface up/down and a "Re-apply" (re-runs `net-bridge.sh`).
- **Bluetooth** (`shell/bluetooth.cpp`) — driven by `dwm-qs-bt`
  (bluetoothctl): power toggle, timed scan, per-device connect/disconnect.
- **Tray** (`shell/tray.cpp`, `shell/traymenu.cpp`) — a hand-rolled
  StatusNotifierItem host/watcher over QDBus, with themed menus built from the
  `com.canonical.dbusmenu` tree (separators, check/radio items, submenus).
  When another watcher already owns the name it mirrors it as a host instead.
- **Launcher** (`shell/launcher.cpp`, `shell/desktopentry.cpp`) — two-column
  grid over XDG .desktop entries (Exec field codes / `Terminal=true` handled)
  or `$PATH` executables; arrow keys / C-n/p/f/b navigate, Enter launches.

Helper scripts live in `scripts/` (`dwm-qs-vpn`, `dwm-qs-net`, `dwm-qs-bt`,
`dwm-qs-mem`, `dwm-qs-battery`, `dwm-qs-dunst`) and install to
`${PREFIX}/bin`.

## Legacy QML

`quickshell/` contains the original QuickShell configuration this panel was
ported from. It is no longer installed or required, but is kept as the
reference for the port; the two render pixel-identically. If you still run it,
its IPC is the old `quickshell ipc call ...` form.
