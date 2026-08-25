import QtQuick

// Bottom-left corner bar: Open board + Shortcuts. Pure chrome — signals only.
Rectangle {
    id: root

    signal openRequested()
    signal helpRequested()

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property color pillBg: withAlpha(Theme.darkerBackground, 0.97)

    function withAlpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    implicitWidth: row.implicitWidth + 20
    implicitHeight: row.implicitHeight + 16
    radius: 14
    color: pillBg
    border.color: Theme.muted
    border.width: 1

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 10

        Rectangle {
            id: openBtn

            width: openRow.implicitWidth + 18
            height: 34
            radius: 8
            color: openArea.pressed ? Theme.selection
                 : openArea.containsMouse ? Theme.lighterBackground
                 : root.pillBg
            Behavior on color { ColorAnimation { duration: 120 } }

            Row {
                id: openRow
                anchors.centerIn: parent
                spacing: 7

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "❏"
                    color: Theme.foreground
                    font.family: root.fontFamily
                    font.pixelSize: 15
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Open"
                    color: Theme.foreground
                    font.family: root.fontFamily
                    font.pixelSize: 12
                }
            }

            MouseArea {
                id: openArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openRequested()
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 22
            radius: 1
            color: Theme.muted
            opacity: 0.75
        }

        Rectangle {
            id: helpBtn

            width: 34
            height: 34
            radius: 8
            color: helpArea.pressed ? Theme.selection
                 : helpArea.containsMouse ? Theme.lighterBackground
                 : root.pillBg
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "?"
                color: Theme.foreground
                font.family: root.fontFamily
                font.pixelSize: 15
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
