import QtQuick
import Quickshell

ShellRoot {
    Component.onCompleted: {
        console.log(Quickshell.env("PLANET"))
        Qt.quit()
    }
}
