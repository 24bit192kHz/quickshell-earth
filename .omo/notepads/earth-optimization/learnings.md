Set PRAGMA mmap_size=3000000000, cache_size=100; add thread-local SQLite pools in server.py. Retain standard ROWID tables.
- Removed ListModel in VirtualPatch.qml. Used a static Repeater with `maxTiles` (600) and implemented a JS ring buffer using an `activeTiles` dictionary and `freeTiles` array to cycle through pre-allocated `Image` items dynamically. This guarantees zero QML object allocations during panning.
# Earth Optimization Learnings

- **Native C++ Image Decoding**: Decoded images in Python waste up to 10x network/IPC bandwidth when serving tiles to Qt/QML. Qt/QML can decode compressed image formats natively in C++ via hardware-accelerated pathways. Serving raw compressed bytes directly reduces overhead and CPU utilization.
- **OS Page Cache vs In-Memory LRU Cache**: SQLite `mmap` with a large size handles file-level caching natively at the operating system page cache layer. Python-level `@functools.lru_cache` causes duplicate memory usage, garbage collection overhead, and prevents memory reclamation by the OS.
- **FBO Size Capping & Image sourceSize constraints**: Capped FBO (`ShaderEffectSource`) `textureSize` statically to `Qt.size(2048, 2048)` to avoid driver-level VRAM fragmentation during zooming. Added `sourceSize: Qt.size(256, 256)` on `VirtualPatch` tile images to restrict memory overhead from high-resolution image decoding.
- TCP_NODELAY combined with application-layer HTTP response batching (writing headers + body in one wfile.write() call) eliminates MTU fragmentation and ensures line-rate local tile serving.
