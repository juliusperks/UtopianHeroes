## SynergyPanel — sidebar showing all active trait synergies and their tiers.
extends PanelContainer

var _vbox: VBoxContainer
var _header: Label

func _ready() -> void:
	custom_minimum_size = Vector2(160, 200)
	_build_ui()
	SignalBus.synergies_updated.connect(_on_synergies_updated)

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var outer := VBoxContainer.new()
	margin.add_child(outer)

	_header = Label.new()
	_header.text = "Synergies"
	_header.add_theme_font_size_override("font_size", 13)
	_header.modulate = Color.GOLD
	outer.add_child(_header)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 3)
	outer.add_child(_vbox)

func _on_synergies_updated(player_id: int, _bonuses: Dictionary) -> void:
	if player_id != GameState.local_player_id:
		return
	_rebuild_list()

func _rebuild_list() -> void:
	for child in _vbox.get_children():
		child.queue_free()

	var synergies := SynergyManager.get_display_synergies(GameState.local_player_id)
	for entry in synergies:
		# Wrap the row in a Control that intercepts mouse events for hover tooltip.
		var wrapper := Control.new()
		wrapper.custom_minimum_size = Vector2(0, 18)
		wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
		wrapper.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Tier pip indicator
		var pip_label := Label.new()
		pip_label.add_theme_font_size_override("font_size", 10)
		pip_label.text = "●" if entry["tier"] >= entry["max_tier"] else "◐" if entry["tier"] > 0 else "○"
		pip_label.modulate = _tier_color(entry["tier"], entry["max_tier"])
		pip_label.custom_minimum_size = Vector2(14, 0)
		pip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pip_label)

		# Name + count
		var name_label := Label.new()
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.text = "%s (%d)" % [entry["display_name"], entry["count"]]
		name_label.modulate = _tier_color(entry["tier"], entry["max_tier"])
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_label)

		wrapper.add_child(row)

		# Hover → show trait tooltip; leave → hide it.
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
