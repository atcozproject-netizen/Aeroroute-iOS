"""V0.9.1 static safety checks; Godot compilation and iPhone testing are separate."""
from pathlib import Path
p=Path(__file__).resolve().parents[1]
world=(p/'scripts/WorldMap.gd').read_text()
main=(p/'scripts/Main.gd').read_text()
fir=(p/'scripts/FirLayer.gd').read_text()
checks={
 'Touch captured at viewport level':'func _input(event: InputEvent)' in world and 'gesture_captured' in world,
 'Release before opening modal':world.index('pointers.erase(event.index)') < world.index('handle_release(event.position)'),
 'Reset on app focus loss':'NOTIFICATION_APPLICATION_FOCUS_OUT' in world,
 'Touch stale-event watchdog':'last_touch_event_ms > 8500' in world,
 'Multi-touch cannot start from UI':'pointers.size() > 0 and not _can_capture_touch(event.position)' in world,
 'Mouse events not emulated':'pointing/emulate_mouse_from_touch=false' in (p/'project.godot').read_text(),
 'FIR layer passes touches':'MOUSE_FILTER_IGNORE' in main and 'fir_layer' in main,
 'FIR layer toggle':'set_fir_visible(active)' in main,
 'FIR data bundled':'data/fir_regions.json' in fir,
 'FIR error feedback':'fir_load_failed.emit' in fir,
 'World texture included':(p/'data/world_land.png').is_file(),
 'ICAO airport data included':(p/'data/airports.json').stat().st_size>20000,
}
for title,ok in checks.items():print(('PASS' if ok else 'FAIL'),title)
assert all(checks.values()),'Regression validation failed'
