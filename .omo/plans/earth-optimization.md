# Earth Repository Optimization Plan

## TODOs
### Wave 1
- [ ] Task 1: SQLite Mmap & Connection Pooling (server.py)
- [ ] Task 2: Strip Python Caching & Decoding (server.py)
- [ ] Task 4: Math Offload (Astronomy JS -> C++)
- [ ] Task 5: Wayland Texture Deduplication (Earth.qml/shell.qml)
- [ ] Task 6: VirtualPatch QML Rewrite (VirtualPatch.qml)

### Wave 2
- [ ] Task 3: Network Batching & TCP_NODELAY (server.py)
- [ ] Task 7: FBO & SourceSize Caps (VirtualPatch.qml)

### Wave 3
- [ ] Task 8: Integration Profiling

## Final Verification Wave
- [ ] F1: Verify VRAM caps bounded and deduplicated
- [ ] F2: Verify zero ListModel object churn
- [ ] F3: Verify stable 60fps under Wayland
- [ ] F4: Verify server raw byte mmap passthrough