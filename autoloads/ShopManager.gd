## ShopManager — manages the shared unit pool and generates shops for all players.
## Pool logic mirrors TFT: each unit has a fixed total copy count shared by all players.
extends Node

const SHOP_SIZE := 5

func _ready() -> void:
	pass  # Pool is initialized by GameState.init_game()

# ── Shop refresh ──────────────────────────────────────────────────────────────

func refresh_shops_for_all() -> void:
	for ps in GameState.alive_players():
		refresh_shop(ps.player_id, false)  # don't return old units for first shop

func refresh_shop(player_id: int, return_old: bool = true) -> void:
	var ps := GameState.get_player(player_id)
	if ps == null:
		return

	# Return existing non-empty, non-locked slots back to pool
	if return_old:
		for slot_id in ps.shop_slots:
			if slot_id != "" and not slot_id.begins_with("LOCKED:"):
				_return_to_pool(slot_id)

	ps.shop_slots = _roll_shop(ps.level)
	SignalBus.shop_refreshed.emit(player_id)

# ── Buy / Sell / Reroll ───────────────────────────────────────────────────────

func buy_unit(player_id: int, slot_index: int) -> bool:
	var ps := GameState.get_player(player_id)
	if ps == null:
		return false
	if slot_index < 0 or slot_index >= ps.shop_slots.size():
		return false

	var unit_id: String = ps.shop_slots[slot_index]
	if unit_id == "" or unit_id.begins_with("LOCKED:"):
		return false

	var cost: int = DataLoader.units[unit_id].cost
	if ps.gold < cost:
		return false

	var max_bench: int = DataLoader.economy.get("max_bench_size", 9)
	if ps.bench.size() >= max_bench:
		# Try to place on board if bench is full
		return false

	ps.gold -= cost
	ps.shop_slots[slot_index] = ""

	var inst := GameState.make_unit_instance(unit_id, 1)
	ps.bench.append(inst)

	SignalBus.gold_changed.emit(player_id, ps.gold)
	SignalBus.unit_purchased.emit(player_id, unit_id)
	SignalBus.unit_placed_on_bench.emit(player_id, inst["instance_id"])

	# Check for 3-copy merge (1-star → 2-star)
	GameState.try_merge_units(player_id, unit_id)
	# Check for 3x 2-star → 3-star
	# (try_merge checks 1-stars; after the above we might have 3x 2-stars)
	# We'd need another pass for 2→3, handled in the extended merge path:
	_try_merge_two_stars(player_id, unit_id)

	SynergyManager.recalculate(player_id)
	return true

func sell_unit(player_id: int, instance_id: String) -> bool:
	var ps := GameState.get_player(player_id)
	if ps == null:
		return false

	var inst := GameState.find_unit_instance(player_id, instance_id)
	if inst.is_empty():
		return false

	var unit_id: String = inst.get("unit_id", "")
	var star: int = inst.get("star", 1)
	var cost: int = DataLoader.units[unit_id].cost

	# Return unit copies to pool (1-star = 1 copy, 2-star = 3 copies, 3-star = 9 copies)
	var copies_to_return := 1
	if star == 2: copies_to_return = 3
	elif star == 3: copies_to_return = 9
	for _i in copies_to_return:
		_return_to_pool(unit_id)

	# Remove from board or bench
	_remove_unit_instance(ps, instance_id)

	# Refund
	var sell_values: Dictionary = DataLoader.economy.get("sell_values", {})
	var gold_returned: int = int(sell_values.get(str(cost), cost))
	ps.gold += gold_returned

	SignalBus.gold_changed.emit(player_id, ps.gold)
	SignalBus.unit_sold.emit(player_id, unit_id, gold_returned)
	SynergyManager.recalculate(player_id)
	return true

