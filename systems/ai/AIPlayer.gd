## AIPlayer — simulates one AI opponent during the prep phase.
## Each AI has a chosen "composition goal" (a set of desired trait synergies).
## It buys units that fit its comp, levels up when beneficial, and arranges its board.
class_name AIPlayer
extends RefCounted

var player_id: int
var _strategy: AIShopStrategy
var _positioner: AIBoardPositioner

# The AI's target composition: Array of trait_ids it wants to build around
var target_comp: Array = []

func _init(id: int) -> void:
	player_id = id
	_strategy  = AIShopStrategy.new(id)
	_positioner = AIBoardPositioner.new(id)
	_pick_random_comp()

func _pick_random_comp() -> void:
	# Randomly pick 2-3 traits to build around
	var all_traits := DataLoader.traits.keys()
	all_traits.shuffle()
	target_comp = all_traits.slice(0, 2 + randi() % 2)
	_strategy.set_target_comp(target_comp)

## Called each prep phase by AIDirector
func do_prep_phase() -> void:
	var ps := GameState.get_player(player_id)
	if ps == null or not ps.is_alive:
		return

	_maybe_buy_xp(ps)
	_buy_units(ps)
	_maybe_reroll(ps)
	_positioner.arrange_board()

func _maybe_buy_xp(ps: GameState.PlayerState) -> void:
	# Buy XP if close to leveling and have enough gold to still play the shop
	var xp_cost: int = DataLoader.economy.get("xp_buy_cost", 4)
	var max_board := EconomyManager.max_board_size(player_id)
	var on_board  := ps.board.size()
	# Level up if we have room to add more units and enough gold
	if ps.gold >= xp_cost + 4 and on_board >= max_board - 1 and ps.level < 8:
		EconomyManager.buy_xp(player_id)

func _buy_units(ps: GameState.PlayerState) -> void:
	var max_bench: int = DataLoader.economy.get("max_bench_size", 9)
	# Attempt to buy from each slot
	for slot_idx in ps.shop_slots.size():
		if ps.bench.size() + ps.board.size() >= max_bench + EconomyManager.max_board_size(player_id):
			break
		var unit_id: String = ps.shop_slots[slot_idx]
		if unit_id == "" or unit_id.begins_with("LOCKED:"):
			continue
		if ps.gold < DataLoader.units[unit_id].cost:
			continue
		if _strategy.wants_unit(unit_id):
			ShopManager.buy_unit(player_id, slot_idx)

func _maybe_reroll(ps: GameState.PlayerState) -> void:
	# Reroll if we have a clear target and spare gold (keep at least 10 for interest)
	var reroll_cost: int = DataLoader.economy.get("reroll_cost", 2)
	if ps.gold < 10 + reroll_cost:
		return
	if _strategy.should_reroll():
		ShopManager.reroll_shop(player_id)
