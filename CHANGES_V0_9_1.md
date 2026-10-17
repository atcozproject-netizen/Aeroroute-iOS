# Aeroroute Godot V0.9.1
- Touch captured at viewport level; gestures reset after lost focus, skipped release, and on modal/section switch.
- FIR toggle overlays boundaries from 255 actual FIR geometries. Data is generated at build from T&E/OpenAviation TopoJSON and bundled locally in the PCK, with HTTP fallback.
- Non-authoritative FIR data: game illustration only, not an official AIS publication.
- Godot Web (single thread) deploys automatically from GitHub Actions to iPhone Safari through GitHub Pages.
