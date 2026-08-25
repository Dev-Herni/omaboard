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
    // nf-md-draw (pen nib drawing a squiggle) — scratch-pad motif.
    text: "\u{F0F49}"
    tooltipText: "OmaBoard"
    onPressed: function(b) {
      if (b === Qt.LeftButton)
        Util.execDetached("omaboard")
    }
  }
}
