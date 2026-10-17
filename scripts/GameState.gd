extends RefCounted
## Aeroroute: deterministic economy/progression architecture with stochastic demand and timed flights.

signal changed
signal landed(route_id: String, passenger_count: int, net: float)
signal news(title: String, detail: String)

const SAVE_FILE = "user://aeroroute_native_v1.json"
const LEVEL_REQUIREMENTS = [0, 160, 950, 4000, 16000, 48000, 130000, 300000]

var airports: Array = []
var airports_by_code: Dictionary = {}
var featured_codes: Dictionary = {}
var catalog: Array = []
var catalog_by_id: Dictionary = {}
var land: Array = []
var company_name: String = "Northstar Airways"
var home: String = "ESSA"
var initialized: bool = false
var cash: float = 650.0
var routes: Array = []
var owned: Dictionary = {}
var terminals: Dictionary = {}
var total_passengers: int = 0
var total_flights: int = 0
var last_profit: float = 0.0
var elapsed: float = 0.0
var day: int = 1
var speed: float = 1.0
var paused: bool = false
var route_events: Array = []
var marketing: int = 0
var service: int = 0
var staffing: int = 0
var autosave_accum: float = 0.0
var ui_accum: float = 0.0

func _init() -> void:
	var airport_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/airports.json"))
	var plane_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/aircraft.json"))
	var land_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/land.json"))
	if airport_data is Array:
		airports = airport_data
	var extra_data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/airports_extra.json"))
	if extra_data is Array:
		var seen_iata: Dictionary = {}
		for item in airports:
			if str(item.get("iata", "")) != "":
				seen_iata[str(item["iata"])] = true
		var seen_icao: Dictionary = {}
		for item in airports:
			seen_icao[str(item["icao"])] = true
		for item in extra_data:
			if not (item is Dictionary) or not item.has("icao"):
				continue
			var code: String = str(item["icao"])
			var alias: String = str(item.get("iata", ""))
			if seen_icao.has(code) or (alias != "" and seen_iata.has(alias)):
				continue
			seen_icao[code] = true
			if alias != "":
				seen_iata[alias] = true
			airports.append(item)
	for a in airports:
		airports_by_code[str(a["icao"])] = a
	var featured_data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/airports_featured.json"))
	if featured_data is Array:
		for code in featured_data:
			if airports_by_code.has(str(code)):
				featured_codes[str(code)] = true
	if featured_codes.is_empty():
		push_warning("No curated airport data found. Falling back to canonical world data.")
		for a in airports:
			featured_codes[str(a["icao"])] = true
	if plane_data is Array:
		catalog = plane_data
	for p in catalog:
		catalog_by_id[str(p["id"])] = p
	if land_data is Array:
		land = land_data

func is_featured(icao: String) -> bool:
	return featured_codes.has(icao) or owned.has(icao) or icao == home and initialized

func can_start_at(icao: String) -> bool:
	if not airports_by_code.has(icao) or not featured_codes.has(icao):
		return false
	for other in airports:
		var code: String = str(other["icao"])
		if featured_codes.has(code) and code != icao and kilometers(icao, code) <= 1100.0:
			return true
	return false

func begin(icao: String) -> void:
	if not can_start_at(icao):
		return
	home = icao
	company_name = "Northstar Airways"
	initialized = true
	cash = 650.0
	routes = []
	owned = {icao: true}
	terminals = {icao: 1}
	total_passengers = 0
	total_flights = 0
	last_profit = 0.0
	elapsed = 0.0
	day = 1
	speed = 1.0
	paused = false
	route_events = []
	marketing = 0
	service = 0
	staffing = 0
	save_game()
	changed.emit()

func level() -> int:
	# Legacy compatibility: there is no player level progression anymore.
	return 8

func next_level_requirement() -> int:
	return -1

func airport(code: String) -> Dictionary:
	return airports_by_code.get(code, {})

func kilometers(a_code: String, b_code: String) -> float:
	var a: Dictionary = airport(a_code)
	var b: Dictionary = airport(b_code)
	if a.is_empty() or b.is_empty():
		return 0.0
	var rad: float = PI / 180.0
	var d_lat: float = (float(b["lat"]) - float(a["lat"])) * rad
	var d_lon: float = (float(b["lon"]) - float(a["lon"])) * rad
	var k: float = pow(sin(d_lat / 2.0), 2.0) + cos(float(a["lat"]) * rad) * cos(float(b["lat"]) * rad) * pow(sin(d_lon / 2.0), 2.0)
	return 12742.0 * asin(sqrt(clampf(k, 0.0, 1.0)))

