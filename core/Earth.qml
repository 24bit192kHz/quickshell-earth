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

    focusable: true
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


    // ── True 3D Scene Properties (Physical Camera Translation) ──
    property real orbitRadius: root.baseSize * 0.9
    property real baseCameraZ: root.baseSize * 3.0
    // As the user zooms, we physically move the camera forward along the Z axis instead of magnifying the lens
    property real currentCameraZ: baseCameraZ / Math.max(0.0001, root.zoomScale)
    
    property real sunDistance: root.solarState.activePlanet === "moon" ? root.baseSize * 150.0 : root.baseSize * 6.0
    property real moonDistance: root.solarState.activePlanet === "moon" ? root.baseSize * 44.24 : root.baseSize * 2.0

    // ── Moon Projection ──────────────────────────────────
    property bool moonInFrontOfCamera: root.moonZ3D < root.currentCameraZ
    property real moonDistToCamera: root.currentCameraZ - root.moonZ3D
    property real moonProjScale: moonInFrontOfCamera ? (baseCameraZ / Math.max(0.001, moonDistToCamera)) : 0

    property real moonProjX: root.moonX3D * moonProjScale
    property real baseMoonSize: root.solarState.activePlanet === "moon" ? root.baseSize * 3.667 : root.baseSize * 0.27
    property real vMoonSize: baseMoonSize * moonProjScale
    
    // ── Sun Projection ───────────────────────────────────
    property bool sunInFrontOfCamera: root.sunZ3D < root.currentCameraZ
    property real sunDistToCamera: root.currentCameraZ - root.sunZ3D
    property real sunProjScale: sunInFrontOfCamera ? (baseCameraZ / Math.max(0.001, sunDistToCamera)) : 0

    property real sunProjX: root.sunX3D * sunProjScale
    property real baseSunSize: root.solarState.activePlanet === "moon" ? root.baseSize * 125.0 : root.baseSize * 5.0
    property real vSunSize: baseSunSize * sunProjScale

    // ── Viewport Positions ───────────────────────────────
    // Earth is at Z=0, so its distance to camera is exactly currentCameraZ
    property real earthProjScale: baseCameraZ / root.currentCameraZ
    property real vEarthSize: root.baseSize * earthProjScale
    
    property real vEarthX: toLocalX(-vEarthSize / 2)
    property real vEarthY: toLocalY(-vEarthSize / 2)

    property real vMoonX: toLocalX(moonProjX - vMoonSize / 2)
    property real vMoonY: toLocalY(-root.moonY3D * moonProjScale - vMoonSize / 2)

    property real vSunX: toLocalX(sunProjX - vSunSize / 2)
    property real vSunY: toLocalY(-root.sunY3D * sunProjScale - vSunSize / 2 + root.baseSize * 0.16 * sunProjScale)

    // Wayland mask removed to allow the full-screen background to render.
    
    // ── Global Background (Dynamic Equirectangular Panorama) ──
    Image { id: milkyWayTexSrc; asynchronous: true; source: Qt.resolvedUrl("../assets/textures/8k_stars_milky_way.jpg"); mipmap: true; visible: false }

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
                
                root.solarState.targetUserOffsetAngle += dx / sensitivity
                root.solarState.targetUserTiltOffset += dy / sensitivity

                // Allow tilting all the way to the poles (Math.PI / 2)
                // We subtract the base camera tilt (Math.PI / 6) to stop exactly at the poles
                let maxTilt = (Math.PI / 2.0) - (Math.PI / 6.0)
                let minTilt = -(Math.PI / 2.0) - (Math.PI / 6.0)
                if (root.solarState.targetUserTiltOffset > maxTilt) root.solarState.targetUserTiltOffset = maxTilt
                if (root.solarState.targetUserTiltOffset < minTilt) root.solarState.targetUserTiltOffset = minTilt
                
                root.solarState.userOffsetAngle = root.solarState.targetUserOffsetAngle
                root.solarState.userTiltOffset = root.solarState.targetUserTiltOffset

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
                let getLonLatAt = function(px, py, zoom) {
                    let vSize = root.baseSize * zoom;
                    let vX = root.sceneCX - vSize / 2.0 - root.screenGlobalX;
                    let vY = root.sceneCY - vSize / 2.0 - root.screenGlobalY;
                    
                    let nx = (px - vX) / vSize * 2.0 - 1.0;
                    let ny = 1.0 - (py - vY) / vSize * 2.0;
                    
                    let z2 = 1.0 - nx*nx - ny*ny;
                    if (z2 < 0.0) return null; // Mouse is pointing at space
                    
                    let z = Math.sqrt(z2);
                    let a = -root.solarState.targetUserTiltOffset - (Math.PI / 6.0); // -root.cameraTilt equivalent for target state
                    let c = Math.cos(a);
                    let s = Math.sin(a);
                    
                    let normY = ny * c - z * s;
                    let normZ = ny * s + z * c;
                    let normX = nx;
                    
                    let lat = Math.asin(Math.max(-1.0, Math.min(1.0, normY)));
                    
                    let greenwichLocalRa = -root.solarState.userLonRad + root.solarState.targetUserOffsetAngle;
                    let sinG = Math.sin(greenwichLocalRa);
                    let cosG = Math.cos(greenwichLocalRa);
                    
                    let dotEast = normX * cosG - normZ * sinG;
                    let dotGreenwich = normX * sinG + normZ * cosG;
                    let lon = Math.atan2(dotEast, dotGreenwich);
                    
                    return {lon: lon, lat: lat};
                };
                
                let before = getLonLatAt(wheel.x, wheel.y, old_zoomScale);
                let after = getLonLatAt(wheel.x, wheel.y, new_zoomScale);
                
                if (before && after) {
                    // Mathematically inverse-transform the Earth's absolute Euler rotation 
                    // so the geographic coordinate exactly maps back to the mouse pixel
                    root.solarState.targetUserOffsetAngle += (after.lon - before.lon);
                    
                    let new_tilt = root.solarState.targetUserTiltOffset + (before.lat - after.lat);
                    let maxTilt = (Math.PI / 2.0) - (Math.PI / 6.0);
                    let minTilt = -(Math.PI / 2.0) - (Math.PI / 6.0);
                    root.solarState.targetUserTiltOffset = Math.max(minTilt, Math.min(maxTilt, new_tilt));
                }
            }
            
            root.solarState.zoomScale = root.solarState.targetZoomScale
            root.solarState.userOffsetAngle = root.solarState.targetUserOffsetAngle
            root.solarState.userTiltOffset = root.solarState.targetUserTiltOffset
        }
    }

    // ── Sun depth ────────────────────────────────────────
    // Depth handled by perspective projection above

    // ── Textures ─────────────────────────────────────────
    Image { id: earthImg; asynchronous: true; source: root.solarState.activePlanet === "earth" ? Qt.resolvedUrl("../assets/textures/earth_8k_opt.jpg") : (root.solarState.activePlanet === "moon" ? Qt.resolvedUrl("../assets/textures/8k_moon.jpg") : Qt.resolvedUrl("../assets/textures/2k_" + root.solarState.activePlanet + ".jpg")); mipmap: true; visible: false }
    ShaderEffectSource { id: earthTexSrc; sourceItem: earthImg; wrapMode: ShaderEffectSource.Repeat }
    
    Image { id: nightImg; asynchronous: true; source: Qt.resolvedUrl("../assets/textures/night_8k.jpg"); mipmap: true; visible: false }
    ShaderEffectSource { id: nightTexSrc; sourceItem: nightImg; wrapMode: ShaderEffectSource.Repeat }
    
    Image { id: bumpImg; asynchronous: true; source: Qt.resolvedUrl("../assets/textures/elev_bump_8k.jpg"); mipmap: true; visible: false }
    ShaderEffectSource { id: bumpTexSrc; sourceItem: bumpImg; wrapMode: ShaderEffectSource.Repeat }
    
    Image { id: waterImg; asynchronous: true; source: Qt.resolvedUrl("../assets/textures/water_8k.png"); mipmap: true; visible: false }
    ShaderEffectSource { id: waterTexSrc; sourceItem: waterImg; wrapMode: ShaderEffectSource.Repeat }
    
    Image { id: cloudImg; asynchronous: true; source: Qt.resolvedUrl("../assets/textures/8k_earth_clouds.jpg"); mipmap: true; visible: false }
    ShaderEffectSource { id: cloudTexSrc; sourceItem: cloudImg; wrapMode: ShaderEffectSource.Repeat }

    Image { id: moonImg; asynchronous: true; source: Qt.resolvedUrl("../assets/textures/moon_2k.jpg"); mipmap: true; visible: false }
    ShaderEffectSource { id: moonTexSrc; sourceItem: moonImg; wrapMode: ShaderEffectSource.Repeat }
    
    Image { id: saturnRingImg; asynchronous: true; source: Qt.resolvedUrl("../assets/textures/8k_saturn_ring_alpha.png"); mipmap: true; visible: false }
    ShaderEffectSource { id: saturnRingTexSrc; sourceItem: saturnRingImg; wrapMode: ShaderEffectSource.Repeat }

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
            let fadeDist = root.baseCameraZ * 0.3;
            if (root.sunDistToCamera < fadeDist) {
                return Math.max(0.0, root.sunDistToCamera / fadeDist);
            }
            return 1.0;
        }
        visible: opacity > 0

        vertexShader: "../assets/shaders/sun.vert.qsb"
        fragmentShader: "../assets/shaders/sun.frag.qsb"
    }

    // ── Planet Label ─────────────────────────────────────────
    Connections {
        target: root.solarState
        function onActivePlanetChanged() {
            planetLabel.opacity = 0.8
            labelTimer.restart()
        }
    }

    Text {
        id: planetLabel
        text: {
            let name = root.solarState.activePlanet
            if (name === "venus_surface") return "VENUS"
            return name.toUpperCase()
        }
        color: "#f4f4f4"
        font.family: "Futura" // A classic cinematic sci-fi font, will fallback cleanly if missing
        font.pixelSize: 64
        font.weight: Font.Thin
        font.letterSpacing: 48
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#cc000000"
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 4
            shadowBlur: 1.0
        }
        
        anchors.horizontalCenter: earthSphere.horizontalCenter
        y: Math.max(parent.height * 0.15, earthSphere.y - height - 60)
        z: 10
        
        opacity: 0.0
        
        Behavior on opacity {
            NumberAnimation { duration: 800; easing.type: Easing.InOutQuad }
        }

        Timer {
            id: labelTimer
            interval: 1500
            onTriggered: planetLabel.opacity = 0.0
        }
    }
    // ── Earth ────────────────────────────────────────────
    ShaderEffect {
        id: earthSphere
        x: root.vEarthX; y: root.vEarthY
        width: root.vEarthSize; height: root.vEarthSize
        z: 0

        property real isEarth: root.solarState.activePlanet === "earth" ? 1.0 : 0.0
        property real isSaturn: root.solarState.activePlanet === "saturn" ? 1.0 : 0.0

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
        property real cloudOpacity: root.solarState.activePlanet === "earth" ? Math.min(1.0, Math.max(0.0, 1.0 - (root.zoomScale - 15.0) / 10.0)) : 0.0

        vertexShader: "../assets/shaders/earth.vert.qsb"
        fragmentShader: "../assets/shaders/earth.frag.qsb"
    }

    // ── Saturn Rings ─────────────────────────────────────────
    ShaderEffect {
        id: saturnRing
        visible: root.solarState.activePlanet === "saturn"
        
        // 3x larger than the planet to accommodate the rings (outer edge ~2.27x)
        x: root.vEarthX - root.vEarthSize
        y: root.vEarthY - root.vEarthSize
        width: root.vEarthSize * 3.0
        height: root.vEarthSize * 3.0
        z: 1  // Rendered on top of earthSphere, shader will clip fragments behind the sphere

        property real utcDaysMod: 0.0
        property real cameraTilt: root.cameraTilt
        property real time: 0.0
        property real gmst: root.solarState.gmst
        property real sunRa: root.solarState.sunRa
        property real sunDec: root.solarState.sunDec
        property real userLonRad: root.solarState.userLonRad
        property real userOffsetAngle: root.userOffsetAngle
        property vector4d patchBounds: Qt.vector4d(0,0,0,0)
        property real patchReady: 0.0
        property real cloudOpacity: 0.0
        property real isEarth: 0.0
        property real isSaturn: 1.0
        
        property var ringTex: saturnRingTexSrc

        vertexShader: "../assets/shaders/earth.vert.qsb" // Standard pass-through vertex shader
        fragmentShader: "../assets/shaders/saturn_ring.frag.qsb"
    }

    // ── Satellite (Moon or Earth) ────────────────────────
    ShaderEffect {
        id: satelliteSphere
        
        opacity: {
            if (!root.moonInFrontOfCamera) return 0.0;
            let fadeDist = root.baseCameraZ * 0.1; // Smoothly fade out when camera flies very close to it
            if (root.moonDistToCamera < fadeDist) {
                return Math.max(0.0, root.moonDistToCamera / fadeDist);
            }
            return 1.0;
        }
        visible: (root.solarState.activePlanet === "earth" || root.solarState.activePlanet === "moon") && opacity > 0
        
        x: root.vMoonX; y: root.vMoonY
        width: root.vMoonSize; height: root.vMoonSize
        z: root.moonZ3D < 0 ? -1 : 1

        property real angle: root.solarState.activePlanet === "moon" ? -(root.solarState.userLonRad - root.userOffsetAngle) / (Math.PI * 2) : -(root.moonRa / (Math.PI * 2))
        property real tilt: root.userTiltOffset * Math.PI
        property real rawLightDirX: root.solarState.activePlanet === "moon" ? 1.0 : root.sunX3D - root.moonX3D
        property real rawLightDirY: root.solarState.activePlanet === "moon" ? 0.3 : root.sunY3D - root.moonY3D
        property real rawLightDirZ: root.solarState.activePlanet === "moon" ? 0.5 : root.sunZ3D - root.moonZ3D
        property real lightDirLen: Math.max(0.001, Math.sqrt(rawLightDirX*rawLightDirX + rawLightDirY*rawLightDirY + rawLightDirZ*rawLightDirZ))
        property real lightDirX: rawLightDirX / lightDirLen
        property real lightDirY: rawLightDirY / lightDirLen
        property real lightDirZ: rawLightDirZ / lightDirLen

        property var moonTex: root.solarState.activePlanet === "moon" ? earthOnlyTexSrc : moonTexSrc
        property var cloudTex: cloudTexSrc // Passed only when the shader needs it
        property var nightTex: nightTexSrc
        property real time: root.solarState.timeSec

        vertexShader: "../assets/shaders/moon.vert.qsb"
        fragmentShader: root.solarState.activePlanet === "moon" ? "../assets/shaders/satellite_earth.frag.qsb" : "../assets/shaders/moon.frag.qsb"
    } // Close moonSphere

    // ── Input ──────────────────────────────────────────────
    Shortcut {
        sequence: "Right"
        onActivated: {
            root.solarState.activePlanetIndex = (root.solarState.activePlanetIndex + 1) % root.solarState.planets.length
        }
    }

    Shortcut {
        sequence: "Left"
        onActivated: {
            root.solarState.activePlanetIndex = (root.solarState.activePlanetIndex - 1 + root.solarState.planets.length) % root.solarState.planets.length
        }
    }
} // Close PanelWindow
