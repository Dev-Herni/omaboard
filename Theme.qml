pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ---- Contract API ----
    property string name: ""
    property bool dark: true
    property color background: "#111418"
    property color darkBackground: "#0d1013"
    property color darkerBackground: "#0a0c0e"
    property color lighterBackground: "#1c2026"
    property color foreground: "#e6e6e6"
    property color darkForeground: "#8a8f98"
    property color lightForeground: "#c5cad2"
    property color brightForeground: "#ffffff"
    property color accent: "#7aa2f7"
    property color selection: "#2a3038"
    property color muted: "#3d444d"
    property color red: "#f7768e"
    property color yellow: "#e0af68"
    property color orange: "#ff9e64"
    property color green: "#9ece6a"
    property color cyan: "#449dab"
    property color blue: "#7aa2f7"
    property color magenta: "#bb9af7"
    property color brown: "#75493d"

    // Public readonly facade over the private, rebuildable entries.
    readonly property var palette: root._paletteEntries
    property var _paletteEntries: [
        { name: "accent", c: root.accent },
        { name: "red", c: root.red },
        { name: "yellow", c: root.yellow },
        { name: "green", c: root.green },
        { name: "cyan", c: root.cyan },
        { name: "blue", c: root.blue },
        { name: "magenta", c: root.magenta },
        { name: "foreground", c: root.foreground }
    ]

    signal themeChanged()

    // ---- Paths ----
    // omarchy atomically swaps ~/.local/state/omarchy/current/theme (rm + mv),
    // which kills inode watchers on colors.toml. theme.name is rewritten in place
    // (same inode), so it stays watchable and acts as the change kick. We also
    // poll every 1500ms as belt-and-braces.
    function homePath() {
        var h = Quickshell.env("HOME");
        return h ? h : "";
    }
    function colorsFilePath() {
        return homePath() + "/.local/state/omarchy/current/theme/colors.toml";
    }
    function nameFilePath() {
        return homePath() + "/.local/state/omarchy/current/theme.name";
    }

    function snakeToCamel(s) {
        return s.replace(/_([a-zA-Z0-9])/g, function(m, c) {
            return c.toUpperCase();
        });
    }

    readonly property var _knownColors: [
        "background", "darkBackground", "darkerBackground", "lighterBackground",
        "foreground", "darkForeground", "lightForeground", "brightForeground",
        "accent", "selection", "muted",
        "red", "yellow", "orange", "green", "cyan", "blue", "magenta", "brown"
    ]

    function applyName(raw) {
        if (typeof raw !== "string")
            return;
        var n = raw.trim();
        if (n.length === 0)
            return;
        root.name = n;
        emitIfChanged();
    }

    function applyColors(text) {
        if (typeof text !== "string" || text.length === 0)
            return;
        var lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            var trimmed = line.trim();
            if (trimmed.length === 0 || trimmed.charAt(0) === "#" || trimmed.indexOf("[") === 0)
                continue;
            var m = trimmed.match(/^([A-Za-z0-9_]+)\s*=\s*(.*)$/);
            if (!m)
                continue;
            var key = m[1];
            var value = m[2].trim();
            if (value.length >= 2 && ((value.charAt(0) === '"' && value.charAt(value.length - 1) === '"')
                                   || (value.charAt(0) === "'" && value.charAt(value.length - 1) === "'")))
                value = value.slice(1, -1);
            if (key === "mode") {
                root.dark = (value === "dark");
                continue;
            }
            if (!/^#[0-9a-fA-F]{3,8}$/.test(value))
                continue;
            var prop = snakeToCamel(key);
            if (root._knownColors.indexOf(prop) !== -1)
                root[prop] = value;
        }
        emitIfChanged();
    }

    function currentSignature() {
        return root.name + "|" + root.dark
             + "|" + root.background.toString() + "|" + root.darkBackground.toString()
             + "|" + root.darkerBackground.toString() + "|" + root.lighterBackground.toString()
             + "|" + root.foreground.toString() + "|" + root.darkForeground.toString()
             + "|" + root.lightForeground.toString() + "|" + root.brightForeground.toString()
             + "|" + root.accent.toString() + "|" + root.selection.toString()
             + "|" + root.muted.toString()
             + "|" + root.red.toString() + "|" + root.yellow.toString()
             + "|" + root.orange.toString() + "|" + root.green.toString()
             + "|" + root.cyan.toString() + "|" + root.blue.toString()
             + "|" + root.magenta.toString() + "|" + root.brown.toString();
    }

    property string _lastSignature: ""

    // Emit only when the effective palette actually changed, so the 1500ms
    // poll does not spam consumers with no-op re-reads.
    function emitIfChanged() {
        var sig = currentSignature();
        if (sig === root._lastSignature)
            return;
        root._lastSignature = sig;
        rebuildPalette();
        root.themeChanged();
    }

    function rebuildPalette() {
        root._paletteEntries = [
            { name: "accent", c: root.accent },
            { name: "red", c: root.red },
            { name: "yellow", c: root.yellow },
            { name: "green", c: root.green },
            { name: "cyan", c: root.cyan },
            { name: "blue", c: root.blue },
            { name: "magenta", c: root.magenta },
            { name: "foreground", c: root.foreground }
        ];
    }

    // Re-resolve BOTH paths and re-read BOTH files fresh, because the atomic
    // dir swap replaces the colors.toml inode out from under any watcher.
    function refresh() {
        nameView.path = nameFilePath();
        colorsView.path = colorsFilePath();
        nameView.reload();
        colorsView.reload();
    }

    FileView {
        id: nameView

        path: root.nameFilePath()
        watchChanges: true
        printErrors: false

        onLoaded: root.applyName(nameView.text())
        onFileChanged: root.refresh()
    }

    FileView {
        id: colorsView

        path: root.colorsFilePath()
        watchChanges: true
        printErrors: false

        onLoaded: root.applyColors(colorsView.text())
        onFileChanged: root.refresh()
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: root.refresh()
    }
}