func distance_label(a_code: String, b_code: String) -> String:
	var km: float = kilometers(a_code, b_code)
	return "%d NM  ·  %d km" % [roundi(km / 1.852), roundi(km)]

func airport_market_class(code: String) -> String:
	var a: Dictionary = airport(code)
	if a.is_empty():
		return "Okänd marknad"
	var rank: int = int(a["rank"])
	if rank >= 7:
		return "Globalt nav"
	if rank >= 5:
		return "Stark internationell"
	if rank >= 3:
		return "Regional"
	return "Mindre marknad"

func demand_market(a_code: String, b_code: String) -> Dictionary:
	var a: Dictionary = airport(a_code)
	var b: Dictionary = airport(b_code)
	var km: float = kilometers(a_code, b_code)
	if a.is_empty() or b.is_empty():
		return {"base": 0.0, "label": "Okänd"}
	var same: bool = str(a["country"]) == str(b["country"])
	var factor: float = 0.34
	if km < 80.0:
		factor = 0.012 if same else 0.045
	elif km < 160.0:
		factor = 0.055 if same else 0.14
	elif km < 300.0:
		factor = 0.15 if same else 0.35
	elif km < 600.0:
		factor = 0.46 if same else 0.75
	elif km < 1100.0:
		factor = 1.0
	elif km < 2500.0:
		factor = 1.13
	elif km < 6000.0:
		factor = 0.83
	elif km < 10000.0:
		factor = 0.58
	var base: float = maxf(0.35, pow(float(a["rank"]) * float(b["rank"]), 0.89) * 18.0 * factor)
	var label_text: String = "Mycket hög"
	if base < 16.0:
		label_text = "Låg"
	elif base < 85.0:
		label_text = "Måttlig"
	elif base < 240.0:
		label_text = "Hög"
	return {"base": base, "label": label_text}

func initial_plane(a_code: String, b_code: String) -> Dictionary:
	var km: float = kilometers(a_code, b_code)
	for p in catalog:
		if float(p["range"]) >= km:
			return p
	return {}

func minimum_plane(a_code: String, b_code: String) -> Dictionary:
	var km: float = kilometers(a_code, b_code)
	for p in catalog:
		if float(p["range"]) >= km:
			return p
	return {}

func recommended_destinations(from_code: String, limit: int = 4) -> Array:
	# Offers actual reachable airport markets, not arbitrary generic upgrades.
	if not airports_by_code.has(from_code):
		return []
	var proposals: Array = []
	for other in airports:
		var code: String = str(other["icao"])
		if not is_featured(code) or code == from_code or not get_route(route_key(from_code, code)).is_empty():
			continue
		var km: float = kilometers(from_code, code)
		if km < 80.0 or km > 1100.0 or initial_plane(from_code, code).is_empty():
			continue
		if not gates_available(from_code) or not gates_available(code):
			continue
		var cost: float = route_cost(from_code, code)
		if cost <= 0.0:
			continue
		var market: Dictionary = demand_market(from_code, code)
		# Favor demand, affordable openings and manageable short-haul distances.
		var score: float = float(market["base"]) * 0.38 + float(other["rank"]) * 11.0 - cost * 0.19 - km * 0.011
		if cost > cash:
			score -= 30.0
		proposals.append({"code":code,"km":km,"cost":cost,"demand":market["label"],"score":score})
	proposals.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return float(a["score"]) > float(b["score"]))
	return proposals.slice(0, mini(limit, proposals.size()))

func gates_used(icao: String) -> int:
	var count: int = 0
	for r in routes:
		if str(r["from"]) == icao or str(r["to"]) == icao:
			count += 1
	return count

func gates_available(icao: String) -> bool:
	return gates_used(icao) < (2 + int(terminals.get(icao, 1)) * 2)

func infrastructure_fee(a_code: String, b_code: String) -> float:
	var opening_a: float = 0.0 if owned.has(a_code) else 22.0 + float(airport(a_code)["rank"]) * 28.0
	var opening_b: float = 0.0 if owned.has(b_code) else 22.0 + float(airport(b_code)["rank"]) * 28.0
	return roundf((20.0 + kilometers(a_code, b_code) * 0.018 + opening_a + opening_b) * 10.0) / 10.0