func reroll_shop(player_id: int) -> bool:
	var ps := GameState.get_player(player_id)
	if ps == null:
		return false

	# Check free rerolls first
	if ps.free_rerolls_remaining > 0:
		ps.free_rerolls_remaining -= 1
		refresh_shop(player_id)
		SignalBus.shop_rerolled.emit(player_id)
		return true

	var reroll_cost: int = DataLoader.economy.get("reroll_cost", 2)
	if ps.gold < reroll_cost:
		return false

	ps.gold -= reroll_cost
	SignalBus.gold_changed.emit(player_id, ps.gold)
	refresh_shop(player_id)
	SignalBus.shop_rerolled.emit(player_id)
	return true

func lock_shop(player_id: int) -> void:
	var ps := GameState.get_player(player_id)
	if ps == null:
		return
	for i in ps.shop_slots.size():
		if ps.shop_slots[i] != "":
			ps.shop_slots[i] = "LOCKED:" + ps.shop_slots[i]

func unlock_shop(player_id: int) -> void:
	var ps := GameState.get_player(player_id)
	if ps == null:
		return
	for i in ps.shop_slots.size():
		if ps.shop_slots[i].begins_with("LOCKED:"):
			ps.shop_slots[i] = ps.shop_slots[i].substr(7)

# ── Internal helpers ──────────────────────────────────────────────────────────

func _roll_shop(level: int) -> Array:
	var odds: Array = DataLoader.shop_odds.get(str(level), DataLoader.shop_odds.get("1", []))
	var result: Array = []
	for _i in SHOP_SIZE:
		result.append(_draw_unit(odds))
	return result

func _draw_unit(odds: Array) -> String:
	var roll := randf()
	var cumulative := 0.0
	var chosen_cost := 1
	for cost in range(1, 6):
		cumulative += float(odds[cost - 1])
		if roll <= cumulative:
			chosen_cost = cost
			break

	# Gather available units of that cost tier
	var available: Array = []
	for uid in DataLoader.units:
		if DataLoader.units[uid].cost == chosen_cost and GameState.unit_pool.get(uid, 0) > 0:
			available.append(uid)

	if available.is_empty():
		return ""   # Pool exhausted for this tier

	var chosen: String = available[randi() % available.size()]
	GameState.unit_pool[chosen] -= 1
	return chosen

func _return_to_pool(unit_id: String) -> void:
	if GameState.unit_pool.has(unit_id):
		GameState.unit_pool[unit_id] += 1

func _remove_unit_instance(ps: GameState.PlayerState, instance_id: String) -> void:
	for i in ps.bench.size():
		if ps.bench[i].get("instance_id", "") == instance_id:
			ps.bench.remove_at(i)
			return
	for coord in ps.board.keys():
		if ps.board[coord].get("instance_id", "") == instance_id:
			ps.board.erase(coord)
			SignalBus.unit_removed_from_board.emit(ps.player_id, instance_id)
			return

func _try_merge_two_stars(player_id: int, unit_id: String) -> void:
	var ps := GameState.get_player(player_id)
	if ps == null:
		return

	var two_stars: Array = []
	for inst in ps.bench:
		if inst.get("unit_id") == unit_id and inst.get("star", 1) == 2:
			two_stars.append({"source": "bench", "inst": inst})
	for coord in ps.board:
		var inst: Dictionary = ps.board[coord]
		if inst.get("unit_id") == unit_id and inst.get("star", 1) == 2:
			two_stars.append({"source": coord, "inst": inst})

	if two_stars.size() < 3:
		return

	var removed := 0
	var first_board_coord: Variant = null
	for entry in two_stars:
		if removed >= 3:
			break
		if entry["source"] == "bench":
			ps.bench.erase(entry["inst"])
		else:
			if first_board_coord == null:
				first_board_coord = entry["source"]
			ps.board.erase(entry["source"])
		removed += 1

	var new_inst := GameState.make_unit_instance(unit_id, 3)
	if not two_stars.is_empty():
		new_inst["items"] = two_stars[0]["inst"].get("items", []).duplicate()

	if first_board_coord != null:
		ps.board[first_board_coord] = new_inst
	else:
		ps.bench.append(new_inst)

	SignalBus.unit_upgraded.emit(player_id, unit_id, 3)
