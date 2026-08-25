import QtQuick
import Quickshell.Io

// Modal board-picker overlay: lists .md boards from vaultDir + localDir,
// each section newest-first (ls -t). Emits picked(path) or dismissed().
Rectangle {
    id: root

    signal picked(string path)
    signal dismissed()

    property string vaultDir: ""
    property string localDir: ""

    property var vaultNames: []
    property var localNames: []

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int rowCount: vaultNames.length + localNames.length

    readonly property var sections: {
        var arr = [];
        var i;
        if (root.vaultNames.length > 0) {
            arr.push({ isHeader: true, label: "VAULT \u2302", path: "" });
            for (i = 0; i < root.vaultNames.length; i++)
                arr.push({ isHeader: false, label: root.vaultNames[i], path: root.vaultDir + "/" + root.vaultNames[i] });
        }
        if (root.localNames.length > 0) {
            arr.push({ isHeader: true, label: "LOCAL", path: "" });
            for (i = 0; i < root.localNames.length; i++)
                arr.push({ isHeader: false, label: root.localNames[i], path: root.localDir + "/" + root.localNames[i] });
        }
        return arr;
    }

    function withAlpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function open() {
        visible = true;
        refresh();
        root.forceActiveFocus();
    }

    function close() {
        visible = false;
    }

    function refresh() {
        vaultNames = [];
        localNames = [];
        vaultLs.exec(["ls", "-t"]);
        localLs.exec(["ls", "-t"]);
    }

    function parseNames(text) {
        var out = [];
        var lines = String(text === undefined || text === null ? "" : text).split("\n");
        for (var i = 0; i < lines.length; i++) {
            var n = lines[i].trim();
            if (n.length > 3 && n.lastIndexOf(".md") === n.length - 3)
                out.push(n);
        }
        return out;
    }

    focus: visible
    Keys.onEscapePressed: function(event) {
        event.accepted = true;
        root.dismissed();
    }
    Keys.onReturnPressed: function(event) {
        event.accepted = true;
    }

    color: Qt.rgba(0, 0, 0, 0.55)

    MouseArea { // click-outside closes
        anchors.fill: parent
        onClicked: root.dismissed()
    }

    Process {
        id: vaultLs

        workingDirectory: root.vaultDir
        stdout: StdioCollector {
            id: vaultOut
        }

        onExited: function(exitCode, exitStatus) {
            root.vaultNames = root.parseNames(vaultOut.text);
        }
    }

    Process {
        id: localLs

        workingDirectory: root.localDir
        stdout: StdioCollector {
            id: localOut
        }

        onExited: function(exitCode, exitStatus) {
            root.localNames = root.parseNames(localOut.text);
        }
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Math.min(parent.width - 96, 560)
        height: Math.min(parent.height - 96, 540)
        radius: 16
        color: root.withAlpha(Theme.darkerBackground, 0.98)
        border.color: Theme.muted
        border.width: 1

        MouseArea { // swallow clicks inside the card
            anchors.fill: parent
            onClicked: function(mouse) {
                mouse.accepted = true;
            }
        }

        Column {
            id: cardCol

            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            Column {
                id: headerCol

                spacing: 4

                Text {
                    text: "Open board"
                    color: Theme.brightForeground
                    font.family: root.fontFamily
                    font.pixelSize: 18
                    font.bold: true
                }

                Text {
                    text: root.rowCount > 0
                          ? root.rowCount + " board" + (root.rowCount === 1 ? "" : "s")
                          : "no boards found"
                    color: Theme.darkForeground
                    font.family: root.fontFamily
                    font.pixelSize: 11
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.muted
                opacity: 0.6
            }

            Item {
                visible: root.rowCount === 0
                width: parent.width
                height: 120

                Text {
                    anchors.centerIn: parent
                    text: "Nothing here yet.\nSave a board with Ctrl+S first."
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.darkForeground
                    font.family: root.fontFamily
                    font.pixelSize: 12
                }
            }

            Flickable {
                id: listFlick

                visible: root.rowCount > 0
                width: parent.width
                height: card.height - headerCol.height - cardCol.spacing * 2 - cardCol.anchors.margins * 2 - 2
                clip: true
                contentWidth: width
                contentHeight: listCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: listCol

                    width: listFlick.width
                    spacing: 2

                    Repeater {
                        model: root.sections

                        delegate: Item {
                            id: entry

                            required property var modelData

                            width: listFlick.width
                            height: modelData.isHeader ? 30 : 34

                            Text {
                                visible: entry.modelData.isHeader
                                anchors.left: parent.left
                                anchors.leftMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                text: entry.modelData.label
                                color: Theme.accent
                                font.family: root.fontFamily
                                font.pixelSize: 10
                                font.letterSpacing: 2
                                font.bold: true
                            }

                            Rectangle {
                                id: rowRect

                                visible: !entry.modelData.isHeader
                                anchors.fill: parent
                                radius: 8
                                color: rowArea.containsMouse ? Theme.lighterBackground : "transparent"

                                Behavior on color { ColorAnimation { duration: 100 } }

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 28
                                    text: "\u25AB " + entry.modelData.label
                                    color: Theme.foreground
                                    font.family: root.fontFamily
                                    font.pixelSize: 13
                                    elide: Text.ElideMiddle
                                }

                                MouseArea {
                                    id: rowArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.picked(entry.modelData.path);
                                        root.close();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
