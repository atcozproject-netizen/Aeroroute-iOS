# Aeroroute V0.9.5 – map input and FIR decluttering
- Normal finger swipes always pan, even if the swipe starts on an airport marker.
- Short tap opens airport info; hold an airport for 0.42 s then drag to open route planner.
- LINJE mode continues supporting two taps, and also enables deliberate direct dragging.
- Pinch cancels any pending long-press route creation, resets on Safari focus loss, and never generates a route.
- FIR is a three-state button (AV / FIR / FIR+); normal startup displays only thin desaturated borders.
- FIR+ shows at most 3 labels at medium zoom or 5 at high zoom, with collision avoidance.
- FIR boundaries continue using the 255 packaged global geometry features; non-authoritative game data.