func route_cost(a_code: String, b_code: String) -> float:
	var p: Dictionary = initial_plane(a_code, b_code)
	if p.is_empty():
		return -1.0
	return infrastructure_fee(a_code, b_code) + float(p["price"])

func route_key(a_code: String, b_code: String) -> String:
	var both: Array = [a_code, b_code]
	both.sort()
	return "%s-%s" % [both[0], both[1]]

func get_route(route_id: String) -> Dictionary:
	for r in routes:
		if str(r["id"]) == route_id:
			return r
	return {}

func create_route(a_code: String, b_code: String) -> String:
	if a_code == b_code or not airports_by_code.has(a_code) or not airports_by_code.has(b_code):
		return "Ogiltig flygplats"
	if not get_route(route_key(a_code, b_code)).is_empty():
		return "Linjen finns redan"
	var plane: Dictionary = initial_plane(a_code, b_code)
	if plane.is_empty():
		return "Ingen flygplansmodell har tillräcklig räckvidd"
	if not gates_available(a_code) or not gates_available(b_code):
		return "Uppgradera terminalkapaciteten först"
	var fee: float = route_cost(a_code, b_code)
	if cash < fee:
		return "Otillräckligt med AirCredits"
	cash = rounded(cash - fee)
	var km: float = kilometers(a_code, b_code)
	routes.append({"id": route_key(a_code, b_code), "from": a_code, "to": b_code,
		"plane": str(plane["id"]), "fare": rounded(0.85 + km * 0.00028),
		"progress": 0.0, "direction": 0, "flights": 0, "total_net": 0.0,
		"total_pax": 0, "last_net": 0.0, "last_pax": 0})
	owned[a_code] = true
	owned[b_code] = true
	if not terminals.has(a_code):
		terminals[a_code] = 1
	if not terminals.has(b_code):
		terminals[b_code] = 1
	save_game()
	changed.emit()
	return ""

func flight_duration(r: Dictionary) -> float:
	var p: Dictionary = catalog_by_id.get(str(r.get("plane", "")), {})
	if p.is_empty():
		return 60.0
	return clampf(17.0 + kilometers(str(r["from"]), str(r["to"])) / float(p["speed"]) * 3.7, 18.0, 60.0)

func projected(r: Dictionary) -> Dictionary:
	var a_code: String = str(r["from"])
	var b_code: String = str(r["to"])
	var dist: float = kilometers(a_code, b_code)
	var market: Dictionary = demand_market(a_code, b_code)
	var p: Dictionary = catalog_by_id.get(str(r["plane"]), {})
	if p.is_empty():
		return {}
	var hubs: int = gates_used(a_code) + gates_used(b_code)
	var hub_bonus: float = 1.0 + minf(0.7, maxf(0.0, float(hubs - 2)) * 0.065)
	var base_fare: float = maxf(0.1, rounded(0.85 + dist * 0.00028))
	var price_factor: float = clampf(1.62 - (float(r["fare"]) / base_fare) * 0.62, 0.22, 1.38)
	var bonus: float = 1.0
	for e in route_events:
		if int(e.get("ends", 0)) > day and (str(e.get("airport", "")) == a_code or str(e.get("airport", "")) == b_code):
			bonus *= float(e.get("multiplier", 1.0))
	var demand: float = float(market["base"]) / 9.5 * hub_bonus * (1.0 + marketing * 0.075) * (1.0 + service * 0.035) * price_factor * bonus
	var seats: int = int(p["seats"])
	var pax: float = minf(float(seats), maxf(0.0, demand))
	var revenue: float = rounded(pax * float(r["fare"]))
	var cost: float = rounded(2.0 + int(p["level"]) * 1.4 + seats * 0.055 + dist * 0.0018 * (1.0 + int(p["level"]) * 0.2) + marketing * 0.10 + service * 0.07 + staffing * 0.05)
	return {"demand": demand, "pax": pax, "seats": seats, "revenue": revenue,
		"cost": cost, "net": rounded(revenue - cost), "load": roundi(100.0 * pax / maxf(1.0, float(seats))), "bonus": bonus,
		"label": str(market["label"]), "distance": dist}

