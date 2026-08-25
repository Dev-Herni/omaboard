import QtQuick
import Quickshell

ShellRoot {
    FloatingWindow {
        id: win

        title: "OmaBoard"
        visible: true
        width: 1200
        height: 800
        color: Theme.background

        Rectangle {
            anchors.fill: parent
            color: Theme.background

            Column {
                anchors.centerIn: parent
                spacing: 28

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Theme.name + "  \u00B7  accent " + Theme.accent.toString()
                    color: Theme.foreground
                    font.pixelSize: 22
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12

                    Repeater {
                        model: Theme.palette

                        delegate: Column {
                            id: swatchColumn

                            spacing: 5

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 36
                                height: 36
                                radius: 6
                                color: modelData.c
                                border.color: Theme.muted
                                border.width: 1
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.name
                                color: Theme.darkForeground
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: Theme
        function onThemeChanged() {
            console.log("THEME:", Theme.name, Theme.accent.toString())
        }
    }
}
