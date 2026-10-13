import QtQuick
import Quickshell
import Quickshell.I3._Ipc

// LEFT ISLAND: i3 workspaces as numbered chips with sliding underline.
// Focused = bright text + green underline, urgent = red text + red
// underline, occupied = bright text, empty = dim text.
Row {
  id: root
  spacing: 2
  required property var i3screen

  readonly property var allWorkspaces: I3.workspaces.values ?? []

  Repeater {
    model: root.allWorkspaces

    Item {
      required property var modelData
      readonly property bool isFocused: (I3.focusedWorkspace?.name ?? "") === modelData.name
      readonly property bool isUrgent: modelData.urgent ?? false
      readonly property bool isOccupied: (modelData.windows ?? 0) > 0
      width: wsLabel.implicitWidth + 20
      height: 28

      Text {
        id: wsLabel
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -2
        text: (modelData.name ?? "").replace(/[^0-9]/g, "") || modelData.name
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSize
        font.weight: isFocused ? Font.Bold : Font.Normal
        color: isFocused ? Theme.fg : (isUrgent ? Theme.red : (isOccupied ? Theme.fg : Theme.muted))

        Behavior on color {
          ColorAnimation {
            duration: 150
          }
        }
      }

      // underline indicator
      Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        anchors.horizontalCenter: parent.horizontalCenter
        width: isFocused ? wsLabel.implicitWidth + 8 : (isUrgent ? wsLabel.implicitWidth + 8 : 0)
        height: 2
        radius: 1
        color: isFocused ? Theme.green : Theme.red
        visible: isFocused || isUrgent

        Behavior on width {
          NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
          }
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: if (!parent.isFocused)
          wsLabel.color = Theme.green
        onExited: wsLabel.color = parent.isFocused ? Theme.fg : (parent.isUrgent ? Theme.red : (parent.isOccupied ? Theme.fg : Theme.muted))
        onClicked: I3.dispatch("workspace " + parent.modelData.name)
        onWheel: wheel => {
          const dir = wheel.angleDelta.y > 0 ? "prev" : "next";
          I3.dispatch("workspace " + dir);
        }
      }
    }
  }
}
