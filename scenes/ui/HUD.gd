## HUD — in-game overlay showing gold, HP, XP, round info, and the prep timer.
## All sizes are derived from the viewport dimensions at startup so the UI
## scales correctly with any design resolution.
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
	var vp := get_viewport().get_visible_rect().size
	var vw := vp.x
	var vh := vp.y

	# Proportions (designed at 1920×1080)
	var bar_h    := int(vh * 0.063)   # 68px @ 1080p
	var pad_x    := int(vw * 0.006)   # 12px
	var pad_y    := int(vh * 0.007)   # 8px
	var sep      := int(vw * 0.013)   # 24px gap between items
	var fnt_main := int(vh * 0.026)   # 28px  HP / Gold
	var fnt_mid  := int(vh * 0.020)   # 22px  Round / Phase
	var fnt_tmr  := int(vh * 0.037)   # 40px  countdown
	var fnt_skip := int(vh * 0.017)   # 18px  Ready button
	var lbl_h    := int(vh * 0.048)   # 52px  label min height
	var lbl_w    := int(vw * 0.063)   # 120px label min width
	var tmr_w    := int(vw * 0.042)   # 80px  timer min width
	var btn_w    := int(vw * 0.063)   # 120px Ready button
	var btn_h    := int(vh * 0.044)   # 48px

	# ── Top bar background ──────────────────────────────────────────────────
	var top_bg := ColorRect.new()
	top_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bg.custom_minimum_size = Vector2(0, bar_h)
	top_bg.color = Color(0.04, 0.06, 0.12, 0.88)
	add_child(top_bg)

	# ── Top bar content row ─────────────────────────────────────────────────
	var top_bar := HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.position = Vector2(pad_x, pad_y)
	top_bar.custom_minimum_size = Vector2(0, lbl_h)
	top_bar.add_theme_constant_override("separation", sep)
	add_child(top_bar)

	_hp_label = _make_label("♥ 100", fnt_main, Color(1.0, 0.35, 0.35), lbl_w, lbl_h)
	top_bar.add_child(_hp_label)

	_gold_label = _make_label("0 g", fnt_main, Color.GOLD, lbl_w, lbl_h)
	top_bar.add_child(_gold_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	_round_label = _make_label("Round 1", fnt_mid, Color.WHITE, lbl_w, lbl_h)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(_round_label)

	_phase_label = _make_label("PREP", fnt_mid, Color.AQUA, lbl_w, lbl_h)
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(_phase_label)

	_timer_label = _make_label("30", fnt_tmr, Color.WHITE, tmr_w, lbl_h)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(_timer_label)

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer2)

	_skip_btn = Button.new()
	_skip_btn.text = "Ready ✓"
	_skip_btn.add_theme_font_size_override("font_size", fnt_skip)
	_skip_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	_skip_btn.pressed.connect(func(): RoundManager.skip_prep())
	var skip_style := StyleBoxFlat.new()
	skip_style.bg_color = Color(0.10, 0.52, 0.18)
	skip_style.border_color = Color(0.25, 0.80, 0.30)
	skip_style.set_border_width_all(2)
	skip_style.set_corner_radius_all(6)
	_skip_btn.add_theme_stylebox_override("normal", skip_style)
	top_bar.add_child(_skip_btn)

	# ── Message banner ──────────────────────────────────────────────────────
	var fnt_msg := int(vh * 0.033)   # 36px
	var msg_w   := int(vw * 0.208)   # 400px
	var msg_h   := int(vh * 0.065)   # 70px
	_message_label = Label.new()
	_message_label.add_theme_font_size_override("font_size", fnt_msg)
	_message_label.add_theme_constant_override("outline_size", 4)
	_message_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.position = Vector2(vw * 0.396, vh * 0.407)
	_message_label.size = Vector2(msg_w, msg_h)
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
		_gold_label.text = "%d g" % amount

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

func _make_label(text: String, size: int, color: Color, min_w: int, min_h: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 2)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.modulate = color
	l.custom_minimum_size = Vector2(min_w, min_h)
	return l