func network_snapshot() -> Dictionary:
	# Informational network analytics; no XP requirements or hard objectives.
	var net_per_rotation: float = 0.0
	var full_flights: int = 0
	var risk_count: int = 0
	var average_load: float = 0.0
	var next_landing_sec: float = 999999.0
	var next_landing_code: String = ""
	var best_route_id: String = ""
	var weakest_route_id: String = ""
	var strongest: float = -999999.0
	var weakest: float = 999999.0
	for r in routes:
		var projection: Dictionary = projected(r)
		if projection.is_empty():
			continue
		var profit: float = float(projection["net"])
		net_per_rotation += profit
		average_load += float(projection["load"])
		if profit < 0.0:
			risk_count += 1
		if profit > strongest:
			strongest = profit
			best_route_id = str(r["id"])
		if profit < weakest:
			weakest = profit
			weakest_route_id = str(r["id"])
		var remaining: float = (1.0 - float(r.get("progress", 0.0))) * flight_duration(r) / maxf(0.5, speed)
		if remaining < next_landing_sec:
			next_landing_sec = remaining
			next_landing_code = str(r["to"]) if int(r.get("direction", 0)) == 0 else str(r["from"])
		full_flights += 1
	if full_flights > 0:
		average_load /= float(full_flights)
	return {"routes":full_flights,"net":rounded(net_per_rotation),
		"loss_routes":risk_count,"load":roundi(average_load),
		"next_seconds":ceili(next_landing_sec) if full_flights > 0 else -1,
		"next_airport":next_landing_code,"best_id":best_route_id,"risk_id":weakest_route_id}

func available_upgrades(r: Dictionary) -> Array:
	var current: Dictionary = catalog_by_id.get(str(r["plane"]), {})
	if current.is_empty():
		return []
	var result: Array = []
	var dist: float = kilometers(str(r["from"]), str(r["to"]))
	for p in catalog:
		if int(p["level"]) > int(current["level"]) and int(p["seats"]) > int(current["seats"]) and float(p["range"]) >= dist:
			result.append(p)
	return result

func upgrade_plane(route_id: String, model_id: String) -> String:
	var r: Dictionary = get_route(route_id)
	var new_plane: Dictionary = catalog_by_id.get(model_id, {})
	if r.is_empty() or new_plane.is_empty():
		return "Okänd linje eller flygplansmodell"
	var current: Dictionary = catalog_by_id.get(str(r["plane"]), {})
	if int(new_plane["level"]) <= int(current["level"]) or float(new_plane["range"]) < kilometers(str(r["from"]), str(r["to"])):
		return "Modellen är inte tillgänglig"
	var cost: float = maxf(0.0, rounded(float(new_plane["price"]) - float(current["price"]) * 0.55))
	if cash < cost:
		return "Otillräckligt med AirCredits"
	cash = rounded(cash - cost)
	r["plane"] = model_id
	r["progress"] = 0.0
	save_game()
	changed.emit()
	return ""

func upgrade_terminal(icao: String) -> String:
	if not owned.has(icao):
		return "Flygplatsen är inte ansluten"
	var level_here: int = int(terminals.get(icao, 1))
	if level_here >= 5:
		return "Terminalen är på maxnivå"
	var cost: float = rounded((45.0 + float(airport(icao)["rank"]) * 17.5) * level_here)
	if cash < cost:
		return "Otillräckligt med AirCredits"
	cash = rounded(cash - cost)
	terminals[icao] = level_here + 1
	save_game()
	changed.emit()
	return ""

func close_route(route_id: String) -> void:
	var r: Dictionary = get_route(route_id)
	if r.is_empty():
		return
	var p: Dictionary = catalog_by_id.get(str(r["plane"]), {})
	cash = rounded(cash + float(p.get("price", 0.0)) * 0.45 + infrastructure_fee(str(r["from"]), str(r["to"])) * 0.2)
	routes.erase(r)
	save_game()
	changed.emit()

func advance(delta: float) -> void:
	if not initialized or paused:
		return
	var dt: float = minf(delta, 0.3) * speed
	elapsed += dt
	var next_day: int = 1 + int(floor(elapsed / 120.0))
	if next_day > day:
		day = next_day
		var remaining_events: Array = []
		for e in route_events:
			if int(e["ends"]) > day:
				remaining_events.append(e)
		route_events = remaining_events
		if day % 4 == 0 and routes.size() > 0 and randf() < 0.55:
			new_event()
		changed.emit()
	for r in routes:
		r["progress"] = float(r.get("progress", 0.0)) + dt / flight_duration(r)
		if float(r["progress"]) >= 1.0:
			r["progress"] = fmod(float(r["progress"]), 1.0)
			r["direction"] = 1 - int(r.get("direction", 0))
			complete_flight(r)
	autosave_accum += dt
	if autosave_accum > 10.0:
		autosave_accum = 0.0
		save_game()

