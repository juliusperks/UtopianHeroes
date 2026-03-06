## SynergyPanel — sidebar showing all active trait synergies and their tiers.
## All sizes are derived from viewport dimensions at startup.
extends PanelContainer

var _vbox: VBoxContainer
var _header: Label

func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	custom_minimum_size = Vector2(int(vp.x * 0.115), int(vp.y * 0.278))  # 220×300 @ 1080p
	_build_ui()
	SignalBus.synergies_updated.connect(_on_synergies_updated)

func _build_ui() -> void:
	var vp  := get_viewport().get_visible_rect().size
	var vw  := vp.x
	var vh  := vp.y

	var pad       := int(vh * 0.009)   # 10px margin
	var fnt_hdr   := int(vh * 0.017)   # 18px
	var row_h     := int(vh * 0.024)   # 26px per row
	var pip_w     := int(vw * 0.009)   # 18px pip
	var fnt_pip   := int(vh * 0.013)   # 14px
	var fnt_name  := int(vh * 0.014)   # 15px
	var sep       := int(vh * 0.006)   # 6px between rows

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   pad)
	margin.add_theme_constant_override("margin_right",  pad)
	margin.add_theme_constant_override("margin_top",    pad)
	margin.add_theme_constant_override("margin_bottom", pad)
	add_child(margin)

	var outer := VBoxContainer.new()
	margin.add_child(outer)

	_header = Label.new()
	_header.text = "Synergies"
	_header.add_theme_font_size_override("font_size", fnt_hdr)
	_header.add_theme_constant_override("outline_size", 2)
	_header.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_header.modulate = Color.GOLD
	outer.add_child(_header)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", sep)
	_vbox.set_meta("_row_h",    row_h)
	_vbox.set_meta("_pip_w",    pip_w)
	_vbox.set_meta("_fnt_pip",  fnt_pip)
	_vbox.set_meta("_fnt_name", fnt_name)
	outer.add_child(_vbox)

func _on_synergies_updated(player_id: int, _bonuses: Dictionary) -> void:
	if player_id != GameState.local_player_id:
		return
	_rebuild_list()

func _rebuild_list() -> void:
	for child in _vbox.get_children():
		child.queue_free()

	var row_h    := int(_vbox.get_meta("_row_h",    26))
	var pip_w    := int(_vbox.get_meta("_pip_w",    18))
	var fnt_pip  := int(_vbox.get_meta("_fnt_pip",  14))
	var fnt_name := int(_vbox.get_meta("_fnt_name", 15))

	var synergies := SynergyManager.get_display_synergies(GameState.local_player_id)
	for entry in synergies:
		var wrapper := Control.new()
		wrapper.custom_minimum_size = Vector2(0, row_h)
		wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
		wrapper.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(pip_w * 0.3))
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var pip_label := Label.new()
		pip_label.add_theme_font_size_override("font_size", fnt_pip)
		pip_label.text = "●" if entry["tier"] >= entry["max_tier"] else "◐" if entry["tier"] > 0 else "○"
		pip_label.modulate = _tier_color(entry["tier"], entry["max_tier"])
		pip_label.custom_minimum_size = Vector2(pip_w, 0)
		pip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pip_label)

		var name_label := Label.new()
		name_label.add_theme_font_size_override("font_size", fnt_name)
		name_label.add_theme_constant_override("outline_size", 1)
		name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		name_label.text = "%s (%d)" % [entry["display_name"], entry["count"]]
		name_label.modulate = _tier_color(entry["tier"], entry["max_tier"])
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_label)

		wrapper.add_child(row)

		var tid: String = entry["trait_id"]
		var count: int  = entry["count"]
		var tier: int   = entry["tier"]
		wrapper.mouse_entered.connect(func():
			var tdata: TraitData = DataLoader.traits.get(tid, null)
			if tdata != null:
				SignalBus.show_trait_tooltip.emit(tdata, count, tier)
		)
		wrapper.mouse_exited.connect(func():
			SignalBus.hide_trait_tooltip.emit()
		)
		wrapper.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton:
				var mb := event as InputEventMouseButton
				if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
					var reopened := AdvisorManager.reopen_offer_for_trait(GameState.local_player_id, tid)
					if not reopened:
						SignalBus.show_message.emit("No pending advisor offer for this synergy.", 1.3)
		)

		_vbox.add_child(wrapper)

func _tier_color(tier: int, max_tier: int) -> Color:
	if tier <= 0:
		return Color(0.5, 0.5, 0.5)
	if tier >= max_tier:
		return Color.GOLD
	return Color(0.4, 0.9, 0.5)
