import QtQuick

// Bottom-center toast stack. Pure presentational: show(message, kind) only.
Item {
    id: root

    function withAlpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function kindColor(kind) {
        if (kind === "ok")
            return Theme.green;
        if (kind === "warn")
            return Theme.yellow;
        return Theme.accent; // "info"
    }

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int maxToasts: 3

    function show(message, kind) {
        var k = (typeof kind === "string") ? kind : "info";
        var msg = (typeof message === "string") ? message : String(message);

        // cap the stack: expire the oldest toast
        var kids = stack.data;
        var pills = [];
        for (var i = 0; i < kids.length; i++)
            if (kids[i].objectName === "toastPill")
                pills.push(kids[i]);
        while (pills.length >= maxToasts)
            pills.shift().dismiss();

        pillFactory.createObject(stack, {
            message: msg,
            barColor: kindColor(k),
            durationMs: k === "ok" ? 1600 : 2200
        });
    }

    Column {
        id: stack
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 22
        spacing: 8
    }

    Component {
        id: pillFactory

        ToastPill {}
    }

    component ToastPill: Rectangle {
        id: pill

        objectName: "toastPill"
        property string message: ""
        property color barColor: Theme.accent
        property int durationMs: 2200
        property bool leaving: false

        function dismiss() {
            if (!leaving) {
                leaving = true;
                shown = false;
                destroyTimer.start();
            }
        }

        width: Math.max(150, textLabel.implicitWidth + 40)
        height: 36
        radius: 18
        color: withAlpha(Theme.darkerBackground, 0.97)
        border.color: Theme.muted
        border.width: 1
        z: 100

        opacity: shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
        transform: Translate { y: shown ? 0 : 16; Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } } }

        property bool shown: false

        Component.onCompleted: shown = true

        Timer {
            id: lifeTimer
            interval: pill.durationMs
            running: !pill.leaving
            onTriggered: pill.dismiss()
        }

        Timer {
            id: destroyTimer
            interval: 220
            onTriggered: pill.destroy()
        }

        Rectangle { // left accent bar
            x: 5
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: parent.height - 14
            radius: 2
            color: pill.barColor
        }

        Text {
            id: textLabel
            anchors.left: parent.left
            anchors.leftMargin: 17
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: pill.message
            color: Theme.foreground
            font.family: root.fontFamily
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }
}
