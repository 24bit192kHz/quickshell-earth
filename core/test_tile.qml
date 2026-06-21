import QtQuick
Window {
    visible: true; width: 200; height: 200
    Image { id: img; source: "../assets/textures/moon_2k.jpg"; fillMode: Image.Tile; visible: false }
    ShaderEffect {
        anchors.fill: parent
        property var tex: img
        fragmentShader: "
            #version 440
            layout(location = 0) in vec2 qt_TexCoord0;
            layout(location = 0) out vec4 fragColor;
            layout(binding = 1) uniform sampler2D tex;
            void main() { fragColor = texture(tex, qt_TexCoord0 * 2.0); }
        "
    }
}
