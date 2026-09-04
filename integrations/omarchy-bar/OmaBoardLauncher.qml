import QtQuick
import qs.Commons
import qs.Ui
import "Boards.js" as Boards

// Bar widget for OmaBoard. Left-click opens recents, middle-click new board,
// right-click launches the app.
BarWidget {
  id: root
  moduleName: "oxhenri.omaboard"

  function injectPanel() {
    var target = panelLoader.item
    if (!target)
      return
    if ("bar" in target)
      target.bar = root.bar
    if ("settings" in target)
      target.settings = root.settings
    if ("anchorItem" in target)
      target.anchorItem = button
    if ("hostWidget" in target)
      target.hostWidget = root
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle)
      panelLoader.item.toggle()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool appRunning: panelLoader.item ? panelLoader.item.appRunning === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey)
      panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close)
      panelLoader.item.close()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item && panelLoader.item.closeForPopoutSwitch)
      panelLoader.item.closeForPopoutSwitch()
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: "OmaBoard"
    iconComponent: Component {
      Item {
        Canvas {
          id: iconCanvas
          width: Math.round(parent.width)
          height: Math.round(parent.height)
          antialiasing: false
          smooth: false
          renderTarget: Canvas.Image
          renderStrategy: Canvas.Cooperative
          onWidthChanged: requestPaint()
          onHeightChanged: requestPaint()
          onPaint: Boards.paintIcon(getContext("2d"), width, height, button.foreground, button.foreground, false)
        }
        Connections {
          target: root
          function onAppRunningChanged() { iconCanvas.requestPaint() }
        }
        Connections {
          target: button
          function onForegroundChanged() { iconCanvas.requestPaint() }
        }
      }
    }

    onPressed: function (b) {
      if (b === Qt.RightButton) {
        if (panelLoader.item && panelLoader.item.launchApp)
          panelLoader.item.launchApp()
        return
      }
      if (b === Qt.MiddleButton) {
        if (panelLoader.item && panelLoader.item.launchNew)
          panelLoader.item.launchNew()
        return
      }
      root.togglePanel()
    }
  }
}
