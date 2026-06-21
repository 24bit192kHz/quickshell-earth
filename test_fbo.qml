import QtQuick

Window {
    width: 400; height: 400; visible: true

    Item {
        id: sharedTextures
        Image { id: img; source: "assets/textures/moon_2k.jpg"; visible: false; asynchronous: false }
        ShaderEffectSource { id: fbo; sourceItem: img; wrapMode: ShaderEffectSource.Repeat }
    }

    ShaderEffect {
        anchors.fill: parent
        property var tex: sharedTextures.fbo
        fragmentShader: "qrc:/qt-project.org/imports/QtQuick/shaders/shadereffect.frag" // simple passthrough
        // Wait, standard passthrough needs valid vertices.
        // Let's just use an Image with source: sharedTextures.fbo
    }
}
