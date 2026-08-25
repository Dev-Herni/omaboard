import QtQuick
import QtQuick.Controls

// Floating toolbar pill. Pure chrome: emits signals only, never mutates state.
Item {
    id: root

    // ---- Contract API (docs/CONTRACTS.md) ----
    property string activeTool: "select"
    property color strokeColor: Theme.foreground
    property color fillColor: "transparent"
    property bool canUndo: false
    property bool canRedo: false
    property bool dirty: false
    property bool showGrid: false
    property string boardTitle: ""

    signal toolPicked(string tool)
    signal strokePicked(color c)
    signal fillPicked(color c)
    signal action(string name)

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property color pillBg: withAlpha(Theme.darkerBackground, 0.97)

    function withAlpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    implicitWidth: pill.width
    implicitHeight: pill.height

    Rectangle {
        id: pill

        width: bar.implicitWidth + 24
        height: bar.implicitHeight + 20
        radius: 14
        color: root.pillBg
        border.color: Theme.muted
        border.width: 1

        Row {
            id: bar
            anchors.centerIn: parent
            spacing: 10

            Row {
                spacing: 4

                IconButton {
                    glyph: "✚"
                    tip: "New · Ctrl+N"
                    actionName: "new"
                }
                IconButton {
                    glyph: "❏"
                    tip: "Open · Ctrl+O"
                    actionName: "open"
                }
            }

            Divider {}

            Row {
                spacing: 4

                IconButton {
                    glyph: "↺"
                    tip: "Undo · Ctrl+Z"
                    actionName: "undo"
                    dimmed: !root.canUndo
                }
                IconButton {
                    glyph: "↻"
                    tip: "Redo · Ctrl+Y"
                    actionName: "redo"
                    dimmed: !root.canRedo
                }
            }

            Divider {}

            Row {
                spacing: 2

                Repeater {
                    model: [
                        { tool: "select",    glyph: "⬚", tip: "Select · 1" },
                        { tool: "rectangle", glyph: "▭", tip: "Rectangle · 2" },
                        { tool: "ellipse",   glyph: "◯", tip: "Ellipse · 3" },
                        { tool: "diamond",   glyph: "◇", tip: "Diamond · 4" },
                        { tool: "arrow",     glyph: "➚", tip: "Arrow · 5" },
                        { tool: "line",      glyph: "╱", tip: "Line · 6" },
                        { tool: "draw",      glyph: "✎", tip: "Draw · 7" },
                        { tool: "text",      glyph: "𝐀", tip: "Text · 8" },
                        { tool: "eraser",    glyph: "⌫", tip: "Eraser · 9" }
                    ]

                    delegate: IconButton {
                        required property var modelData

                        glyph: modelData.glyph
                        tip: modelData.tip
                        toolName: modelData.tool
                        isActive: root.activeTool === modelData.tool
                    }
                }
            }

            Divider {}

            Row {
                spacing: 6

                SwatchButton {
                    id: strokeSwatch
                    label: "S"
                    tip: "Stroke color"
                    chipColor: root.strokeColor
                    onOpened: palettePop.openFor("stroke")
                }
                SwatchButton {
                    id: fillSwatch
                    label: "F"
                    tip: "Fill color"
                    chipColor: root.fillColor
                    transparentAware: true
                    onOpened: palettePop.openFor("fill")
                }
            }

            Divider {}

            Row {
                spacing: 4

                IconButton {
                    glyph: "▦"
                    tip: "Grid · G"
                    actionName: "grid"
                    showCheckDot: root.showGrid
                }
                IconButton {
                    glyph: "⊞"
                    tip: "Fit · ="
                    actionName: "fit"
                }
                IconButton {
                    glyph: "?"
                    tip: "Shortcuts · ?"
                    actionName: "help"
                }
            }

            Divider {}

            Row {
                spacing: 4

                IconButton {
                    id: saveBtn
                    glyph: "⤓"
                    tip: root.dirty ? "Save · Ctrl+S · unsaved changes"
                                    : "Save · Ctrl+S"
                    actionName: "save"
                    pulse: root.dirty
                }
                IconButton {
                    glyph: "⌂"
                    tip: root.boardTitle.length > 0
                         ? "Vault-save · Ctrl+Shift+S — " + root.boardTitle
                         : "Vault-save · Ctrl+Shift+S"
                    actionName: "vault"
                    outlined: true
                }
            }
        }

        // Shared hover tooltip, rendered below the hovered button.
        Rectangle {
            id: tipRect
            visible: opacity > 0.01
            opacity: 0
            Behavior on opacity { NumberAnimation { duration: 100 } }
            x: Math.max(4, Math.min(tipX - width / 2, root.width - width - 4))
            y: root.height + 7
            width: tipText.implicitWidth + 18
            height: tipText.implicitHeight + 9
            radius: 6
            color: root.withAlpha(Theme.darkerBackground, 0.98)
            border.color: Theme.muted
            border.width: 1
            z: 999

            property real tipX: 0

            Text {
                id: tipText
                anchors.centerIn: parent
                text: ""
                color: Theme.darkForeground
                font.family: root.fontFamily
                font.pixelSize: 11
            }
        }

        PalettePopup {
            id: palettePop
        }
    }

    function showTip(item) {
        var p = item.mapToItem(root, 0, 0);
        tipRect.tipX = p.x + item.width / 2;
        tipText.text = item.tip;
        tipRect.opacity = 1;
    }

    function hideTip() {
        tipRect.opacity = 0;
    }

    component Divider: Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: 22
        radius: 1
        color: Theme.muted
        opacity: 0.75
    }

    component IconButton: Rectangle {
        id: ib

        property string glyph: ""
        property string tip: ""
        property string toolName: ""   // set => emits toolPicked
        property string actionName: "" // set => emits action(name)
        property bool isActive: false
        property bool dimmed: false
        property bool outlined: false  // accent border (vault)
        property bool pulse: false     // dirty-save pulse ring
        property bool showCheckDot: false

        width: 34
        height: 34
        radius: 8
        color: ib.isActive ? Theme.accent
             : area.pressed ? Theme.selection
             : area.containsMouse ? Theme.lighterBackground
             : root.pillBg
        Behavior on color { ColorAnimation { duration: 120 } }

        border.width: ib.outlined ? 1 : 0
        border.color: Theme.accent
        Behavior on border.color { ColorAnimation { duration: 120 } }

        opacity: ib.dimmed ? 0.35 : 1
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: ib.glyph
            color: ib.isActive ? Theme.background : Theme.foreground
            font.family: root.fontFamily
            font.pixelSize: 16
        }

        Rectangle { // grid checked-state underline dot
            visible: ib.showCheckDot && !ib.isActive
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
            width: 4
            height: 4
            radius: 2
            color: Theme.accent
        }

        Rectangle { // dirty-save pulse ring
            id: ring
            visible: ib.pulse
            anchors.fill: parent
            radius: 8
            color: "transparent"
            border.color: Theme.accent
            border.width: 1
            opacity: 0

            SequentialAnimation {
                running: ib.pulse
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { target: ring; property: "opacity"; from: 0.85; to: 0.15; duration: 700; easing.type: Easing.InOutQuad }
                NumberAnimation { target: ring; property: "opacity"; from: 0.15; to: 0.85; duration: 700; easing.type: Easing.InOutQuad }
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onContainsMouseChanged: {
                if (containsMouse)
                    root.showTip(ib);
                else
                    root.hideTip();
            }
            onClicked: {
                if (ib.dimmed)
                    return;
                root.hideTip();
                if (ib.toolName !== "")
                    root.toolPicked(ib.toolName);
                else if (ib.actionName !== "")
                    root.action(ib.actionName);
            }
        }
    }

    component SwatchButton: Item {
        id: sw

        property string label: ""
        property string tip: ""
        property color chipColor: "transparent"
        property bool transparentAware: false
        readonly property bool isTransparent: chipColor.a === 0

        signal opened()

        width: 26
        height: 38

        MouseArea {
            id: hoverZone
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: {
                if (containsMouse)
                    root.showTip(sw);
                else
                    root.hideTip();
            }
            onClicked: {
                root.hideTip();
                sw.opened();
            }
        }

        Rectangle {
            id: chip
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: 22
            height: 22
            radius: 7
            color: sw.isTransparent ? Theme.lighterBackground : sw.chipColor
            border.color: hoverZone.containsMouse || hoverZone.pressed
                          ? Theme.accent : Theme.muted
            border.width: 1
            clip: true

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Rectangle { // slash marker for transparent fill
                visible: sw.transparentAware && sw.isTransparent
                anchors.centerIn: parent
                width: 34
                height: 2
                radius: 1
                rotation: -45
                color: Theme.darkForeground
                opacity: 0.9
            }
        }

        Text {
            anchors.top: chip.bottom
            anchors.topMargin: 1
            anchors.horizontalCenter: chip.horizontalCenter
            text: sw.label
            color: Theme.darkForeground
            font.family: root.fontFamily
            font.pixelSize: 10
        }
    }

    component PalettePopup: Popup {
        id: pop

        property string mode: "stroke" // "stroke" | "fill"

        function openFor(m) {
            mode = m;
            open();
        }

        parent: root
        y: root.height + 8
        x: Math.max(4, Math.min((root.width - width) / 2, root.width - width - 4))
        padding: 12
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: 12
            color: root.withAlpha(Theme.darkerBackground, 0.97)
            border.color: Theme.muted
            border.width: 1
        }

        contentItem: Column {
            spacing: 8

            Text {
                anchors.left: parent.left
                text: pop.mode === "fill" ? "FILL" : "STROKE"
                color: Theme.darkForeground
                font.family: root.fontFamily
                font.pixelSize: 10
                font.letterSpacing: 2
            }

            Grid {
                columns: 4
                horizontalItemAlignment: Grid.AlignHCenter
                columnSpacing: 12
                rowSpacing: 10

                Repeater {
                    model: pop.mode === "fill"
                           ? [{ name: "transparent", c: "transparent" }].concat(Theme.palette)
                           : Theme.palette

                    delegate: Column {
                        id: choiceColumn
                        required property var modelData

                        spacing: 3

                        Rectangle {
                            id: choiceChip
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 28
                            height: 28
                            radius: 7
                            color: choiceColumn.modelData.name === "transparent"
                                   ? Theme.lighterBackground
                                   : choiceColumn.modelData.c
                            border.color: chipArea.containsMouse
                                          ? Theme.accent : Theme.muted
                            border.width: 1
                            clip: true

                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            Rectangle { // slash for transparent entry
                                visible: choiceColumn.modelData.name === "transparent"
                                anchors.centerIn: parent
                                width: 40
                                height: 2
                                radius: 1
                                rotation: -45
                                color: Theme.darkForeground
                                opacity: 0.9
                            }

                            MouseArea {
                                id: chipArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    var c = choiceColumn.modelData.c;
                                    if (pop.mode === "fill") {
                                        root.fillPicked(c);
                                    } else {
                                        root.strokePicked(c);
                                    }
                                    pop.close();
                                }
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: choiceColumn.modelData.name
                            color: Theme.darkForeground
                            font.family: root.fontFamily
                            font.pixelSize: 9
                        }
                    }
                }
            }
        }

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 110; easing.type: Easing.OutQuad }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 90; easing.type: Easing.OutQuad }
        }
    }
}
