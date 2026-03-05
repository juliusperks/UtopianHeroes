## EconomyManager — handles gold income, interest, XP, and leveling.
extends Node

func _ready() -> void:
	pass

# ── Income ────────────────────────────────────────────────────────────────────

func grant_round_income(player_id: int) -> void:
	var ps := GameState.get_player(player_id)
	if ps == null or not ps.is_alive:
		return

	var eco := DataLoader.economy
	var base: int         = eco.get("base_income", 5)
	var rate: float       = float(eco.get("interest_rate", 0.1))
	var max_int: int      = eco.get("max_interest", 5)

	# Underdraft bonus: ceil interest when fielding fewer units than level allows.
	var max_board: int    = max_board_size(player_id)
	var fielded: int      = ps.board.size()
	var raw_interest: float = float(ps.gold) * rate
	var interest: int
	if fielded < max_board:
		interest = mini(ceili(raw_interest), max_int)
	else:
		interest = mini(int(raw_interest), max_int)

	var streak_bonus: int = _get_streak_bonus(ps)

	# Trait bonus: Merchant "gold_per_round"
	var trait_bonus: int  = SynergyManager.get_bonus_value(player_id, "gold_per_round", 0)

	var total: int = base + interest + streak_bonus + trait_bonus

	# Mercenary penalty: fielding more than 2 overdraft units costs -2 interest next round.
	if ps.mercs_last_battle > 2:
		total = maxi(0, total - 2)
	ps.mercs_last_battle = 0

	ps.gold += total

	SignalBus.gold_changed.emit(player_id, ps.gold)

func _get_streak_bonus(ps: GameState.PlayerState) -> int:
	var streak := maxi(ps.win_streak, ps.loss_streak)
	if streak < 2:
		return 0
	var streak_table: Dictionary = DataLoader.economy.get("streak_bonus", {})
	var best := 0
	for threshold_str in streak_table.keys():
		var threshold := int(threshold_str)
		if streak >= threshold:
			best = maxi(best, int(streak_table[threshold_str]))
	return best

# ── XP / Leveling ─────────────────────────────────────────────────────────────

func grant_round_xp(player_id: int) -> void:
	var ps := GameState.get_player(player_id)
	if ps == null:
		return
	var per_round: int = DataLoader.economy.get("xp_per_round", 2)
	# Sage trait bonus xp
	var trait_xp: int = SynergyManager.get_bonus_value(player_id, "xp_per_round", 0)
	_add_xp(player_id, per_round + trait_xp)

func buy_xp(player_id: int) -> bool:
	var ps := GameState.get_player(player_id)
	if ps == null:
		return false
	var xp_cost: int = DataLoader.economy.get("xp_buy_cost", 4)
	if ps.gold < xp_cost:
		return false
	ps.gold -= xp_cost
	SignalBus.gold_changed.emit(player_id, ps.gold)
	_add_xp(player_id, DataLoader.economy.get("xp_buy_amount", 4))
	return true

func _add_xp(player_id: int, amount: int) -> void:
	var ps := GameState.get_player(player_id)
	if ps == null:
		return
	var max_level: int = DataLoader.economy.get("max_level", 9)
	if ps.level >= max_level:
		return
	ps.xp += amount
	_check_level_up(player_id)
	SignalBus.xp_changed.emit(player_id, ps.xp, xp_needed(ps.level))

func _check_level_up(player_id: int) -> void:
	var ps := GameState.get_player(player_id)
	if ps == null:
		return
	var max_level: int = DataLoader.economy.get("max_level", 9)
	while ps.level < max_level:
		var needed := xp_needed(ps.level)
		if ps.xp < needed:
			break
		ps.xp -= needed
		ps.level += 1
		SignalBus.player_leveled_up.emit(player_id, ps.level)

func xp_needed(level: int) -> int:
	var table: Array = DataLoader.economy.get("xp_to_level", [])
	# table[0] = XP to reach level 2, table[1] = level 3, etc.
	var idx := level - 1
	if idx < 0 or idx >= table.size():
		return 9999
	return int(table[idx])

func max_board_size(player_id: int) -> int:
	var ps := GameState.get_player(player_id)
	if ps == null:
		return 1
	var table: Array = DataLoader.economy.get("max_board_size_by_level", [])
	var idx := ps.level - 1
	if idx < 0 or idx >= table.size():
		return ps.level
	return int(table[idx])

## How many extra (overdraft) units a player may field beyond their normal cap.
## = min( ceil(max_board * overdraft_pct), overdraft_cap )
func overdraft_limit(player_id: int) -> int:
	var eco := DataLoader.economy
	var pct: float = float(eco.get("overdraft_pct", 0.4))
	var cap: int   = int(eco.get("overdraft_cap", 4))
	return mini(ceili(float(max_board_size(player_id)) * pct), cap)

# ── Damage ────────────────────────────────────────────────────────────────────

func apply_combat_damage(loser_id: int, surviving_units: int, round_number: int) -> int:
	var round_cfg: RoundConfig = DataLoader.get_round(round_number)
	var base_dmg := 2
	var per_unit := 1
	if round_cfg != null:
		base_dmg = round_cfg.base_damage
		per_unit = round_cfg.damage_per_surviving_unit
	var damage := base_dmg + (surviving_units * per_unit)

	var ps := GameState.get_player(loser_id)
	if ps != null and ps.is_alive:
		ps.hp -= damage
		SignalBus.hp_changed.emit(loser_id, ps.hp)
		if ps.hp <= 0:
			ps.is_alive = false
			SignalBus.player_eliminated.emit(loser_id)

	return damage
