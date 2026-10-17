# Aeroroute V0.9.7 – closer zoom and local airports
- Maximum map zoom is 64 instead of 16. iPhone map zoom buttons move at 1.27x per tap, pinch gesture remains 12% clamped per event for stability.
- Airport size is revealed progressively: large hubs first, regional airports next, local rank-1 airports at zoom 18+.
- At zoom 17+ ICAO and any IATA alias appear; at zoom 30+ markers can show ICAO and airport name.
- More aggressive geographic culling before projections, and tighter collision spacing at close zoom, avoids rendering all 2661 airports every frame.
- Airports opened via search/home remain highlighted even when their rank would normally be hidden at the current zoom.
- Existing iPhone touch safety, FIR display modes, route gameplay and saves preserved.
