# Aeroroute — Airline Empire (iPhone / Godot 4)

A 2D, map-first airline management game. The **actual game runs in Godot 4.5.1**; GitHub Actions compiles a single-threaded Web build for **iPhone Safari**.

**Play the latest successful build:** https://atcozproject-netizen.github.io/Aeroroute-iOS/

## Gameplay

- Start a new airline from a commercial airport, search real ICAO/IATA airports, and explore a styled world map.
- Draw new flight routes by touching airports. Opening costs break down aircraft purchase, route setup, and first-time airport access.
- Watch aircraft move between cities, follow active flights, view live profits and adjust game speed.
- Manage terminals, choose aircraft by range, and monitor network profitability and passenger demand.
- Adjust route fares: **revenue, operating costs, passenger load and forecast net profit refresh immediately**.
- Use the optional market-based suggested ticket price. It is a forecast, not guaranteed profit.
- The aircraft selection screen compares forecast net per flight and passenger load across available models.
- Optional FIR boundaries; touch-safe layouts for portrait and true landscape on iPhone.
- Browser-local autosave, no mandatory levels and no visible day counter.

## Build and quality checks

Commits affecting game source trigger the CI workflow at `.github/workflows/godot-web.yml`. It validates data, generates map assets, compiles the actual Godot game, runs headless GUI tests (`tests/gui_interaction_smoke.gd`) and publishes to GitHub Pages **only when checks succeed**. A source commit alone does not prove the Pages update has finished.

The latest changes add a non-mutating fare optimizer, live fare previews and profitability comparisons between aircraft, with regression assertions.

To work locally, open `project.godot` in Godot 4.5.1. Main scene: `scenes/Main.tscn`. Simulation: `scripts/GameState.gd`; UI: `scripts/Main.gd`; camera: `scripts/WorldMap.gd`.
