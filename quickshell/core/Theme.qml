pragma Singleton

import Quickshell

Singleton {
    // Tokyo Night palette, matching dwm-qs config.h (col_* / colors[]).
    readonly property string bg:            "#1a1b26"
    readonly property string surface:       "#32344a"
    readonly property string surfaceHover:  "#444b6a"
    readonly property string border:        "#444b6a"
    readonly property string text:          "#dddddd"
    readonly property string textMuted:     "#787c99"
    readonly property string accent:        "#0db9d7"  // SchemeSel (cyan)
    readonly property string selected:      "#ad8ee6"  // SchemeTitle (magenta)
    readonly property string urgent:        "#f7768e"
    readonly property string transparent:   "#00000000"
    readonly property string textStrong:    "#c0caf5"
    readonly property string danger:        "#f7768e"  // red
    readonly property string success:       "#9ece6a"  // green
    readonly property string warning:       "#e0af68"  // yellow

    readonly property string black:		"#32344a"
    readonly property string red:		"#f7768e"
    readonly property string green:		"#9ece6a"
    readonly property string yellow:		"#e0af68"
    readonly property string blue:		"#7aa2f7"
    readonly property string magenta:		"#ad8ee6"
    readonly property string cyan:		"#0db9d7"
    readonly property string white:		"#787c99"

    readonly property string brightblack:	"#444b6a"
    readonly property string brightred:		"#ff7a93"
    readonly property string brightgreen:	"#b9f27c"
    readonly property string brightyellow:	"#ff9e64"
    readonly property string brightblue:	"#7da6ff"
    readonly property string brightmagenta:	"#bb9af7"
    readonly property string brightcyan:	"#449dab"
    readonly property string brightwhite:	"#acb0d0"


    // Workspace/tag states: active = cyan, occupied (has windows) = white,
    // empty/inactive = gray.
    readonly property string tagActive:     "#0db9d7"
    readonly property string tagOccupied:   "#dddddd"
    readonly property string tagEmpty:      "#565f89"

    readonly property string fontFamily: "JetBrainsMono Nerd Font Propo"

    // Keep panelHeight == config.h `barheight` so tiled windows leave exactly
    // the panel's height free (dwm-qs reserves that strip but draws nothing).
    readonly property int panelHeight: 28
    readonly property int panelPadding: 8
    readonly property int rowSpacing: 8
    readonly property int compactSpacing: 2
    readonly property int listSpacing: 4
    readonly property int sectionSpacing: 12
    readonly property int popupMargin: 14
    readonly property int popupSpacing: 10
    readonly property int radius: 4
    readonly property int smallRadius: 3
    readonly property int workspaceButtonSize: 22
    readonly property int trayItemSize: 24
    readonly property int trayIconSize: 18
    readonly property int pillHeight: 22
    readonly property int buttonHeight: 28
    readonly property int chipHeight: 24
    readonly property int iconSize: 18
    readonly property int tinyFontSize: 10
    readonly property int smallFontSize: 12
    readonly property int panelFontSize: 13
    readonly property int bodyFontSize: 14
    readonly property int titleFontSize: 16
    readonly property int maxTitleWidth: 420
}
