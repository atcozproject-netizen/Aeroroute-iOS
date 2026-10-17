# Aeroroute V1.0 – living airline network
Research references: Fly Corp network management; Mini Metro visual clarity; Pocket Planes market events; Godot CanvasItem deferred redraw and GPU batching.
- Player's actual next arrival is shown in the top brand strip, updated twice per second, without additional screen space.
- Map routes are financially color-coded according to REAL projected net: green profit, coral loss, amber near break-even.
- Newly opened routes receive an approximately 0.9-second growing-arc reveal.
- A new operating snapshot in LINJER shows forecast profit per full network cycle, projected load, unprofitable routes, and next landing.
- Route discovery radar suggests concrete reachable destinations from the player's headquarters.
- Fixed existing economics error: earlier forecast calculated passenger count from demand*10, while actual landed flights used demand. Both now use the same demand scale.
- All actions are optional. No XP, no forced leveling or auto-trading; unchanged save structure.
