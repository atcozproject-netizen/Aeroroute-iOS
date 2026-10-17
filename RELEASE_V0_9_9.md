# Aeroroute V0.9.9: clean commercial simulation (no levels)
- Passenger level-up mechanics, goal progress bar and celebratory level UI removed.
- All aircraft models now available subject to route length, affordability and seats, not player XP.
- New commercial ICAO selection de-duplicates nearby minor airports (minimum region dependent spacing) but preserves every old canonical airport in the data model and saved routes.
- Close zoom uses transparent independent Natural Earth 1:10m rendered 20x20 degree high-resolution tiles (1280px per tile); only camera-visible tiles are loaded into a bounded cache.
- Original 4K overview remains for zoomed-out play, FIR and flight routes unchanged.
- Simulation remains light, playable by touch and on iPhone Safari.
