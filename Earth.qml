import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var modelData
    required property QtObject solarState
    required property var monitorLayout
    required property real sceneCenterX
    required property real sceneCenterY
    required property real primaryScreenHeight

    screen: modelData

    WlrLayershell.namespace: "earth-sphere-bg"
    WlrLayershell.layer: WlrLayer.Bottom

    focusable: false
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    implicitWidth: root.screen.width
    implicitHeight: root.screen.height

    // ── Screen Position (auto-detected from hyprctl) ─────
    property string screenName: root.modelData.name || ""
    property var myMonitor: root.monitorLayout[root.screenName] || null
    property real screenGlobalX: root.myMonitor ? root.myMonitor.x : 0
    property real screenGlobalY: root.myMonitor ? root.myMonitor.y : 0

    // Scene sizing from primary screen
    property real baseSize: root.primaryScreenHeight * 0.75

    // Scene center (center of primary/focused monitor)
    property real sceneCX: root.sceneCenterX
    property real sceneCY: root.sceneCenterY

    // Convert scene-relative position to local screen coordinates
    function toLocalX(relX) { return root.sceneCX + relX - root.screenGlobalX }
    function toLocalY(relY) { return root.sceneCY + relY - root.screenGlobalY }

    // ── Convenience Aliases ──────────────────────────────
    property real zoomScale: root.solarState.zoomScale
    property real userOffsetAngle: root.solarState.userOffsetAngle
    property real userTiltOffset: root.solarState.userTiltOffset
    property real utcDaysMod: root.solarState.utcDaysMod

    // ── High Precision Astronomical Coordinates ────────────────
    property real sunRa: root.solarState.sunRa
    property real sunDec: root.solarState.sunDec
    property real moonRa: root.solarState.moonRa
    property real moonDec: root.solarState.moonDec
    property real gmst: root.solarState.gmst
    property real eps: root.solarState.eps
    
    // Local Apparent Sidereal Time (LAST) at the center of the screen
    // userOffsetAngle is included so dragging the mouse orbits the camera, changing time-of-day perspective.
    property real localSiderealTime: gmst + root.solarState.userLonRad - root.userOffsetAngle
    
    // Convert Equatorial (RA/Dec) to Local Camera Cartesian
    // Camera is looking down -Z axis, at RA = localSiderealTime, Dec = 0
    property real sunLocalRa: sunRa - localSiderealTime
    property real baseSunX: Math.sin(sunLocalRa) * Math.cos(sunDec) * root.sunDistance
    property real baseSunY: Math.sin(sunDec) * root.sunDistance
    // Positive Z so that when sunLocalRa=0 (camera between Sun and Earth), Sun is behind the camera (+Z)
    property real baseSunZ: Math.cos(sunLocalRa) * Math.cos(sunDec) * root.sunDistance
    
    property real moonLocalRa: moonRa - localSiderealTime
    property real baseMoonX: Math.sin(moonLocalRa) * Math.cos(moonDec) * root.moonDistance
    property real baseMoonY: Math.sin(moonDec) * root.moonDistance
    property real baseMoonZ: Math.cos(moonLocalRa) * Math.cos(moonDec) * root.moonDistance

    // ── Camera Projection ──────────────────────────────
    property real cameraTilt: root.solarState.userTiltOffset + Math.PI / 6.0 // Look down slightly

    // Apply Camera Tilt to Celestial Bodies
    // We intentionally decouple the Sun and Moon from the camera tilt so they remain
    // beautifully framed in the background sky rather than sweeping wildly off-screen.
    property real sunX3D: baseSunX
    property real sunY3D: baseSunY
    property real sunZ3D: baseSunZ

    property real moonX3D: baseMoonX
    property real moonY3D: baseMoonY
    property real moonZ3D: baseMoonZ


    // ── 3D Scene Properties ──────────────────────────────
    property real orbitRadius: root.baseSize * 0.9
    property real cameraZ: root.baseSize * 3.0      // Camera distance from Earth
    property real sunDistance: root.baseSize * 6.0  // True distance to the Sun
    property real moonDistance: root.baseSize * 2.0 // True distance to the Moon

    property bool moonInFrontOfCamera: root.moonZ3D < root.cameraZ
    property real moonDistToCamera: root.cameraZ - root.moonZ3D
    property real moonProjScale: moonInFrontOfCamera ? (root.cameraZ / Math.max(0.001, root.moonDistToCamera)) : 0

    property real moonProjX: root.moonX3D * root.moonProjScale
    property real baseMoonSize: root.baseSize * 0.27
    property real vMoonSize: root.baseMoonSize * root.zoomScale * root.moonProjScale

    

    property bool sunInFrontOfCamera: root.sunZ3D < root.cameraZ
    property real sunDistToCamera: root.cameraZ - root.sunZ3D
    property real sunProjScale: sunInFrontOfCamera ? (root.cameraZ / Math.max(0.001, root.sunDistToCamera)) : 0

    property real sunProjX: root.sunX3D * root.sunProjScale
    property real baseSunSize: root.baseSize * 5.0
    property real vSunSize: root.baseSunSize * root.zoomScale * root.sunProjScale

    // ── Viewport Positions ───────────────────────────────
    property real vEarthSize: root.baseSize * root.zoomScale
    property real vEarthX: toLocalX(-root.vEarthSize / 2)
    property real vEarthY: toLocalY(-root.vEarthSize / 2)

    property real vMoonX: toLocalX(root.moonProjX * root.zoomScale - root.vMoonSize / 2)
    property real vMoonY: toLocalY(-root.moonY3D * root.zoomScale * root.moonProjScale - root.vMoonSize / 2)

    property real vSunX: toLocalX(root.sunProjX * root.zoomScale - root.vSunSize / 2)
    property real vSunY: toLocalY(-root.sunY3D * root.zoomScale * root.sunProjScale - root.vSunSize / 2 + root.baseSize * 0.16 * root.zoomScale * root.sunProjScale)

    // Wayland mask removed to allow the full-screen background to render.
    
    // ── Global Background (Dynamic Equirectangular Panorama) ──
    Image { id: milkyWayTexSrc; source: Qt.resolvedUrl("8k_stars_milky_way.jpg"); visible: false }

    ShaderEffect {
        id: bgSphere
        anchors.fill: parent
        z: -10

        property real localSiderealTime: root.localSiderealTime
        property real userTiltOffset: root.userTiltOffset
        property real aspect: root.width / Math.max(1.0, root.height)

        property var bgTex: milkyWayTexSrc

        vertexShader: "stars.vert.qsb"
        fragmentShader: "stars.frag.qsb"
    }

    // ── Interaction ──────────────────────────────────────
    MouseArea {
        id: dragArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton

        property real lastX: 0
        property real lastY: 0

        onPressed: (mouse) => {
            lastX = mouse.x
            lastY = mouse.y
            root.solarState.isDragging = true
        }

        onPositionChanged: (mouse) => {
            if (root.solarState.isDragging) {
                let dx = mouse.x - lastX
                let dy = mouse.y - lastY
                
                root.solarState.userOffsetAngle += dx / 500.0
                root.solarState.userTiltOffset += dy / 500.0

                // Allow tilting all the way to the poles (Math.PI / 2)
                // We subtract the base camera tilt (Math.PI / 6) to stop exactly at the poles
                let maxTilt = (Math.PI / 2.0) - (Math.PI / 6.0)
                let minTilt = -(Math.PI / 2.0) - (Math.PI / 6.0)
                if (root.solarState.userTiltOffset > maxTilt) root.solarState.userTiltOffset = maxTilt
                if (root.solarState.userTiltOffset < minTilt) root.solarState.userTiltOffset = minTilt

                lastX = mouse.x
                lastY = mouse.y
            }
        }

        onReleased: {
            root.solarState.isDragging = false
        }

        onWheel: (wheel) => {
            if (wheel.angleDelta.y > 0) {
                root.solarState.zoomScale = Math.min(root.solarState.zoomScale * 1.15, 15.0)
            } else if (wheel.angleDelta.y < 0) {
                root.solarState.zoomScale = Math.max(root.solarState.zoomScale / 1.15, 0.15)
            }
        }
    }

    // ── Sun depth ────────────────────────────────────────
    // Depth handled by perspective projection above

    // ── Textures ─────────────────────────────────────────
    Image { id: earthTexSrc; source: Qt.resolvedUrl("earth_8k.jpg"); visible: false }
    // Fetch live global cloud composite generated from weather satellites (updated every 3 hours)
    Image { 
        id: cloudTexSrc; 
        source: "https://clouds.matteason.co.uk/images/8192x4096/clouds.jpg?v=" + root.solarState.cloudUpdateFlag; 
        visible: false 
    }
    Image { id: nightTexSrc; source: Qt.resolvedUrl("night_8k.jpg"); visible: false }
    Image { id: bumpTexSrc; source: Qt.resolvedUrl("elev_bump_8k.jpg"); visible: false }
    Image { id: waterTexSrc; source: Qt.resolvedUrl("water_8k.png"); visible: false }
    Image { id: moonTexSrc; source: Qt.resolvedUrl("moon_8k.jpg"); visible: false }

    // ── Sun ──────────────────────────────────────────────
    ShaderEffect {
        id: sunSphere
        x: root.vSunX; y: root.vSunY
        width: root.vSunSize; height: root.vSunSize
        z: -2
        
        opacity: {
            if (!root.sunInFrontOfCamera) return 0.0;
            // Fade out smoothly as it sweeps past the camera
            let fadeDist = root.cameraZ * 0.3; // start fading when within 30% of camera plane
            if (root.sunDistToCamera < fadeDist) {
                return Math.max(0.0, root.sunDistToCamera / fadeDist);
            }
            return 1.0;
        }
        visible: opacity > 0

        vertexShader: "sun.vert.qsb"
        fragmentShader: "sun.frag.qsb"
    }

    // ── Earth ────────────────────────────────────────────
    ShaderEffect {
        id: earthSphere
        x: root.vEarthX; y: root.vEarthY
        width: root.vEarthSize; height: root.vEarthSize
        z: 0

        property real utcDaysMod: root.utcDaysMod
        property real cameraTilt: root.cameraTilt

        property real time: root.solarState.timeSec
        property real gmst: root.solarState.gmst
        property real sunRa: root.solarState.sunRa
        property real sunDec: root.solarState.sunDec
        property real userLonRad: root.solarState.userLonRad
        property real userOffsetAngle: root.userOffsetAngle

        property var earthTex: earthTexSrc
        property var cloudTex: cloudTexSrc
        property var nightTex: nightTexSrc
        property var bumpTex: bumpTexSrc
        property var waterTex: waterTexSrc

        vertexShader: "earth.vert.qsb"
        fragmentShader: "earth.frag.qsb"
    }

    // ── Moon ─────────────────────────────────────────────
    ShaderEffect {
        id: moonSphere
        x: root.vMoonX; y: root.vMoonY
        width: root.vMoonSize; height: root.vMoonSize
        z: root.moonZ3D < 0 ? -1 : 1

        property real angle: -(root.moonRa / (Math.PI * 2))
        property real tilt: root.userTiltOffset * Math.PI
        property real lightDirX: root.sunX3D - root.moonX3D
        property real lightDirY: root.sunY3D - root.moonY3D
        property real lightDirZ: root.sunZ3D - root.moonZ3D

        property var moonTex: moonTexSrc

        vertexShader: "moon.vert.qsb"
        fragmentShader: "moon.frag.qsb"
    }
}
