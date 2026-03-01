## SignalBus — global decoupled event hub.
## All systems emit and connect through here so they never reference each other directly.
## This is especially important for multiplayer-readiness: the server can emit signals
## and all UI/logic reacts the same way as if the local player triggered them.
extends Node

# --- Phase / Round ---
signal phase_changed(phase: int)          # RoundManager.Phase enum value
signal round_started(round_number: int)
signal prep_timer_updated(seconds_left: float)

# --- Economy ---
signal gold_changed(player_id: int, new_amount: int)
signal player_leveled_up(player_id: int, new_level: int)
signal xp_changed(player_id: int, current_xp: int, xp_needed: int)

# --- Shop ---
signal shop_refreshed(player_id: int)
signal unit_purchased(player_id: int, unit_id: String)
signal unit_sold(player_id: int, unit_id: String, gold_returned: int)
signal shop_rerolled(player_id: int)

# --- Board / Bench ---
signal unit_placed_on_board(player_id: int, unit_instance_id: String, coord: Vector2i)
signal unit_removed_from_board(player_id: int, unit_instance_id: String)
signal unit_placed_on_bench(player_id: int, unit_instance_id: String)
signal unit_upgraded(player_id: int, unit_id: String, new_star: int)

# --- Synergies ---
signal synergies_updated(player_id: int, active_bonuses: Dictionary)

# --- Combat ---
signal combat_started(player_id: int, opponent_id: int)
signal combat_ended(winner_player_id: int, loser_player_id: int, damage: int)
signal unit_died(unit_instance_id: String, team: int)

# --- Players ---
signal hp_changed(player_id: int, new_hp: int)
signal player_eliminated(player_id: int)
signal game_over(winner_player_id: int)

# --- Items ---
signal item_equipped(player_id: int, unit_instance_id: String, item_id: String)
signal item_unequipped(player_id: int, unit_instance_id: String, item_id: String)

# --- Advisors ---
signal synergy_tier_reached(player_id: int, trait_id: String, tier: int)
signal advisor_offer_ready(player_id: int, trait_id: String, choices: Array)
signal advisor_purchased(player_id: int, advisor_id: String)

# --- UI helpers ---
signal show_unit_tooltip(unit_data: UnitData, unit_instance: Dictionary)
signal hide_unit_tooltip()
signal show_trait_tooltip(trait_data: TraitData, count: int, active_tier: int)
signal hide_trait_tooltip()
signal show_message(text: String, duration: float)
