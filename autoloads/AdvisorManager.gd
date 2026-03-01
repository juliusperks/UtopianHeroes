## AdvisorManager — manages the advisor offer and purchase system.
##
## When a synergy reaches a new tier, this manager picks 3 random advisor cards
## from that trait's pool and emits advisor_offer_ready. The player can buy one
## advisor per offer. Advisors grant persistent combat bonuses (not battlefield units).
## Purchased advisors are stored in PlayerState.advisors and applied at combat start.
extends Node

# Raw advisor data: trait_id -> Array[{id, name, description, cost, bonus}]
var _advisor_pool: Dictionary = {}
# Pending offers per player and trait:
# { player_id: { trait_id: Array[advisor_dict] } }
var _pending_offers: Dictionary = {}

# Track advisors already owned per player to avoid duplicate offers
# (we allow duplicates for now — buying the same advisor stacks the bonus)

func _ready() -> void:
	_load_advisors()
	SignalBus.synergy_tier_reached.connect(_on_tier_reached)

func _load_advisors() -> void:
	var path := "res://data/advisors.json"
	if not FileAccess.file_exists(path):
		push_error("[AdvisorManager] advisors.json not found")
		return
	var f := FileAccess.open(path, FileAccess.READ)
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if raw is Dictionary:
		_advisor_pool = raw as Dictionary
	else:
		push_error("[AdvisorManager] Failed to parse advisors.json")

# ── Offer generation ──────────────────────────────────────────────────────────

func _on_tier_reached(player_id: int, trait_id: String, _tier: int) -> void:
	# Only show offers to the local human player during prep phase
	if player_id != GameState.local_player_id:
		return
	var pool: Array = _advisor_pool.get(trait_id, [])
	if pool.is_empty():
		return
	# Shuffle a copy so we don't mutate the source data
	var shuffled := pool.duplicate()
	shuffled.shuffle()
	var choices := shuffled.slice(0, mini(3, shuffled.size()))
	if not _pending_offers.has(player_id):
		_pending_offers[player_id] = {}
	var per_player: Dictionary = _pending_offers[player_id]
	per_player[trait_id] = choices
	_pending_offers[player_id] = per_player
	SignalBus.advisor_offer_ready.emit(player_id, trait_id, choices)

## Re-open the latest pending advisor offer for a specific trait.
## Returns true if an offer exists and was emitted.
func reopen_offer_for_trait(player_id: int, trait_id: String) -> bool:
	if not _pending_offers.has(player_id):
		return false
	var per_player: Dictionary = _pending_offers[player_id]
	if not per_player.has(trait_id):
		return false
	var choices: Array = per_player[trait_id]
	if choices.is_empty():
		return false
	SignalBus.advisor_offer_ready.emit(player_id, trait_id, choices)
	return true

# ── Purchase ──────────────────────────────────────────────────────────────────

## Attempt to buy an advisor for the local player. Returns true on success.
func purchase(advisor_id: String) -> bool:
	var ps := GameState.local_player()
	if ps == null:
		return false
	var advisor := _find_advisor(advisor_id)
	if advisor.is_empty():
		push_error("[AdvisorManager] Unknown advisor id: %s" % advisor_id)
		return false
	var cost: int = int(advisor.get("cost", 3))
	if ps.gold < cost:
		SignalBus.show_message.emit("Not enough gold for this advisor!", 2.0)
		return false
	ps.gold -= cost
	SignalBus.gold_changed.emit(GameState.local_player_id, ps.gold)
	ps.advisors.append(advisor_id)
	SignalBus.advisor_purchased.emit(GameState.local_player_id, advisor_id)
	_clear_pending_offer_for_advisor(GameState.local_player_id, advisor_id)
	return true

## Sell (remove) an advisor the player already owns. Refunds half cost (rounded down).
func sell(advisor_id: String) -> bool:
	var ps := GameState.local_player()
	if ps == null:
		return false
	var idx := ps.advisors.find(advisor_id)
	if idx < 0:
		return false
	var advisor := _find_advisor(advisor_id)
	ps.advisors.remove_at(idx)
	var refund: int = int(advisor.get("cost", 3)) / 2
	ps.gold += refund
	SignalBus.gold_changed.emit(GameState.local_player_id, ps.gold)
	SignalBus.show_message.emit("Advisor dismissed (+%dg)" % refund, 1.5)
	return true

# ── Bonus calculation ─────────────────────────────────────────────────────────

## Returns the combined bonus dict for all advisors a player has purchased.
## Bonus keys match the synergy bonus key convention.
func get_bonuses(player_id: int) -> Dictionary:
	var ps := GameState.get_player(player_id)
	if ps == null:
		return {}
	var result: Dictionary = {}
	for advisor_id in ps.advisors:
		var advisor := _find_advisor(advisor_id)
		var bonus: Dictionary = advisor.get("bonus", {})
		for key in bonus:
			result[key] = float(result.get(key, 0)) + float(bonus[key])
	return result

## Returns the def dict for a single advisor id, searching all pools.
func get_advisor_def(advisor_id: String) -> Dictionary:
	return _find_advisor(advisor_id)

func _find_advisor(advisor_id: String) -> Dictionary:
	for trait_id in _advisor_pool:
		for advisor in _advisor_pool[trait_id]:
			if advisor.get("id", "") == advisor_id:
				return advisor
	return {}

func _find_trait_for_advisor(advisor_id: String) -> String:
	for trait_id in _advisor_pool:
		for advisor in _advisor_pool[trait_id]:
			if advisor.get("id", "") == advisor_id:
				return trait_id
	return ""

func _clear_pending_offer_for_advisor(player_id: int, advisor_id: String) -> void:
	var trait_id := _find_trait_for_advisor(advisor_id)
	if trait_id == "":
		return
	if not _pending_offers.has(player_id):
		return
	var per_player: Dictionary = _pending_offers[player_id]
	if per_player.has(trait_id):
		per_player.erase(trait_id)
		_pending_offers[player_id] = per_player
