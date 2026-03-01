## SynergyManager — counts traits on board, determines active tiers, and emits bonuses.
## Other systems call get_all_bonuses() or get_bonus_value() to read the current state.
extends Node

# active_bonuses[player_id] = Dictionary of:
#   trait_id -> { count, tier, bonuses: {bonus_key: value} }
var active_bonuses: Dictionary = {}

# _prev_tiers[player_id][trait_id] = tier int from the last recalculate call.
# Used to detect tier-up events and emit synergy_tier_reached.
var _prev_tiers: Dictionary = {}

func _ready() -> void:
	pass

# ── Recalculate (call whenever board changes) ─────────────────────────────────

func recalculate(player_id: int) -> void:
	var ps := GameState.get_player(player_id)
	if ps == null:
		return

	var counts: Dictionary = {}   # trait_id -> count

	for coord in ps.board:
		var inst: Dictionary = ps.board[coord]
		var uid: String = inst.get("unit_id", "")
		if uid == "" or not DataLoader.units.has(uid):
			continue
		var udata: UnitData = DataLoader.units[uid]
		_inc(counts, udata.origin)
		_inc(counts, udata.unit_class)

	var bonuses: Dictionary = {}
	for trait_id in counts:
		if not DataLoader.traits.has(trait_id):
			continue
		var tdata: TraitData = DataLoader.traits[trait_id]
		var tier: int = tdata.get_tier_for_count(counts[trait_id])
		if tier > 0:
			bonuses[trait_id] = {
				"count": counts[trait_id],
				"tier": tier,
				"bonuses": tdata.get_bonuses_for_tier(tier)
			}

	# Detect tier increases and emit synergy_tier_reached for the advisor system.
	var prev: Dictionary = _prev_tiers.get(player_id, {})
	var new_tiers: Dictionary = {}
	for trait_id in bonuses:
		var tier: int = bonuses[trait_id]["tier"]
		new_tiers[trait_id] = tier
		if tier > prev.get(trait_id, 0):
			SignalBus.synergy_tier_reached.emit(player_id, trait_id, tier)
	_prev_tiers[player_id] = new_tiers

	active_bonuses[player_id] = bonuses
	SignalBus.synergies_updated.emit(player_id, bonuses)

func _inc(d: Dictionary, key: String) -> void:
	d[key] = d.get(key, 0) + 1

# ── Read bonuses ──────────────────────────────────────────────────────────────

## Returns the combined flat bonuses for a single unit on the board.
## Merges bonuses from both its origin and class.
func get_unit_bonuses(player_id: int, unit_id: String) -> Dictionary:
	if not DataLoader.units.has(unit_id):
		return {}
	var udata: UnitData = DataLoader.units[unit_id]
	var result: Dictionary = {}
	var player_bonuses: Dictionary = active_bonuses.get(player_id, {})
	for trait_id in [udata.origin, udata.unit_class]:
		if player_bonuses.has(trait_id):
			var trait_bonuses: Dictionary = player_bonuses[trait_id].get("bonuses", {})
			for key in trait_bonuses:
				if result.has(key):
					result[key] = result[key] + trait_bonuses[key]
				else:
					result[key] = trait_bonuses[key]
	return result

## Returns all merged bonus values for a player (combined across all active traits).
func get_all_bonuses(player_id: int) -> Dictionary:
	var result: Dictionary = {}
	var player_bonuses: Dictionary = active_bonuses.get(player_id, {})
	for trait_id in player_bonuses:
		var trait_bonuses: Dictionary = player_bonuses[trait_id].get("bonuses", {})
		for key in trait_bonuses:
			if result.has(key):
				result[key] = result[key] + trait_bonuses[key]
			else:
				result[key] = trait_bonuses[key]
	return result

## Returns a specific bonus value (or default if not active).
func get_bonus_value(player_id: int, bonus_key: String, default_value: Variant = 0) -> Variant:
	return get_all_bonuses(player_id).get(bonus_key, default_value)

## Returns a snapshot of active synergies for display in the UI.
## Returns Array of { trait_id, display_name, count, tier, max_tier }
func get_display_synergies(player_id: int) -> Array:
	var player_bonuses: Dictionary = active_bonuses.get(player_id, {})
	var result: Array = []
	for trait_id in player_bonuses:
		if not DataLoader.traits.has(trait_id):
			continue
		var tdata: TraitData = DataLoader.traits[trait_id]
		var entry: Dictionary = player_bonuses[trait_id]
		result.append({
			"trait_id": trait_id,
			"display_name": tdata.display_name,
			"count": entry["count"],
			"tier": entry["tier"],
			"max_tier": tdata.thresholds.size()
		})
	# Sort: origin first, then by count descending
	result.sort_custom(func(a, b):
		var ta: TraitData = DataLoader.traits[a["trait_id"]]
		var tb: TraitData = DataLoader.traits[b["trait_id"]]
		if ta.trait_type != tb.trait_type:
			return ta.trait_type < tb.trait_type  # "class" < "origin" alphabetically, flip if needed
		return b["count"] > a["count"]
	)
	return result
