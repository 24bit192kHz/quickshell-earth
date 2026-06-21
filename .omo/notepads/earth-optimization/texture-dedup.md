## Texture Deduplication
Removed ShaderEffectSource wrappers in core/Earth.qml. Using Image items directly.
QQuickTextureFactory naturally deduplicates images loaded via same source URL, saving memory without FBO context sharing issues in Wayland.

