## RoundManager — drives the game's phase state machine.
## Phases: LOBBY → (CAROUSEL or PREP) → COMBAT → RESULTS → next round
extends Node

enum Phase {
	LOBBY     = 0,
	CAROUSEL  = 1,
	PREP      = 2,
	COMBAT    = 3,
	RESULTS   = 4,
	GAME_OVER = 5
}

const PREP_DURATION    := 30.0
const RESULTS_DURATION := 4.0

var current_phase: Phase = Phase.LOBBY
var prep_time_remaining: float = 0.0

var _phase_timer: Timer

func _ready() -> void:
	_phase_timer = Timer.new()
	_phase_timer.one_shot = true
	_phase_timer.timeout.connect(_on_phase_timer_timeout)
	add_child(_phase_timer)

func start_game() -> void:
	GameState.init_game()
	_advance_round()

func _advance_round() -> void:
	GameState.current_round += 1
	var round_cfg: RoundConfig = DataLoader.get_round(GameState.current_round)

	SignalBus.round_started.emit(GameState.current_round)

	if round_cfg == null:
		# Past defined rounds — keep using PvP defaults
		_enter_phase(Phase.PREP)
		return

	match round_cfg.round_type:
		"carousel":
			_enter_phase(Phase.CAROUSEL)
		_:
			_enter_phase(Phase.PREP)

func _enter_phase(phase: Phase) -> void:
	current_phase = phase
	GameState.current_phase = phase as int
	SignalBus.phase_changed.emit(phase as int)

	match phase:
		Phase.PREP:
			# Grant round income to all alive players
			for ps in GameState.alive_players():
				EconomyManager.grant_round_income(ps.player_id)
				# Apply free rerolls from Human trait
				var bonuses := SynergyManager.get_all_bonuses(ps.player_id)
				ps.free_rerolls_remaining = bonuses.get("free_rerolls", 0)

			# Refresh shops
			ShopManager.refresh_shops_for_all()

			# AI players take their turn
			AIDirector.do_prep_phase()

			# Start countdown
			prep_time_remaining = PREP_DURATION
			_phase_timer.start(PREP_DURATION)

		Phase.CAROUSEL:
			# Carousel logic handled by CarouselRound scene via signals
			pass

		Phase.COMBAT:
			_phase_timer.stop()
			# BattleArena scene listens to phase_changed and kicks off combat

		Phase.RESULTS:
			_phase_timer.start(RESULTS_DURATION)

		Phase.GAME_OVER:
			pass

func _process(delta: float) -> void:
	if current_phase == Phase.PREP:
		prep_time_remaining -= delta
		SignalBus.prep_timer_updated.emit(prep_time_remaining)

func _on_phase_timer_timeout() -> void:
	match current_phase:
		Phase.PREP:
			_enter_phase(Phase.COMBAT)
		Phase.RESULTS:
			_check_game_over()

## Called by BattleArena after combat is resolved
func on_combat_complete() -> void:
	_enter_phase(Phase.RESULTS)

## Called by CarouselRound when player has picked their unit
func on_carousel_complete() -> void:
	_enter_phase(Phase.PREP)

func skip_prep() -> void:
	if current_phase == Phase.PREP:
		_phase_timer.stop()
		_enter_phase(Phase.COMBAT)

func _check_game_over() -> void:
	var alive := GameState.alive_player_count()
	if alive <= 1:
		var winner_id := -1
		for ps in GameState.players:
			if ps.is_alive:
				winner_id = ps.player_id
				break
		_enter_phase(Phase.GAME_OVER)
		SignalBus.game_over.emit(winner_id)
	else:
		_advance_round()

func is_prep() -> bool:
	return current_phase == Phase.PREP

func is_combat() -> bool:
	return current_phase == Phase.COMBAT
