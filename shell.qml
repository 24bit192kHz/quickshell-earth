import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    id: shell

    // ── Monitor Layout (auto-detected from Hyprland) ─────
    property var monitorLayout: ({})
    property real primaryCenterX: 960
    property real primaryCenterY: 540
    property real primaryHeight: 1080

    Process {
        id: hyprProc
        command: ["hyprctl", "monitors", "-j"]
        running: true

        property string buf: ""

        stdout: SplitParser {
            onRead: data => { hyprProc.buf += data + "\n" }
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) return
            try {
                let monitors = JSON.parse(hyprProc.buf)
                let layout = {}
                let primaryName = ""

                for (let i = 0; i < monitors.length; i++) {
                    let m = monitors[i]
                    let lw = m.width / m.scale
                    let lh = m.height / m.scale
                    if (m.transform % 2 === 1) {
                        let tmp = lw; lw = lh; lh = tmp
                    }
                    layout[m.name] = { x: m.x, y: m.y, width: lw, height: lh }
                    if (m.focused) primaryName = m.name
                }

                if (!primaryName && monitors.length > 0)
                    primaryName = monitors[0].name

                shell.monitorLayout = layout

                let p = layout[primaryName]
                if (p) {
                    shell.primaryCenterX = p.x + p.width / 2.0
                    shell.primaryCenterY = p.y + p.height / 2.0
                    shell.primaryHeight = p.height
                }
            } catch(e) {
                console.error("Failed to parse hyprctl:", e)
            }
        }
    }

    // ── IP Geolocation (Auto-Center) ─────────────────────
    Process {
        id: locProc
        command: ["curl", "-s", "http://ip-api.com/json/"]
        running: true
        
        property string buf: ""
        stdout: SplitParser {
            onRead: data => { locProc.buf += data }
        }
        
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) return
            try {
                let data = JSON.parse(locProc.buf)
                if (data.status === "success" && data.lon !== undefined) {
                    // Center the camera mathematically on the user's longitude
                    state.userLonRad = data.lon * Math.PI / 180.0
                    state.userOffsetAngle = 0
                    
                    console.log("Centered Earth on", data.city + ",", data.country, "(Lon:", data.lon + ")")
                }
            } catch(e) {
                console.error("Failed to parse location:", e)
            }
        }
    }

    // ── Shared Solar System State ────────────────────────
    QtObject {
        id: state

        property real sunOrbitAngle: 0
        property real moonOrbitAngle: 0
        property real utcDaysMod: 0

        property real userOffsetAngle: 0
        property real userTiltOffset: 0
        property real userLonRad: 0
        property real timeSec: 0
        property real zoomScale: 1.0
        property bool isDragging: false

        Behavior on userTiltOffset {
            enabled: !state.isDragging
            SpringAnimation { spring: 0.4; damping: 0.15; mass: 2.0; epsilon: 0.001 }
        }

        Behavior on zoomScale {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }
    }

    // ── Real-Time Astronomy Engine ───────────────────────
    Timer {
        interval: 16 // 60fps
        running: true
        repeat: true
        onTriggered: {
            let ms = Date.now()
            let now = new Date(ms)
            
            // Season (0 to 2PI). June 21 is day 172. 
            // At 0, North Pole tilts directly at Sun.
            let startOfYear = new Date(now.getFullYear(), 0, 1)
            let dayOfYear = (now - startOfYear) / 86400000.0
            state.sunOrbitAngle = ((dayOfYear - 172) / 365.25) * 2 * Math.PI

            // Moon Phase (29.53 days)
            let newMoonRef = 1781405640000 // June 14, 2026
            let moonAgeDays = (ms - newMoonRef) / 86400000.0
            let moonPhase = (moonAgeDays % 29.530588) / 29.530588
            state.moonOrbitAngle = state.sunOrbitAngle - moonPhase * 2 * Math.PI

            // Time of day (UTC days for exact rotation mapping)
            state.utcDaysMod = (ms / 86400000.0) % 1.0
            
            // Fast time for shader animations (lightning, etc)
            state.timeSec = (ms % 1000000) / 1000.0
        }
    }

    // One Earth panel per screen, all sharing the same state
    Variants {
        model: Quickshell.screens
        Earth {
            solarState: state
            monitorLayout: shell.monitorLayout
            sceneCenterX: shell.primaryCenterX
            sceneCenterY: shell.primaryCenterY
            primaryScreenHeight: shell.primaryHeight
        }
    }
}
