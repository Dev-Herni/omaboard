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
    // nf-md-vector_square — selection frame with corner handles, whiteboard motif.
    text: "\u{F0466}"
    tooltipText: "OmaBoard"
    onPressed: function(b) {
      if (b === Qt.LeftButton)
        Util.execDetached("omaboard")
    }
  }
}
