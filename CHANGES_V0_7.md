# Aeroroute Godot V0.7 — touch and map navigation fix

The user-provided iPhone video showed disproportionate map travel with a global zoom and difficult navigation. Fixes:

- Ignore synthesized mouse events after touch to prevent duplicate handling. Disable mouse emulation from touch in project.godot.
- Proper pinch lifecycle (first finger / second finger / lifting / cancel), calibrated pinch zoom and midpoint pan.
- Dampen and cap per-event pan travel; clamp latitude to useful world regions.
- Mobile portrait overview now continental instead of fitting entire world inside a narrow screen with excess ocean.
- More usable default HQ zoom.
- Explicit +, -, overview buttons for users who prefer one-finger controls.
- Map airport LOD and coastal LOD inherited from V0.6.

Verify on physical iPhone; headless compile is not a substitute for touch testing.
