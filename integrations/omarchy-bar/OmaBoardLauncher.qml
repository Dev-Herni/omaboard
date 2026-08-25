import QtQuick
import qs.Commons
import qs.Ui

// Bar widget that launches OmaBoard on click. Same monochrome BarIconButton
// glyph treatment as the other bar widgets.
BarWidget {
  id: root
  moduleName: "oxhenri.omaboard"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // nf-fa-chalkboard — an actual board with writing on it.
    text: "\u{EDE5}"
    tooltipText: "OmaBoard"
    onPressed: function(b) {
      if (b === Qt.LeftButton)
        Util.execDetached("omaboard")
    }
  }
}
