# dwm-qs — QuickShell status bar

This fork's built-in status bar and system tray have been removed. The bar is
now an external [QuickShell](https://quickshell.outfoxxed.me/) panel. dwm-qs
still reserves a strip of screen (so tiled windows never overlap the panel) and
publishes its state over EWMH root-window properties; QuickShell reads that
state through the `dwm-qs-state` bridge and renders workspaces, the focused
window title, an SNI system tray, optional status text, and a clock.

The binary is named **`dwm-qs`** so it can coexist with a stock `dwm` install.

## What changed in dwm

- `drawbar`/`drawbars` are no-ops; the systray subsystem is gone.
- `barwin` is created for bookkeeping but never mapped, so it can't paint over
  or steal clicks from the QuickShell panel.
- Windows with `_NET_WM_WINDOW_TYPE_DOCK` (the QuickShell panel) are left
  **unmanaged** — dwm-qs maps them as-is instead of tiling them as a client.
- The reserved strip height is `config.h` → `barheight` (default **28**). Keep
  it equal to QuickShell's `Theme.panelHeight`.
- dwm-qs now publishes `_NET_NUMBER_OF_DESKTOPS`, `_NET_DESKTOP_NAMES`,
  `_NET_CURRENT_DESKTOP`, `_NET_DESKTOP_VIEWPORT` (plus the existing
  `_NET_ACTIVE_WINDOW` / `_NET_CLIENT_LIST`).
- dwm-qs handles incoming `_NET_CURRENT_DESKTOP` client messages, so clicking a
  workspace in the panel switches tags.

## Dependencies

- `quickshell` — the panel runtime (built with PipeWire + SystemTray support)
- `xprop` (x11-utils) — required by the state bridge
- `xdotool` **or** `wmctrl` — for workspace-click switching
- A Nerd Font (`JetBrainsMono Nerd Font`) for icons/glyphs

Widget dependencies (only what you use):
- **Volume/mic** — native PipeWire via QuickShell; no script, no extra tool.
- **VPN** — `wg-quick` (WireGuard) + passwordless `sudo` for it. Tunnel `tun1`
  (override with `$DWM_QS_VPN_TUNNEL`).
- **Network** — `nmcli` (NetworkManager) enables the full Wi-Fi manager; without
  it the widget falls back to `iproute2` status + `net-bridge.sh` re-apply.
- **Bluetooth** — `bluetoothctl` (bluez).

## Install

```sh
make clean && make        # builds ./dwm-qs
sudo make install         # installs dwm-qs AND all dwm-qs-* helper scripts
                          # (state, vpn, net, bt) to ${PREFIX}/bin (on PATH)

# QuickShell config
cp -r quickshell ~/.config/          # -> ~/.config/quickshell/shell.qml
```

> The bridge **must** be on the `PATH` that QuickShell inherits. `make install`
> puts it in `/usr/local/bin` for exactly this reason. If you instead keep it in
> `~/.local/bin`, that directory is often missing from the PATH of a WM launched
> by a display manager or a minimal `.xinitrc`, and the panel will silently show
> its defaults (9 tags, stuck on tag 1). Verify with:
> `pgrep -a quickshell` then `cat /proc/<pid>/environ | tr '\0' '\n' | grep ^PATH`.

Optionally install `dwm-qs.desktop` to `/usr/share/xsessions/` so a display
manager offers a "dwm-qs" session.

## Launch

QuickShell runs as a normal background app; `DwmState.qml` spawns
`dwm-qs-state watch` itself. Start it from your session before (or after) dwm-qs
— e.g. in `~/.xinitrc`:

```sh
quickshell --no-duplicate &
exec dwm-qs
```

## Tuning

- **Bar height / gap:** if the panel and reserved strip don't match, set
  `barheight` in `config.h` and `Theme.panelHeight` in
  `quickshell/core/Theme.qml` to the same value, then `make && sudo make install`.
- **Colors / font:** edit `quickshell/core/Theme.qml` (defaults match the
  Tokyo Night palette in `config.h`).
- **Status text:** the panel shows the root `WM_NAME` (dwmblocks/statuscmd
  style) with color markup stripped. If you don't use an external status
  writer, that area stays empty.

## Verifying without a display

```sh
Xvfb :20 -screen 0 1280x800x24 &
DISPLAY=:20 ./dwm-qs &
DISPLAY=:20 xprop -root _NET_NUMBER_OF_DESKTOPS _NET_DESKTOP_NAMES _NET_CURRENT_DESKTOP
DISPLAY=:20 PATH="$PWD/scripts:$PATH" dwm-qs-state state
DISPLAY=:20 xdotool set_desktop 3   # -> _NET_CURRENT_DESKTOP becomes 3
```

## Panel widgets

The panel's right side hosts (in order) Network, VPN, Bluetooth, Volume, the
system tray, and the clock. Each is a `BarPill` (`quickshell/core/BarPill.qml`)
that opens a themed `Popup` (`quickshell/core/Popup.qml`, Escape to close).

- **Volume/mic** (`panel/VolumeWidget.qml`, `VolumePopup.qml`) — native
  `Quickshell.Services.Pipewire`; no script. Scroll = adjust output,
  right-click = mute, click = popup with output/mic sliders + output-device
  switch. A `PwObjectTracker` keeps the default sink/source bound.
- **VPN** (`panel/VpnWidget.qml`) — polls `dwm-qs-vpn`; click toggles the
  WireGuard `tun1` tunnel (green shield = up).
- **Network** (`panel/NetworkWidget.qml`, `NetworkPopup.qml`, `state/NetworkState.qml`)
  — driven by `dwm-qs-net`. On NetworkManager: Wi-Fi scan/list/connect (inline
  password)/disconnect + Wi-Fi radio toggle. On the bridge desktop: bridge/VLAN
  link status with per-interface up/down and a "Re-apply" (re-runs `net-bridge.sh`).
- **Bluetooth** (`panel/BluetoothWidget.qml`, `BluetoothPopup.qml`, `state/BluetoothState.qml`)
  — driven by `dwm-qs-bt` (bluetoothctl): power toggle, timed scan, per-device
  connect/disconnect.
- **Tray menus** (`panel/TrayMenu.qml`) — themed menus built from the SNI menu
  model (`QsMenuOpener`), replacing the native Qt menu; supports separators,
  check/radio items, and submenus.

New helper scripts live in `scripts/` (`dwm-qs-vpn`, `dwm-qs-net`, `dwm-qs-bt`)
and install to `${PREFIX}/bin`. Your existing `~/.local/bin` scripts and
`fandwmblocks` config are untouched. Colors/sizing come from
`quickshell/core/Theme.qml`.

> Note: the QML was authored against the QuickShell API but not runtime-tested
> here (no `quickshell`/PipeWire in the build sandbox). The shell scripts and
> the C/EWMH side were tested. If `Quickshell.Services.Pipewire` is unavailable
> in your quickshell build, the volume widget is the only piece that needs it.
