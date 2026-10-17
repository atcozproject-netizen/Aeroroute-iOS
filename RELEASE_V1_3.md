# Aeroroute V1.3 – Direct Routes and Stable Startup
- Replaced scrolling airport picker in startup with four large fixed buttons, selected-state visuals and persistent selected-airport label, solving the disappearing/blank labels seen in 17 Oct iPhone screen recording.
- Search matches ICAO, IATA, city/name and country with stable buttons; no nested scrolling in modal.
- Direct-route gesture after holding an airport marker for 0.26s then dragging to another: creates a route instantly, with an automatically selected aircraft; no airport menu, route picker, or extra confirmation.
- Quick swipes pan, touch holds only arm near a real marker (~19px), two-finger pinch remains safe. Attempted routes without capacity/cash show an error.
- Existing line taps still open plane list; airport taps open terminal upgrade + attached routes. New line menu removed from airport sheet.
- Original save format, fleet, economy, FIR, commercial airports and visual art intact.
