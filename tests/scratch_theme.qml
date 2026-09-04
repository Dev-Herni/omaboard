import QtQuick
import Quickshell
import ".."

ShellRoot {
    property int fails: 0

    function check(label, actual, expected) {
        var a = actual.toString().toLowerCase();
        var e = expected.toString().toLowerCase();
        var ok = a === e;
        if (!ok)
            fails++;
        console.log((ok ? "PASS" : "FAIL") + ": " + label + " (actual=" + a + " expected=" + e + ")");
    }

    Component.onCompleted: {
        // Phase 1: ANSI-schema theme (dos-moos) must map via fallback.
        var dosMoos = [
            'accent = "#819890"',
            'foreground = "#F8EBE3"',
            'background = "#131516"',
            'selection_foreground = "#131516"',
            'selection_background = "#A5B5AB"',
            'color0 = "#131516"',
            'color1 = "#F0334A"',
            'color2 = "#819890"',
            'color3 = "#F4E276"',
            'color4 = "#A5B5AB"',
            'color5 = "#72856C"',
            'color6 = "#6d877d"',
            'color7 = "#d5dbd7"',
            'color8 = "#3A4849"',
            'color9 = "#F0334A"',
            'color10 = "#819890"',
            'color11 = "#F4E276"',
            'color12 = "#A5B5AB"',
            'color13 = "#72856C"',
            'color14 = "#6d877d"',
            'color15 = "#F8EBE3"'
        ].join("\n");
        Theme.applyColors(dosMoos);

        check("red from color1", Theme.red, "#F0334A");
        check("green from color2", Theme.green, "#819890");
        check("yellow from color3", Theme.yellow, "#F4E276");
        check("blue from color4", Theme.blue, "#A5B5AB");
        check("magenta from color5", Theme.magenta, "#72856C");
        check("cyan from color6", Theme.cyan, "#6d877d");
        check("muted from color8", Theme.muted, "#3A4849");
        check("selection from selection_background", Theme.selection, "#A5B5AB");
        check("brightForeground from color15", Theme.brightForeground, "#F8EBE3");
        check("darkForeground from color8", Theme.darkForeground, "#3A4849");
        check("lightForeground from color7", Theme.lightForeground, "#d5dbd7");
        check("accent direct", Theme.accent, "#819890");
        check("background direct", Theme.background, "#131516");
        check("foreground direct", Theme.foreground, "#F8EBE3");

        // Phase 2: canonical theme must win over ANSI fallback.
        var canonical = [
            'background = "#1e1e2e"',
            'foreground = "#cdd6f4"',
            'accent = "#89b4fa"',
            'selection = "#45475a"',
            'muted = "#585b70"',
            'red = "#f38ba8"',
            'green = "#a6e3a1"',
            'color1 = "#000000"',
            'color2 = "#000000"',
            'color8 = "#000000"'
        ].join("\n");
        Theme.applyColors(canonical);

        check("canonical red wins", Theme.red, "#f38ba8");
        check("canonical green wins", Theme.green, "#a6e3a1");
        check("canonical selection wins", Theme.selection, "#45475a");
        check("canonical muted wins", Theme.muted, "#585b70");
        check("canonical accent wins", Theme.accent, "#89b4fa");

        console.log(fails === 0 ? "ALL THEME TESTS PASSED" : (fails + " THEME TESTS FAILED"));
        Qt.quit();
    }
}
