# Quickshell Optimization Learnings

## Background QML
- Replaced blocking `magick identify` Process with an asynchronous, invisible QML `Image` element to bind dimensions (`sourceSize`) directly via Qt internals. This avoids spawning an external shell process and blocking the UI.
