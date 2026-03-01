## DataLoader — loads all JSON data files at startup and converts them into typed Resources.
## After _ready(), all data is read-only. Systems must never modify these Resources.
## To rebalance: edit JSON files and restart (or call reload() in editor).
extends Node

var units: Dictionary = {}      # unit_id (String) -> UnitData
var traits: Dictionary = {}     # trait_id (String) -> TraitData
var items: Dictionary = {}      # item_id (String) -> ItemData
var rounds: Array = []          # Array[RoundConfig], indexed by round_number - 1
var shop_odds: Dictionary = {}  # level (String "1"-"9") -> Array[float] of 5 cost-tier weights
var economy: Dictionary = {}    # flat config values (base_income, pool_sizes, etc.)

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	var raw_units  := _read_json_array("res://data/units.json")
	var raw_traits := _read_json_dict("res://data/traits.json")
	var raw_items  := _read_json_dict("res://data/items.json")
	var raw_rounds := _read_json_array("res://data/rounds.json")
	shop_odds       = _read_json_dict("res://data/shop_odds.json")
	economy         = _read_json_dict("res://data/economy.json")

	units  = _parse_units(raw_units)
	traits = _parse_traits(raw_traits)
	items  = _parse_items(raw_items)
	rounds = _parse_rounds(raw_rounds)

	print("[DataLoader] Loaded %d units, %d traits, %d items, %d rounds." % [
		units.size(), traits.size(), items.size(), rounds.size()])

# --- Helpers ---

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("[DataLoader] File not found: %s" % path)
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var result: Variant = JSON.parse_string(text)
	if result == null:
		push_error("[DataLoader] Failed to parse JSON: %s" % path)
	return result

func _read_json_array(path: String) -> Array:
	var raw: Variant = _read_json(path)
	if raw is Array:
		return raw as Array
	push_error("[DataLoader] Expected JSON array in: %s" % path)
	return []

func _read_json_dict(path: String) -> Dictionary:
	var raw: Variant = _read_json(path)
	if raw is Dictionary:
		return raw as Dictionary
	push_error("[DataLoader] Expected JSON object in: %s" % path)
	return {}

func _parse_units(raw: Array) -> Dictionary:
	var result := {}
	for entry in raw:
		var u := UnitData.new()
		u.id                  = entry["id"]
		u.display_name        = entry["name"]
		u.origin              = entry["origin"]
		u.unit_class          = entry["class"]
		u.cost                = entry["cost"]
		u.base_hp             = float(entry["stats"]["hp"])
		u.base_atk            = float(entry["stats"]["atk"])
		u.base_armor          = float(entry["stats"]["armor"])
		u.base_mr             = float(entry["stats"]["mr"])
		u.atk_speed           = float(entry["stats"]["atk_speed"])
		u.atk_range           = int(entry["stats"]["atk_range"])
		u.star2_multiplier    = float(entry.get("star2_multiplier", 1.8))
		u.star3_multiplier    = float(entry.get("star3_multiplier", 3.24))
		u.sprite_path         = entry.get("sprite", "")
		var ab: Dictionary = entry.get("ability", {})
		if not ab.is_empty():
			u.ability_id          = ab.get("id", "")
			u.ability_name        = ab.get("name", "")
			u.ability_description = ab.get("description", "")
			u.ability_mana_cost   = int(ab.get("mana_cost", 60))
			u.ability_values      = ab.get("values", [])
		result[u.id] = u
	return result

func _parse_traits(raw: Dictionary) -> Dictionary:
	var result := {}
	var all_trait_arrays: Array = []
	if raw.has("origins"):
		all_trait_arrays.append_array(raw["origins"])
	if raw.has("classes"):
		all_trait_arrays.append_array(raw["classes"])
	for entry in all_trait_arrays:
		var t := TraitData.new()
		t.id           = entry["id"]
		t.display_name = entry["display_name"]
		t.trait_type   = entry.get("type", "origin")
		t.description  = entry.get("description", "")
		t.thresholds   = Array(entry.get("thresholds", []), TYPE_INT, "", null)
		t.tiers        = entry.get("tiers", [])
		result[t.id]   = t
	return result

func _parse_items(raw: Dictionary) -> Dictionary:
	var result := {}
	var all_items: Array = []
	if raw.has("components"):
		all_items.append_array(raw["components"])
	if raw.has("combined"):
		all_items.append_array(raw["combined"])
	for entry in all_items:
		var it := ItemData.new()
		it.id           = entry["id"]
		it.display_name = entry["name"]
		it.description  = entry.get("description", "")
		it.is_component = entry.get("is_component", true)
		it.component_ids = entry.get("components", [])
		var stats: Dictionary = entry.get("stats", {})
		it.hp_bonus            = float(stats.get("hp_bonus", 0))
		it.atk_bonus           = float(stats.get("atk_bonus", 0))
		it.armor_bonus         = float(stats.get("armor_bonus", 0))
		it.mr_bonus            = float(stats.get("mr_bonus", 0))
		it.atk_speed_bonus     = float(stats.get("atk_speed_pct_bonus", 0)) / 100.0
		it.mana_bonus          = int(stats.get("mana_bonus", 0))
		it.effect_id           = entry.get("effect_id", "")
		it.effect_value        = float(entry.get("effect_value", 0.0))
		it.sprite_path         = entry.get("sprite", "")
		result[it.id] = it
	return result

func _parse_rounds(raw: Array) -> Array:
	var result := []
	for entry in raw:
		var r := RoundConfig.new()
		r.round_number   = int(entry["round"])
		r.round_type     = entry.get("type", "pvp")
		r.display_label  = entry.get("display_label", "Round %d" % r.round_number)
		r.pve_enemies    = entry.get("enemies", [])
		r.carousel_units = entry.get("carousel_units", [])
		r.base_damage                = int(entry.get("base_damage", 2))
		r.damage_per_surviving_unit  = int(entry.get("damage_per_surviving_unit", 1))
		result.append(r)
	return result

# --- Utility ---

func get_units_by_cost(cost: int) -> Array:
	var result := []
	for uid in units:
		if units[uid].cost == cost:
			result.append(uid)
	return result

func get_round(round_number: int) -> RoundConfig:
	var idx := round_number - 1
	if idx < 0 or idx >= rounds.size():
		return null
	return rounds[idx]
