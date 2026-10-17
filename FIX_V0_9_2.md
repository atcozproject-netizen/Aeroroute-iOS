# Aeroroute V0.9.2 — iOS input hotfix

Enable `input_devices/pointing/emulate_mouse_from_touch=true` for native Godot Control widgets on mobile browsers. Map touch gesture handling still suppresses duplicate synthetic mouse events after touch via `touch_input_seen`. Regression test checks the start menu, search field, airport selection, and begin button.
