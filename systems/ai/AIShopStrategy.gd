## AIShopStrategy — scores each shop slot and decides whether to buy or reroll.
class_name AIShopStrategy
extends RefCounted

var _player_id: int
var _target_comp: Array = []   # Array[String] trait_ids

func _init(player_id: int) -> void:
	_player_id = player_id

func set_target_comp(comp: Array) -> void:
	_target_comp = comp

## Returns true if the AI should buy this unit
func wants_unit(unit_id: String) -> bool:
	if not DataLoader.units.has(unit_id):
		return false
	var udata: UnitData = DataLoader.units[unit_id]

	# Always buy if it completes a 3-copy merge
	var copies := GameState.count_unit_copies(_player_id, unit_id)
	if copies == 2:  # buying the 3rd completes a star upgrade
		return true

	# Buy if the unit fits the target comp
	if udata.origin in _target_comp or udata.unit_class in _target_comp:
		return true

	# Opportunistically buy cheap units that pair with what we have
	if udata.cost == 1 and copies == 1:
		return true

	return false

## Returns true if the AI should spend gold rerolling this round
func should_reroll() -> bool:
	var ps := GameState.get_player(_player_id)
	if ps == null:
		return false

	# Reroll if we have 2-of-something and need the 3rd copy
	for uid in DataLoader.units:
		if GameState.count_unit_copies(_player_id, uid) == 2:
			return true

	# Reroll if very few shop slots match our comp
	var matching := 0
	for slot_id in ps.shop_slots:
		if slot_id == "" or slot_id.begins_with("LOCKED:"):
			continue
		if wants_unit(slot_id):
			matching += 1
	return matching == 0
