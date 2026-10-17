# Aeroroute Godot V0.8 — world map fixes

- Replaces unreliable Godot triangulation of 294 self-intersecting coastline rings with a pre-rasterized transparent vector-derived world texture.
- Draws only on-screen regions of the land texture, with wrapped copies for dateline navigation (at most three draw calls).
- Corrects the missing Eurasia/Arabian Peninsula/Africa landmass rendering, including OMDB/United Arab Emirates.
- Simplifies map setup, reducing per-game startup polygon preprocessing.
- Retains interactive ICAO airport pins, routes, aircraft layers, touch controls and AirCredits economy.
- Still needs on-device iPhone/Safari performance validation.

- Sets stretch aspect to expand to use the full variable iPhone Safari viewport without fixed-aspect black bars.
- Positions zoom controls below top status card to avoid UI collision.