func complete_flight(r: Dictionary) -> void:
	var estimate: Dictionary = projected(r)
	if estimate.is_empty():
		return
	var exp_pax: float = clampf(float(estimate["demand"]) * randf_range(0.82, 1.18), 0.0, float(estimate["seats"]))
	var pax: int = mini(int(floor(exp_pax)) + (1 if randf() < exp_pax - floor(exp_pax) else 0), int(estimate["seats"]))
	var revenue: float = rounded(pax * float(r["fare"]))
	var net: float = rounded(revenue - float(estimate["cost"]))
	cash = rounded(cash + net)
	total_passengers += pax
	total_flights += 1
	last_profit = net
	r["flights"] = int(r["flights"]) + 1
	r["total_pax"] = int(r["total_pax"]) + pax
	r["total_net"] = rounded(float(r["total_net"]) + net)
	r["last_net"] = net
	r["last_pax"] = pax
	landed.emit(str(r["id"]), pax, net)
	changed.emit()
	save_game()

func new_event() -> void:
	var airports_in_network: Array = []
	for r in routes:
		if not airports_in_network.has(r["from"]):
			airports_in_network.append(r["from"])
		if not airports_in_network.has(r["to"]):
			airports_in_network.append(r["to"])
	if airports_in_network.is_empty():
		return
	var dest: String = str(airports_in_network.pick_random())
	var possibilities: Array = [
		{"title": "Musikfestival", "multiplier": 2.1, "days": 3},
		{"title": "Sportevenemang", "multiplier": 2.5, "days": 2},
		{"title": "Semesterboom", "multiplier": 1.8, "days": 4},
		{"title": "Internationell mässa", "multiplier": 1.7, "days": 2}
	]
	var event: Dictionary = possibilities.pick_random()
	route_events.append({"airport": dest, "title": event["title"], "ends": day + int(event["days"]), "multiplier": event["multiplier"]})
	news.emit(str(event["title"]), "%s: efterfrågan stiger under %d speldagar." % [dest, int(event["days"])])
	save_game()

func save_game() -> void:
	if not initialized:
		return
	var data: Dictionary = {"version": 1, "company_name": company_name, "home": home, "cash": cash,
		"routes": routes, "owned": owned.keys(), "terminals": terminals, "total_passengers": total_passengers,
		"total_flights": total_flights, "last_profit": last_profit, "elapsed": elapsed, "day": day,
		"speed": speed, "paused": paused, "route_events": route_events,
		"marketing": marketing, "service": service, "staffing": staffing}
	var file: FileAccess = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_FILE):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_FILE))
	if not (data is Dictionary) or int(data.get("version", 0)) != 1 or not airports_by_code.has(str(data.get("home", ""))):
		return false
	company_name = str(data.get("company_name", "Northstar Airways"))
	home = str(data["home"])
	cash = float(data.get("cash", 650.0))
	routes = data.get("routes", [])
	owned = {}
	for code in data.get("owned", []):
		if airports_by_code.has(str(code)):
			owned[str(code)] = true
	terminals = data.get("terminals", {})
	total_passengers = int(data.get("total_passengers", 0))
	total_flights = int(data.get("total_flights", 0))
	last_profit = float(data.get("last_profit", 0.0))
	elapsed = float(data.get("elapsed", 0.0))
	day = int(data.get("day", 1))
	speed = float(data.get("speed", 1.0))
	paused = bool(data.get("paused", false))
	route_events = data.get("route_events", [])
	marketing = int(data.get("marketing", 0))
	service = int(data.get("service", 0))
	staffing = int(data.get("staffing", 0))
	initialized = true
	changed.emit()
	return true

func money(value: float) -> String:
	var prefix: String = "−" if value < 0.0 else ""
	var abs_value: float = absf(value)
	if abs_value >= 1000000.0:
		return "%s%.2fm AC" % [prefix, abs_value / 1000000.0]
	if abs_value >= 10000.0:
		return "%s%.1fk AC" % [prefix, abs_value / 1000.0]
	if abs_value >= 100.0:
		return "%s%.0f AC" % [prefix, abs_value]
	return "%s%.1f AC" % [prefix, abs_value]

func rounded(n: float) -> float:
	return roundf(n * 100.0) / 100.0
