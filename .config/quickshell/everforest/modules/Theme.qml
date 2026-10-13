pragma Singleton
import QtQuick

// Everforest Dim palette (mirrors dotfiles .config/polybar/config.ini [colors])
QtObject {
  readonly property color bg: "#1e2326"
  readonly property color base: "#232a2e"
  readonly property color hover: "#2e383c"
  readonly property color border: "#3a4141"
  readonly property color fg: "#ffffff"
  readonly property color muted: "#7a8478"
  readonly property color green: "#a7c080"
  readonly property color red: "#e67e80"
  readonly property color yellow: "#dbbc7f"
  readonly property color blue: "#7fbbb3"
  readonly property color grey: "#475258"

  readonly property int barHeight: 38
  readonly property int radius: 4
  readonly property string fontMain: "Inter"
  readonly property string fontMono: "GeistMono Nerd Font Mono"
  readonly property int fontSize: 15
  readonly property string separator: "│"
}
