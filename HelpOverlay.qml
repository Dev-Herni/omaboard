import QtQuick

// Fullscreen dim + centered shortcuts card. Closes on click / Esc via dismissed().
Rectangle {
    id: root

    signal dismissed()

    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    // All shortcuts from docs/CONTRACTS.md (shell section)
    readonly property var leftColumn: [
        { key: "1",           desc: "Select tool" },
        { key: "2",           desc: "Rectangle tool" },
        { key: "3",           desc: "Ellipse tool" },
        { key: "4",           desc: "Diamond tool" },
        { key: "5",           desc: "Arrow tool" },
        { key: "6",           desc: "Line tool" },
        { key: "7",           desc: "Draw tool" },
        { key: "8",           desc: "Text tool" },
        { key: "9",           desc: "Eraser tool" },
        { key: "S",           desc: "Sticky note tool" },
        { key: "Ctrl+N",      desc: "New board" },
        { key: "Ctrl+O",      desc: "Open picker" },
        { key: "Ctrl+S",      desc: "Save in place" }
    ]
    readonly property var rightColumn: [
        { key: "Ctrl+Shift+S", desc: "Vault save" },
        { key: "Ctrl+E",       desc: "Export PNG" },
        { key: "Ctrl+Shift+E", desc: "Export SVG" },
        { key: "Ctrl+V",       desc: "Paste image" },
        { key: "Ctrl+Z",       desc: "Undo" },
        { key: "Ctrl+Y",       desc: "Redo (or Ctrl+Shift+Z)" },
        { key: "Del",          desc: "Delete selection" },
        { key: "Ctrl+D",       desc: "Duplicate" },
        { key: "Ctrl+]",       desc: "Z-order forward" },
        { key: "Ctrl+[",       desc: "Z-order back" },
        { key: "+ / -",        desc: "Zoom in / out" },
        { key: "=",            desc: "Fit to content" },
        { key: "G",            desc: "Toggle grid" },
        { key: "?",            desc: "Toggle help" },
        { key: "Esc",          desc: "Deselect / reset tool" }
    ]

    color: Qt.rgba(0, 0, 0, 0.55)

    function withAlpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    focus: visible
    Keys.onEscapePressed: root.dismissed()

    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed()
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.max(headerRow.implicitWidth, columns.implicitWidth) + 64
        height: cardCol.implicitHeight + 48
        radius: 0
        color: root.withAlpha(Theme.darkerBackground, 0.97)
        border.color: Theme.muted
        border.width: 1

        Column {
            id: cardCol
            anchors.centerIn: parent
            spacing: 20

            Row {
                id: headerRow
                x: (parent.width - width) / 2
                spacing: 12

                Text {
                    id: titleText
                    text: "OmaBoard — Shortcuts"
                    color: Theme.brightForeground
                    font.family: root.fontFamily
                    font.pixelSize: 18
                    font.bold: true
                }

                Text {
                    anchors.baseline: titleText.baseline
                    text: "󰘥"
                    color: Theme.foreground
                    font.family: root.fontFamily
                    font.pixelSize: 18
                    renderType: Text.NativeRendering
                }
            }

            Text {
                x: (parent.width - width) / 2
                text: "click anywhere or press Esc to close"
                color: Theme.darkForeground
                font.family: root.fontFamily
                font.pixelSize: 11
            }

            Row {
                id: columns
                spacing: 56

                Column {
                    spacing: 9

                    Repeater {
                        model: root.leftColumn

                        delegate: ShortcutRow {}
                    }
                }

                Column {
                    spacing: 9

                    Repeater {
                        model: root.rightColumn

                        delegate: ShortcutRow {}
                    }
                }
            }
        }
    }

    component ShortcutRow: Item {
        id: row

        required property var modelData

        width: Math.max(keyChip.width + 10 + descText.implicitWidth, 220)
        height: 24

        Rectangle {
            id: keyChip
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(keyText.implicitWidth + 16, 72)
            height: 20
            radius: 0
            color: root.withAlpha(Theme.lighterBackground, 1)
            border.color: Theme.muted
            border.width: 1

            Text {
                id: keyText
                anchors.centerIn: parent
                text: row.modelData.key
                color: Theme.foreground
                font.family: root.fontFamily
                font.pixelSize: 11
            }
        }

        Text {
            id: descText
            anchors.left: keyChip.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.desc
            color: Theme.lightForeground
            font.family: root.fontFamily
            font.pixelSize: 12
        }
    }
}
