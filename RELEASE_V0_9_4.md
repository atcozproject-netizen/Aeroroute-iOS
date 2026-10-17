# Aeroroute V0.9.4 – game map, route gestures and FIR visibility
- Direct drag any selectable airport marker to another to open route planner (no requirement to own the origin airport).
- Larger 32–33px touch targeting, dragging preview arc, and a dedicated LINJE touch-twice mode for accessibility.
- FIR boundaries are displayed by default; locally bundled 255 worldwide FIR geometries now have stronger purple borderlines, name/code cards, and on-screen status. FIR overlay remains optional and never captures input.
- Removed latitude/longitude coordinate grid; rebuilt the look as stylized airline-strategy cartography with dark sea gradient and subdued land tint.
- Tightened map touch capture around all five right-side buttons to prevent accidental drags.
- Actual aircraft and economy remain Godot-based; no HTML replacement.
- Caveat: global FIR data is third-party GIS game data, not an authoritative current AIS/AIP source.
