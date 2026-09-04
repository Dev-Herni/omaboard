import QtQuick

// Bottom-left corner bar: Save, Save to Obsidian, Help + Shortcuts. Pure chrome — signals only.
Rectangle {
    id: root

    property bool dirty: false
    property string boardTitle: ""

    signal helpRequested()
    signal saveRequested()
    signal vaultRequested()

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property color pillBg: withAlpha(Theme.darkerBackground, 0.97)

    function withAlpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    implicitWidth: row.implicitWidth + 20
    implicitHeight: row.implicitHeight + 16
    radius: 0
    color: pillBg
    border.color: Theme.muted
    border.width: 1

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 10

        Rectangle {
            id: saveBtn

            width: 34
            height: 34
            radius: 0
            color: saveArea.pressed ? Theme.selection
                 : saveArea.containsMouse ? Theme.lighterBackground
                 : root.pillBg
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "󰠘"
                color: Theme.foreground
                font.family: root.fontFamily
                font.pixelSize: 15
                renderType: Text.NativeRendering
            }

            Rectangle { // unsaved-changes pulse ring
                id: pulseRing
                visible: root.dirty
                anchors.fill: parent
                radius: 0
                color: "transparent"
                border.color: Theme.accent
                border.width: 1
                opacity: 0

                SequentialAnimation {
                    running: pulseRing.visible
                    loops: Animation.Infinite
                    alwaysRunToEnd: true
                    NumberAnimation { target: pulseRing; property: "opacity"; from: 0.85; to: 0.15; duration: 700; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: pulseRing; property: "opacity"; from: 0.15; to: 0.85; duration: 700; easing.type: Easing.InOutQuad }
                }
            }

            MouseArea {
                id: saveArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.saveRequested()
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 22
            radius: 0
            color: Theme.muted
            opacity: 0.75
        }

        Rectangle {
            id: vaultBtn

            width: 34
            height: 34
            radius: 0
            color: vaultArea.pressed ? Theme.selection
                 : vaultArea.containsMouse ? Theme.lighterBackground
                 : root.pillBg
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: ""
                color: Theme.foreground
                font.family: root.fontFamily
                font.pixelSize: 15
                renderType: Text.NativeRendering
            }

            MouseArea {
                id: vaultArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.vaultRequested()
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 22
            radius: 0
            color: Theme.muted
            opacity: 0.75
        }

        Rectangle {
            id: helpBtn

            width: 34
            height: 34
            radius: 0
            color: helpArea.pressed ? Theme.selection
                 : helpArea.containsMouse ? Theme.lighterBackground
                 : root.pillBg
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "󰘥"
                color: Theme.foreground
                font.family: root.fontFamily
                font.pixelSize: 15
                renderType: Text.NativeRendering
            }

            MouseArea {
                id: helpArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.helpRequested()
            }
        }
    }
}
