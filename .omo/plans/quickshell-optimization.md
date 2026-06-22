# Quickshell Performance Optimization Plan

## Context
Addressing a ~2-second load time, textureless initial Earth rendering, and slow theming changes. The plan targets four isolated bottlenecks: bash/sed overhead in theming, ImageMagick blocking startup, asynchronous texture loading in QML, and Python cold-start latency for color generation.

## TODOs

### Wave 1
- [ ] Task 1: Refactor applycolor.sh
- [ ] Task 2: Remove magick identify from Background.qml
- [ ] Task 3: Implement Earth Texture Placeholders
- [ ] Task 4: Cache Python Palettes

## Final Verification Wave
- [ ] F1: Verify Quickshell startup time is reduced.
- [ ] F2: Verify Earth renders immediately with low-res texture, fading into 8K.
- [ ] F3: Verify theming applies correctly without python cold-start latency on cached planets.
