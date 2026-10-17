# Aeroroute V1.4 – Full-map responsive simulation, route quote and no day HUD
- Route pricing now appears DURING long-press direct-route dragging: green if affordable, red if unaffordable or blocked, including exact opening fee, wallet, and capacity/range explanation. The preview only updates when the hovered airport changes.
- A selected destination 64px near the fingertip previews its price; the final release uses a precise 30px target.
- GameState.route_quote is side-effect-free and is the same validation path used by create_route; cost and actual charge cannot drift apart.
- The visible DAG counter is removed. Internal elapsed/day continues to control temporary market events, not XP progression.
- The entire HUD now reflows: portrait has floating map controls and bottom traffic/tempo dock; landscape moves the traffic dock to the upper-right and nav to the lower-left, with a compact right-side sheet.
- Input hitboxes follow real UI rectangles, avoiding non-interactive invisible horizontal bands that previously constrained the map.
- Portrait + landscape sensor enabled for native iOS, and browser CSS viewport adapts to Safari device rotation (subject to iOS orientation lock).
- Underlying Godot rendering, touch/pinch, FIR, 1350 commercial airports, route save data and plane logic unchanged.
