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

    // Apply Camera Tilt to Celestial Bodies (10% parallax to match stars)
    property real tiltParallax: root.solarState.userTiltOffset * 0.1
    property real tiltCos: Math.cos(tiltParallax)
    property real tiltSin: Math.sin(tiltParallax)

    property real sunX3D: baseSunX
    property real sunY3D: baseSunY * tiltCos - baseSunZ * tiltSin
    property real sunZ3D: baseSunY * tiltSin + baseSunZ * tiltCos

    property real moonX3D: baseMoonX
    property real moonY3D: baseMoonY * tiltCos - baseMoonZ * tiltSin
    property real moonZ3D: baseMoonY * tiltSin + baseMoonZ * tiltCos


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
    Image { id: milkyWayTexSrc; source: Qt.resolvedUrl("../assets/textures/4k_stars_milky_way.jpg"); mipmap: true; visible: false }

    ShaderEffect {
        id: bgSphere
        anchors.fill: parent
        z: -10

        property real localSiderealTime: root.localSiderealTime
        property real userTiltOffset: root.userTiltOffset
        property real aspect: root.width / Math.max(1.0, root.height)

        property var bgTex: milkyWayTexSrc

        vertexShader: "../assets/shaders/stars.vert.qsb"
        fragmentShader: "../assets/shaders/stars.frag.qsb"
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
            root.solarState.issModeActive = false
            root.solarState.lastInteractionTime = Date.now()
        }

        onPositionChanged: (mouse) => {
            root.solarState.lastInteractionTime = Date.now()
            if (root.solarState.isDragging) {
                let dx = mouse.x - lastX
                let dy = mouse.y - lastY
                
                // Scale panning sensitivity inversely with zoom so the screen-space movement matches mouse movement
                let sensitivity = 500.0 * root.zoomScale
                
                root.solarState.userOffsetAngle += dx / sensitivity
                root.solarState.userTiltOffset += dy / sensitivity

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
            root.solarState.issModeActive = false
            root.solarState.lastInteractionTime = Date.now()
            
            let old_zoomScale = root.solarState.targetZoomScale
            let input_factor = root.solarState.ctrlHeld ? 1.5 : 1.15
            
            if (wheel.angleDelta.y > 0) {
                root.solarState.targetZoomScale = Math.min(old_zoomScale * input_factor, 250.0)
            } else if (wheel.angleDelta.y < 0) {
                root.solarState.targetZoomScale = Math.max(old_zoomScale / input_factor, 0.15)
            }
            
            let new_zoomScale = root.solarState.targetZoomScale
            let actual_factor = new_zoomScale / old_zoomScale
            
            if (actual_factor !== 1.0) {
                // Calculate geometric center of the Earth on THIS specific monitor
                let center_x = root.sceneCX - root.screenGlobalX
                let center_y = root.sceneCY - root.screenGlobalY
                
                let dx_before = wheel.x - center_x
                let dy_before = wheel.y - center_y
                
                // The visual shift caused by scaling the Earth outwards from the center
                let shift_x = dx_before * (1.0 - actual_factor)
                let shift_y = dy_before * (1.0 - actual_factor)
                
                let new_sensitivity = 500.0 * new_zoomScale
                
                root.solarState.userOffsetAngle += shift_x / new_sensitivity
                
                // Allow tilting all the way to the poles exactly like dragging
                let new_tilt = root.solarState.userTiltOffset + (shift_y / new_sensitivity)
                let maxTilt = (Math.PI / 2.0) - (Math.PI / 6.0)
                let minTilt = -(Math.PI / 2.0) - (Math.PI / 6.0)
                root.solarState.userTiltOffset = Math.max(minTilt, Math.min(maxTilt, new_tilt))
            }
            
            root.solarState.zoomScale = root.solarState.targetZoomScale
        }
    }

    // ── Sun depth ────────────────────────────────────────
    // Depth handled by perspective projection above

    // ── Textures ─────────────────────────────────────────
    Image { id: earthTexSrc; source: Qt.resolvedUrl("../assets/textures/earth_8k_opt.jpg"); mipmap: true; visible: false }
    Image { id: nightTexSrc; source: Qt.resolvedUrl("../assets/textures/night_8k.jpg"); sourceSize: Qt.size(4096, 2048); mipmap: true; visible: false }
    Image { id: bumpTexSrc; source: Qt.resolvedUrl("../assets/textures/elev_bump_8k.jpg"); sourceSize: Qt.size(4096, 2048); mipmap: true; visible: false }
    Image { id: waterTexSrc; source: Qt.resolvedUrl("../assets/textures/water_8k.png"); sourceSize: Qt.size(4096, 2048); mipmap: true; visible: false }
    Image { id: cloudTexSrc; source: Qt.resolvedUrl("../assets/textures/clouds_4k.jpg"); mipmap: true; visible: false }
    Image { id: moonTexSrc; source: Qt.resolvedUrl("../assets/textures/moon_2k.jpg"); mipmap: true; visible: false }

    // ── Native Virtual Texturing ─────────────────────────
    property real patchMinU: 0.0
    property real patchMaxU: 0.0
    property real patchMinV: 0.0
    property real patchMaxV: 0.0

    VirtualPatch {
        id: virtualPatch
        minU: root.patchMinU
        maxU: root.patchMaxU
        minV: root.patchMinV
        maxV: root.patchMaxV
        tileServerUrl: root.solarState.tileServerUrl
    }

    onCameraTiltChanged: updatePatchBounds()
    onWidthChanged: updatePatchBounds()
    onHeightChanged: updatePatchBounds()
    onVEarthSizeChanged: updatePatchBounds()
    
    Connections {
        target: root.solarState
        function onUserOffsetAngleChanged() { root.updatePatchBounds() }
        function onUserLonRadChanged() { root.updatePatchBounds() }
    }

    function updatePatchBounds() {
        if (!root.solarState) return;
        
        let max_visible_x = root.width / vEarthSize;
        let max_visible_y = root.height / vEarthSize;
        
        if (max_visible_x > 1.5 || max_visible_y > 1.5) {
            root.patchMinU = 0; root.patchMaxU = 0; root.patchMinV = 0; root.patchMaxV = 0;
            return;
        }
        
        let lon_range = Math.asin(Math.min(1.0, max_visible_x));
        let lat_range = Math.asin(Math.min(1.0, max_visible_y));
        
        // Raycast from the center of THIS specific monitor to the sphere
        // Calculate vEarthX/Y locally to bypass QML binding update order issues during zoom
        let local_vEarthX = root.sceneCX - root.vEarthSize / 2.0 - root.screenGlobalX;
        let local_vEarthY = root.sceneCY - root.vEarthSize / 2.0 - root.screenGlobalY;
        
        let screenCenterLocalX = root.width / 2.0 - local_vEarthX;
        let screenCenterLocalY = root.height / 2.0 - local_vEarthY;
        
        let x = (screenCenterLocalX / root.vEarthSize) * 2.0 - 1.0;
        let y = 1.0 - (screenCenterLocalY / root.vEarthSize) * 2.0;
        
        let center_lon = root.solarState.userLonRad - root.solarState.userOffsetAngle;
        let center_lat = root.cameraTilt;
        
        let z2 = 1.0 - x*x - y*y;
        if (z2 >= 0.0) {
            let z = Math.sqrt(z2);
            let a = -root.cameraTilt;
            let c = Math.cos(a);
            let s = Math.sin(a);
            
            let normY = y * c - z * s;
            let normZ = y * s + z * c;
            let normX = x;
            
            center_lat = Math.asin(Math.max(-1.0, Math.min(1.0, normY)));
            
            let greenwichLocalRa = -root.solarState.userLonRad + root.solarState.userOffsetAngle;
            let sinG = Math.sin(greenwichLocalRa);
            let cosG = Math.cos(greenwichLocalRa);
            
            let dotEast = normX * cosG - normZ * sinG;
            let dotGreenwich = normX * sinG + normZ * cosG;
            center_lon = Math.atan2(dotEast, dotGreenwich);
        }
        
        let u_center = (center_lon / (2.0 * Math.PI)) + 0.5;
        u_center = u_center - Math.floor(u_center);
        
        // Web Mercator v_center
        let maxLat = 1.4844; // ~85.05 degrees
        let clamped_lat = Math.max(-maxLat, Math.min(maxLat, center_lat));
        let v_center = 0.5 - Math.log(Math.tan(Math.PI / 4.0 + clamped_lat / 2.0)) / (2.0 * Math.PI);
        
        // Fetch a patch slightly larger than the screen to avoid edge pop-in
        let bufferU = (lon_range / (2.0 * Math.PI)) * 1.5;
        let mercator_scale = 1.0 / Math.max(0.01, Math.cos(clamped_lat));
        let bufferV = (lat_range / (2.0 * Math.PI)) * 1.5 * mercator_scale;
        
        root.patchMinU = u_center - bufferU;
        root.patchMaxU = u_center + bufferU;
        root.patchMinV = Math.max(0.0, v_center - bufferV);
        root.patchMaxV = Math.min(1.0, v_center + bufferV);
    }

    // ── Removed Python HTTP patch images ────────────────

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

        vertexShader: "../assets/shaders/sun.vert.qsb"
        fragmentShader: "../assets/shaders/sun.frag.qsb"
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

        property variant earthTex: earthTexSrc
        property variant nightTex: nightTexSrc
        property variant bumpTex: bumpTexSrc
        property variant waterTex: waterTexSrc
        property variant cloudTex: cloudTexSrc
        property var patchTex: virtualPatch.textureProvider
        property vector4d patchBounds: Qt.vector4d(root.patchMinU, root.patchMinV, root.patchMaxU, root.patchMaxV)
        property real patchReady: 1.0
        property real cloudOpacity: Math.min(1.0, Math.max(0.0, 1.0 - (root.zoomScale - 15.0) / 10.0))

        vertexShader: "../assets/shaders/earth.vert.qsb"
        fragmentShader: "../assets/shaders/earth.frag.qsb"
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

        vertexShader: "../assets/shaders/moon.vert.qsb"
        fragmentShader: "../assets/shaders/moon.frag.qsb"
    }
}
