import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Boards.js" as Boards

Panel {
  id: root
  moduleName: "oxhenri.omaboard"

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property bool appRunning: false
  property string vaultDir: ""
  property string localDir: ""
  property var boards: []
  property string filterText: ""
  property int selectedIndex: 0
  property bool cursorActive: false

  readonly property string homeDir: Quickshell.env("HOME") || ""
  readonly property string boardRoot: Quickshell.env("OMABOARD_ROOT") || homeDir + "/Projects/Omarchy/omaboard"
  readonly property string omaboardBin: homeDir + "/.local/bin/omaboard"
  readonly property string configPath: homeDir + "/.config/omaboard/config.json"
  readonly property color fg: bar ? bar.barForeground : Color.foreground
  readonly property color accent: Color.accent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var filtered: Boards.filterBoards(root.boards, root.filterText)
  readonly property var rows: Boards.rowsFor(root.filtered)
  readonly property int actionCount: 1
  readonly property int cursorCount: root.actionCount + root.filtered.length

  function openFromHotkey() {
    root.controller.show()
    Qt.callLater(function () {
      if (root.opened)
        root.setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    root.filterText = ""
    root.cursorActive = false
    if (searchField && searchField.text)
      searchField.text = ""
    setCenterHoverRevealSuppressed(false)
    root.controller.hide()
  }

  function toggle() {
    if (root.opened)
      root.close()
    else
      root.openFromHotkey()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  function clampCursor() {
    if (root.cursorCount <= 0) {
      root.selectedIndex = 0
      return
    }
    if (root.selectedIndex < 0)
      root.selectedIndex = 0
    if (root.selectedIndex >= root.cursorCount)
      root.selectedIndex = root.cursorCount - 1
  }

  function moveCursor(dx, dy) {
    root.cursorActive = true
    if (searchField && searchField.activeFocus)
      searchField.focus = false
    if (dy === 0)
      return
    root.selectedIndex = Math.max(0, Math.min(root.cursorCount - 1, root.selectedIndex + dy))
    scrollCursorIntoView()
  }

  function activateCursor() {
    if (root.selectedIndex <= 0) {
      root.launchNew()
      return
    }
    var board = root.filtered[root.selectedIndex - root.actionCount]
    if (board && board.path)
      root.launchOpen(board.path)
  }

  function runOma(args) {
    var cmd = [root.omaboardBin]
    if (args && args.length)
      cmd = cmd.concat(args)
    Quickshell.execDetached(cmd)
    root.appRunning = true
    root.close()
  }

  function launchNew() {
    root.runOma(["--new"])
  }

  function launchOpen(path) {
    if (!path)
      return
    root.runOma(["--open", path])
  }

  function launchApp() {
    root.runOma([])
  }

  function setCursorOn(index) {
    root.cursorActive = true
    root.selectedIndex = index
  }

  function scrollCursorIntoView() {
    if (!panelFlick)
      return
    Qt.callLater(function () {
      var item = null
      if (root.selectedIndex === 0)
        item = newRow
      else if (boardColumn && root.selectedIndex >= root.actionCount) {
        var kids = boardColumn.children
        var want = root.selectedIndex - root.actionCount
        var seen = 0
        for (var i = 0; i < kids.length; i++) {
          if (kids[i] && kids[i].boardPath) {
            if (seen === want) {
              item = kids[i]
              break
            }
            seen++
          }
        }
      }
      if (!item)
        return
      var margin = Style.space(6)
      var point = item.mapToItem(panelFlick.contentItem, 0, 0)
      var top = point.y
      var bottom = top + item.height
      var viewTop = panelFlick.contentY
      var viewBottom = viewTop + panelFlick.height
      var maxY = Math.max(0, panelFlick.contentHeight - panelFlick.height)
      if (top < viewTop + margin)
        panelFlick.contentY = Math.max(0, top - margin)
      else if (bottom > viewBottom - margin)
        panelFlick.contentY = Math.min(maxY, bottom + margin - panelFlick.height)
    })
  }

  function applyConfig(text) {
    var dirs = Boards.parseConfig(text, root.homeDir)
    root.vaultDir = dirs.vaultDir
    root.localDir = dirs.localDir
    root.refreshBoards()
  }

  function refreshBoards() {
    if (listProc.running)
      listProc.running = false
    listProc.command = [
      "sh", "-c",
      'find "$@" -maxdepth 1 -type f -name "*.md" -printf "%T@\\t%p\\0" 2>/dev/null | sort -z -nr | head -z -n 24',
      "sh",
      root.vaultDir,
      root.localDir
    ]
    listProc.running = true
  }

  function pingApp() {
    if (pingProc.running)
      return
    pingProc.running = true
  }

  onOpenedChanged: if (opened) {
    root.filterText = ""
    root.cursorActive = false
    root.selectedIndex = 0
    if (searchField)
      searchField.text = ""
    if (panelFlick)
      panelFlick.contentY = 0
    root.refreshBoards()
    root.pingApp()
    Qt.callLater(function () {
      if (root.opened && keyCatcher)
        keyCatcher.forceActiveFocus()
    })
  }

  onFilterTextChanged: {
    root.clampCursor()
    if (root.selectedIndex < root.actionCount && root.filtered.length > 0 && root.filterText.length > 0)
      root.selectedIndex = root.actionCount
  }

  FileView {
    id: configView
    path: root.configPath
    printErrors: false
    watchChanges: true
    onLoaded: root.applyConfig(text())
    onLoadFailed: root.applyConfig("")
    onFileChanged: reload()
  }

  Process {
    id: listProc
    stdout: StdioCollector { id: listOut }
    stderr: StdioCollector {}
    onExited: function () {
      root.boards = Boards.dedupeBoards(Boards.parseFindLines(listOut.text, root.vaultDir))
      root.clampCursor()
    }
  }

  Process {
    id: pingProc
    command: ["qs", "ipc", "-p", root.boardRoot, "call", "omaboard", "ping"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function (code) {
      root.appRunning = code === 0
    }
  }

  Timer {
    interval: 2500
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.pingApp()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(body.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: searchField.activeFocus

      onMoveRequested: function (dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }
      onTextKey: function (t) {
        if (t === "n" || t === "N")
          root.launchNew()
        else if (t === "/") {
          searchField.forceActiveFocus()
          searchField.selectAll()
        }
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: false

        Column {
          id: body
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: "OmaBoard"
            meta: root.appRunning ? "Whiteboard open" : "Whiteboard"
            detail: root.appRunning ? "live" : ""
            foreground: root.fg
            fontFamily: root.fontFamily
            iconComponent: Component {
              Item {
                width: Style.space(28)
                height: Style.space(28)
                Canvas {
                  id: heroCanvas
                  width: Math.round(parent.width)
                  height: Math.round(parent.height)
                  antialiasing: false
                  smooth: false
                  renderTarget: Canvas.Image
                  renderStrategy: Canvas.Cooperative
                  onWidthChanged: requestPaint()
                  onHeightChanged: requestPaint()
                  onPaint: Boards.paintIcon(getContext("2d"), width, height, root.fg, root.accent, root.appRunning)
                }
                Connections {
                  target: root
                  function onAppRunningChanged() { heroCanvas.requestPaint() }
                  function onFgChanged() { heroCanvas.requestPaint() }
                }
              }
            }
          }

          PanelSeparator { foreground: root.fg }

          CursorSurface {
            id: newRow
            width: parent.width - Style.space(8)
            height: Style.space(40)
            anchors.horizontalCenter: parent.horizontalCenter
            foreground: root.fg
            accent: root.accent
            hasCursor: root.cursorActive && root.selectedIndex === 0
            radius: Style.cornerRadius

            MouseArea {
              anchors.fill: parent
              z: 2
              hoverEnabled: true
              preventStealing: true
              cursorShape: Qt.PointingHandCursor
              onEntered: root.setCursorOn(0)
              onPressed: root.launchNew()
            }

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: Style.space(12)
              spacing: Style.space(10)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰐕"
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                renderType: Text.NativeRendering
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "New board"
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }
            }
          }

          PanelSeparator { foreground: root.fg }

          Column {
            width: parent.width
            leftPadding: Style.space(16)
            rightPadding: Style.space(16)
            spacing: Style.space(8)

            PanelSectionHeader {
              text: root.filtered.length === 1 ? "1 board" : root.filtered.length + " boards"
              foreground: root.fg
              fontFamily: root.fontFamily
            }

            TextField {
              id: searchField
              width: parent.width - Style.space(32)
              placeholderText: "Search boards"
              foreground: root.fg
              font.family: root.fontFamily
              onTextChanged: root.filterText = text
              Keys.onPressed: function (event) {
                if (event.key === Qt.Key_Escape) {
                  if (searchField.text.length > 0) {
                    searchField.text = ""
                  } else {
                    root.close()
                  }
                  event.accepted = true
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                  searchField.focus = false
                  keyCatcher.forceActiveFocus()
                  if (root.filtered.length > 0)
                    root.setCursorOn(root.actionCount)
                  else
                    root.setCursorOn(0)
                  if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    root.activateCursor()
                  event.accepted = true
                } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                  root.switchPanel(event.key === Qt.Key_Backtab ? -1 : 1)
                  event.accepted = true
                }
              }
            }
          }

          Item {
            visible: root.filtered.length === 0
            width: parent.width
            height: Style.space(72)

            Text {
              anchors.centerIn: parent
              width: parent.width - Style.space(32)
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
              text: root.boards.length === 0
                    ? "Nothing saved yet. Start a board and hit Ctrl+S."
                    : "No boards match that search."
              color: Qt.darker(root.fg, 1.45)
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          Column {
            id: boardColumn
            visible: root.rows.length > 0
            width: parent.width
            spacing: Style.space(2)

            Repeater {
              model: root.rows

              delegate: Item {
                id: rowRoot
                required property var modelData
                required property int index

                readonly property bool isHeader: modelData.kind === "header"
                readonly property string boardPath: isHeader ? "" : (modelData.path || "")
                readonly property int boardCursor: {
                  if (isHeader)
                    return -1
                  var n = 0
                  var list = root.rows
                  for (var i = 0; i < index; i++) {
                    if (list[i] && list[i].kind === "board")
                      n++
                  }
                  return root.actionCount + n
                }

                width: boardColumn.width
                height: isHeader ? Style.space(26) : Style.space(40)

                PanelSectionHeader {
                  visible: rowRoot.isHeader
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(16)
                  anchors.verticalCenter: parent.verticalCenter
                  text: rowRoot.modelData.label
                  foreground: root.fg
                  fontFamily: root.fontFamily
                }

                CursorSurface {
                  visible: !rowRoot.isHeader
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(8)
                  foreground: root.fg
                  accent: root.accent
                  hasCursor: root.cursorActive && root.selectedIndex === rowRoot.boardCursor
                  radius: Style.cornerRadius

                  MouseArea {
                    anchors.fill: parent
                    z: 2
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.setCursorOn(rowRoot.boardCursor)
                    onPressed: root.launchOpen(rowRoot.boardPath)
                  }

                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(12)
                    anchors.rightMargin: Style.space(12)
                    spacing: Style.space(10)

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      width: parent.width - sectionTag.implicitWidth - Style.space(10)
                      text: rowRoot.modelData.label
                      color: root.fg
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      elide: Text.ElideMiddle
                    }

                    Text {
                      id: sectionTag
                      anchors.verticalCenter: parent.verticalCenter
                      text: rowRoot.modelData.section === "vault" ? "vault" : "local"
                      color: Qt.darker(root.fg, 1.55)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
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
}
