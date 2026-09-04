import QtQuick
import Quickshell.Io

// Modal board-picker: search + keyboard over vaultDir / localDir .md files.
// Emits picked(path) or dismissed().
Rectangle {
    id: root

    visible: false

    signal picked(string path)
    signal dismissed()

    property string vaultDir: ""
    property string localDir: ""
    property var vaultNames: []
    property var localNames: []
    property string filterText: ""
    property int selectedIndex: 0

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int rowCount: pickable.length
    // NUL-delimited so filenames containing newlines survive; %f yields a
    // bare basename, keeping the constructed paths inside this directory.
    readonly property string listScript:
        'find . -maxdepth 1 -type f -name "*.md" -not -name ".*" -printf "%T@\\t%f\\0" | sort -z -nr'

    function withAlpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function matches(name) {
        var q = root.filterText.trim().toLowerCase();
        if (q.length === 0)
            return true;
        return String(name).toLowerCase().indexOf(q) >= 0;
    }

    function pretty(name) {
        var label = String(name || "");
        if (label.length > 3 && label.substring(label.length - 3) === ".md")
            label = label.substring(0, label.length - 3);
        return label.replace(/-\d{8}-\d{6}$/, "");
    }

    readonly property var sections: {
        var arr = [];
        var i;
        var names;
        names = [];
        for (i = 0; i < root.vaultNames.length; i++)
            if (root.matches(root.vaultNames[i]))
                names.push(root.vaultNames[i]);
        if (names.length > 0) {
            arr.push({ isHeader: true, label: "VAULT \u2302", path: "" });
            for (i = 0; i < names.length; i++)
                arr.push({ isHeader: false, label: names[i], path: root.vaultDir + "/" + names[i] });
        }
        names = [];
        for (i = 0; i < root.localNames.length; i++)
            if (root.matches(root.localNames[i]))
                names.push(root.localNames[i]);
        if (names.length > 0) {
            arr.push({ isHeader: true, label: "LOCAL", path: "" });
            for (i = 0; i < names.length; i++)
                arr.push({ isHeader: false, label: names[i], path: root.localDir + "/" + names[i] });
        }
        return arr;
    }

    readonly property var pickable: {
        var arr = [];
        var secs = root.sections;
        for (var i = 0; i < secs.length; i++)
            if (!secs[i].isHeader)
                arr.push(secs[i]);
        return arr;
    }

    function open() {
        root.filterText = "";
        root.selectedIndex = 0;
        visible = true;
        refresh();
        Qt.callLater(function() {
            filterInput.forceActiveFocus();
            filterInput.selectAll();
        });
    }

    function close() {
        visible = false;
        root.filterText = "";
    }

    function refresh() {
        vaultNames = [];
        localNames = [];
        vaultLs.exec(["sh", "-c", listScript, "sh"]);
        localLs.exec(["sh", "-c", listScript, "sh"]);
    }

    function parseNames(text) {
        var out = [];
        var recs = String(text === undefined || text === null ? "" : text).split("\u0000");
        for (var i = 0; i < recs.length; i++) {
            var rec = recs[i];
            if (rec.length === 0)
                continue;
            var tab = rec.indexOf("\t");
            var n = tab >= 0 ? rec.substring(tab + 1) : rec;
            if (n.length > 3 && n.lastIndexOf(".md") === n.length - 3 && n.indexOf("/") < 0)
                out.push(n);
        }
        return out;
    }

    function clampSelection() {
        if (root.rowCount === 0) {
            root.selectedIndex = 0;
            return;
        }
        if (root.selectedIndex < 0)
            root.selectedIndex = 0;
        if (root.selectedIndex >= root.rowCount)
            root.selectedIndex = root.rowCount - 1;
    }

    function moveSelection(delta) {
        if (root.rowCount === 0)
            return;
        root.selectedIndex = Math.max(0, Math.min(root.rowCount - 1, root.selectedIndex + delta));
    }

    function confirmSelection() {
        if (root.rowCount === 0)
            return;
        var item = root.pickable[root.selectedIndex];
        if (item && item.path) {
            root.picked(item.path);
            root.close();
        }
    }

    onFilterTextChanged: {
        root.selectedIndex = 0;
        root.clampSelection();
    }
    onRowCountChanged: root.clampSelection()

    focus: visible
    Keys.forwardTo: [filterInput]
    Keys.onEscapePressed: function(event) {
        event.accepted = true;
        root.dismissed();
    }

    color: Qt.rgba(0, 0, 0, 0.55)

    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed()
    }

    Process {
        id: vaultLs
        workingDirectory: root.vaultDir
        stdout: StdioCollector { id: vaultOut }
        onExited: function(exitCode, exitStatus) {
            root.vaultNames = root.parseNames(vaultOut.text);
        }
    }

    Process {
        id: localLs
        workingDirectory: root.localDir
        stdout: StdioCollector { id: localOut }
        onExited: function(exitCode, exitStatus) {
            root.localNames = root.parseNames(localOut.text);
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 96, 560)
        height: Math.min(parent.height - 96, 560)
        radius: 0
        color: root.withAlpha(Theme.darkerBackground, 0.98)
        border.color: Theme.muted
        border.width: 1
        clip: true

        MouseArea {
            anchors.fill: parent
            onClicked: function(mouse) { mouse.accepted = true; }
        }

        Column {
            id: cardCol
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            Column {
                id: headerCol
                width: parent.width
                spacing: 8

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
                          : (root.vaultNames.length + root.localNames.length === 0
                             ? "no boards found" : "no matches")
                    color: Theme.darkForeground
                    font.family: root.fontFamily
                    font.pixelSize: 11
                }

                Rectangle {
                    width: parent.width
                    height: filterInput.implicitHeight + 14
                    radius: 0
                    color: root.withAlpha(Theme.lighterBackground, 1)
                    border.color: filterInput.activeFocus ? Theme.accent : Theme.muted
                    border.width: 1

                    TextInput {
                        id: filterInput
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.foreground
                        font.family: root.fontFamily
                        font.pixelSize: 13
                        clip: true
                        text: root.filterText
                        onTextChanged: root.filterText = text
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Down) {
                                root.moveSelection(1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                root.moveSelection(-1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.confirmSelection();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                if (filterInput.text.length > 0) {
                                    filterInput.text = "";
                                } else {
                                    root.dismissed();
                                }
                                event.accepted = true;
                            }
                        }
                    }

                    Text {
                        visible: filterInput.text.length === 0
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Filter boards"
                        color: Theme.darkForeground
                        font.family: root.fontFamily
                        font.pixelSize: 13
                    }
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
                    text: (root.vaultNames.length + root.localNames.length) === 0
                          ? "Nothing here yet.\nSave a board with Ctrl+S first."
                          : "No boards match that filter."
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
                            required property int index

                            readonly property int pickIndex: {
                                var n = 0;
                                var secs = root.sections;
                                for (var i = 0; i < index; i++)
                                    if (!secs[i].isHeader)
                                        n++;
                                return entry.modelData.isHeader ? -1 : n;
                            }

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
                                radius: 0
                                color: entry.pickIndex === root.selectedIndex
                                       ? root.withAlpha(Theme.accent, 0.18)
                                       : (rowArea.containsMouse ? Theme.lighterBackground : "transparent")
                                border.color: entry.pickIndex === root.selectedIndex ? Theme.accent : "transparent"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 90 } }

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 28
                                    text: "󰧮  " + root.pretty(entry.modelData.label)
                                    color: Theme.foreground
                                    font.family: root.fontFamily
                                    font.pixelSize: 13
                                    renderType: Text.NativeRendering
                                    elide: Text.ElideMiddle
                                }

                                MouseArea {
                                    id: rowArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: root.selectedIndex = entry.pickIndex
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
