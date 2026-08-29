import QtQuick
import qs.Commons
import qs.Ui

// Bar icon with a pulldown — the Tiny Ipsum shape, one surface reached from
// the bar rather than a widget and a full-screen overlay.
//
// Scaffolding: the panel is empty on purpose. The generator, the variant
// picker and the count selector land in #5 and fill the column below; what is
// here is the frame they hang in.
Panel {
  id: root
  moduleName: "cschaba.omaipsum"
  ipcTarget: "cschaba.omaipsum.widget"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // The bar sizes a slot from its widget's implicit size — a root that does
  // not publish one gets a 0x0 slot and renders nothing at all, silently: no
  // icon, no gap, no error in the log. These two lines are the widget.
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // A Nerd Font glyph in `text`, the way every first-party bar widget draws
    // its icon; nf-md-file_document, the same one Omarchy uses for a document.
    text: "󰈙"
    tooltipText: "Lorem ipsum"
    onPressed: root.toggle()
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.spacing.lg

        Text {
          width: parent.width
          text: "Nothing to generate yet"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
