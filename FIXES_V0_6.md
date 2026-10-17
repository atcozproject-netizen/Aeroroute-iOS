# Aeroroute Godot V0.6 – performance and iPhone polish

This is the real Godot 4.5.x game source. The HTML-based V0.5 is not used.

## Fixed

- Airport level of detail by zoom level: global views only show major hubs, smaller airports appear as you zoom in.
- Screen-space marker collision detection and much fewer ICAO labels, with label-overlap prevention.
- LOD coastal geometry (about 60% fewer points at the default zoom) built once on game configuration and reused during pan/zoom.
- Map selection matches currently visible pins to avoid accidental route selection from invisible cities. Search supports all airports.
- Zoom now retains the geographical point under the fingers/cursor instead of drifting across the globe.
- Replaced unsupported symbol glyphs in primary navigation with text-based controls; larger brand clarity.
- Route animation redraw runs at approximately 24 FPS only while a map with actual routes is visible; the static map does not redraw with each plane animation.
- Clearer active navigation state; refined iPhone spacing and button sizing.

## Verification needed

Run Godot 4.5 headless export, browser WebAssembly startup and **actual iPhone Safari test**. Tablet/browser testing is not a substitute for iPhone performance validation. This is a performance candidate, not an App Store release.
