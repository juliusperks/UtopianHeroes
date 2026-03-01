## HUD — in-game overlay showing gold, HP, XP, round info, and the prep timer.
extends CanvasLayer

var _gold_label: Label
var _hp_label: Label
var _round_label: Label
var _phase_label: Label
var _timer_label: Label
var _skip_btn: Button
var _message_label: Label
var _message_timer: float = 0.0

func _ready() -> void:
	_build_ui()
	_connect_signals()

func _build_ui() -> void:
	# Top bar
	var top_bar := HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.position = Vector2(0, 4)
	top_bar.custom_minimum_size = Vector2(0, 40)
	add_child(top_bar)

	_gold_label = _make_label("0g", 16, Color.GOLD)
	top_bar.add_child(_gold_label)

	_hp_label = _make_label("♥ 100", 16, Color.TOMATO)
	top_bar.add_child(_hp_label)

	_round_label = _make_label("Round 1", 16, Color.WHITE)
	top_bar.add_child(_round_label)

	_phase_label = _make_label("PREP", 16, Color.AQUA)
	top_bar.add_child(_phase_label)

	_timer_label = _make_label("30", 18, Color.WHITE)
	top_bar.add_child(_timer_label)

	_skip_btn = Button.new()
	_skip_btn.text = "Ready!"
	_skip_btn.pressed.connect(func(): RoundManager.skip_prep())
	top_bar.add_child(_skip_btn)

	# Message banner (center screen, temporary)
	_message_label = Label.new()
	_message_label.add_theme_font_size_override("font_size", 24)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.set_anchors_preset(Control.PRESET_CENTER)
	_message_label.position = Vector2(440, 300)
	_message_label.size = Vector2(400, 50)
	_message_label.modulate = Color.WHITE
	_message_label.visible = false
	add_child(_message_label)

func _connect_signals() -> void:
	SignalBus.gold_changed.connect(_on_gold_changed)
	SignalBus.hp_changed.connect(_on_hp_changed)
	SignalBus.round_started.connect(_on_round_started)
	SignalBus.phase_changed.connect(_on_phase_changed)
	SignalBus.prep_timer_updated.connect(_on_timer_updated)
	SignalBus.show_message.connect(_on_show_message)
	SignalBus.combat_ended.connect(_on_combat_ended)

func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message_label.visible = false

func _on_gold_changed(player_id: int, amount: int) -> void:
	if player_id == GameState.local_player_id:
		_gold_label.text = "%dg" % amount

func _on_hp_changed(player_id: int, hp: int) -> void:
	if player_id == GameState.local_player_id:
		_hp_label.text = "♥ %d" % hp

func _on_round_started(round_number: int) -> void:
	var round_cfg: RoundConfig = DataLoader.get_round(round_number)
	var label := "Round %d" % round_number
	if round_cfg != null:
		label = round_cfg.display_label
	_round_label.text = label

func _on_phase_changed(phase: int) -> void:
	match phase:
		RoundManager.Phase.PREP:
			_phase_label.text = "PREP"
			_phase_label.modulate = Color.AQUA
			_skip_btn.visible = true
			_timer_label.visible = true
		RoundManager.Phase.COMBAT:
			_phase_label.text = "COMBAT"
			_phase_label.modulate = Color.TOMATO
			_skip_btn.visible = false
		RoundManager.Phase.RESULTS:
			_phase_label.text = "RESULTS"
			_phase_label.modulate = Color.LIME_GREEN
			_timer_label.visible = false
		RoundManager.Phase.CAROUSEL:
			_phase_label.text = "DRAFT"
			_phase_label.modulate = Color.GOLD
		RoundManager.Phase.GAME_OVER:
			_phase_label.text = "GAME OVER"
			_phase_label.modulate = Color.WHITE

func _on_timer_updated(seconds_left: float) -> void:
	_timer_label.text = "%d" % ceili(seconds_left)

func _on_show_message(text: String, duration: float) -> void:
	_message_label.text = text
	_message_label.visible = true
	_message_timer = duration

func _on_combat_ended(winner_id: int, loser_id: int, damage: int) -> void:
	if winner_id == GameState.local_player_id:
		_on_show_message("Victory! +%d damage dealt" % damage, 3.0)
	elif loser_id == GameState.local_player_id:
		_on_show_message("Defeat! -%d HP" % damage, 3.0)

func _make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.modulate = color
	l.custom_minimum_size = Vector2(100, 30)
	return l
