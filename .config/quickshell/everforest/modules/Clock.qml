import QtQuick
import Quickshell

// Center island: date - matches side islands (bg, radius 8, full height)
Rectangle {
  width: clockLabel.implicitWidth + 32
  height: Theme.barHeight
  radius: Theme.radius
  color: Theme.bg
  border.width: 1
  border.color: Theme.border

  Text {
    id: clockLabel
    anchors.centerIn: parent
    text: Qt.formatDateTime(clock.date, "ddd dd MMM  hh:mm")
    font.family: Theme.fontMain
    font.pixelSize: Theme.fontSize
    font.weight: Font.DemiBold
    color: Theme.fg
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }
}
