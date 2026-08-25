// Standalone paint-path harness: `timeout 9 qs -p tests/scratch_ui.qml`
import QtQuick
import Quickshell
import ".."

ShellRoot {
    FloatingWindow {
        id: win

        title: "OmaBoard UI scratch"
        visible: true
        implicitWidth: 1100
        implicitHeight: 720
        color: Theme.background

        Rectangle {
            anchors.fill: parent
            color: Theme.background

            Toolbar {
                id: toolbar
                z: 40
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 16
                activeTool: "rectangle"
                strokeColor: Theme.foreground
                fillColor: "transparent"
                canUndo: true
                canRedo: false
                dirty: true // exercise save pulse path
                showGrid: true
                boardTitle: "scratch-board"

                onToolPicked: function(tool) {
                    console.log("SCRATCH toolPicked:", tool);
                    toolbar.activeTool = tool;
                }
                onAction: function(name) {
                    console.log("SCRATCH action:", name);
                    if (name === "save")
                        toast.show("saved to scratch", "ok");
                    else if (name === "vault")
                        toast.show("vault save is not wired in scratch", "warn");
                    else
                        toast.show("action " + name, "info");
                }
                onStrokePicked: function(c) {
                    console.log("SCRATCH strokePicked:", c.toString());
                    toolbar.strokeColor = c;
                }
                onFillPicked: function(c) {
                    console.log("SCRATCH fillPicked:", c.toString());
                    toolbar.fillColor = c;
                }
            }

            Toast {
                id: toast
                z: 50
                anchors.fill: parent
            }

            HelpOverlay {
                id: help
                z: 60
                anchors.fill: parent
                visible: false

                onDismissed: function() {
                    console.log("SCRATCH help dismissed");
                    help.visible = false;
                }
            }
        }

        Component.onCompleted: {
            console.log("SCRATCH started");
            toast.show("hello", "ok");
        }

        Timer { // second toast, exercises stacking + warn styling
            interval: 3000
            running: true
            repeat: false
            onTriggered: {
                toast.show("draft autosaved 30s ago", "info");
                toast.show("vault unreachable", "warn");
            }
        }

        Timer {
            interval: 5000
            running: true
            repeat: false
            onTriggered: {
                console.log("SCRATCH help shown");
                help.visible = true;
            }
        }

        Timer {
            interval: 7000
            running: true
            repeat: false
            onTriggered: {
                console.log("SCRATCH help hidden");
                help.visible = false;
            }
        }
    }
}
