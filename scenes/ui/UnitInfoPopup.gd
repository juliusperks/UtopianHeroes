## UnitInfoPopup — hover tooltip showing unit stats, ability, and items.
extends PanelContainer

var _name_label: Label
var _trait_label: Label
var _stats_label: Label
var _ability_label: Label
var _items_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(200, 160)
	visible = false
	z_index = 100
	_build_ui()
	SignalBus.show_unit_tooltip.connect(_on_show)
	SignalBus.hide_unit_tooltip.connect(_on_hide)

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.modulate = Color.GOLD
	vbox.add_child(_name_label)

	_trait_label = Label.new()
	_trait_label.add_theme_font_size_override("font_size", 11)
	_trait_label.modulate = Color.AQUA
	vbox.add_child(_trait_label)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_stats_label)

	_ability_label = Label.new()
	_ability_label.add_theme_font_size_override("font_size", 11)
	_ability_label.modulate = Color.PLUM
	_ability_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_ability_label)

	_items_label = Label.new()
	_items_label.add_theme_font_size_override("font_size", 10)
	_items_label.modulate = Color.LIGHT_YELLOW
	vbox.add_child(_items_label)

func _on_show(udata: UnitData, inst: Dictionary) -> void:
	var star: int = inst.get("star", 1)
	_name_label.text = "%s %s" % [udata.display_name, _star_str(star)]
	_trait_label.text = "%s / %s" % [udata.origin.capitalize(), udata.unit_class.capitalize()]

	var hp  := udata.get_stat_at_star(udata.base_hp, star)
	var atk := udata.get_stat_at_star(udata.base_atk, star)
	_stats_label.text = "HP: %d  ATK: %d  ARM: %d  MR: %d\nSPD: %.1f/s  RNG: %d  Cost: %d" % [
		int(hp), int(atk), int(udata.base_armor), int(udata.base_mr),
		udata.atk_speed, udata.atk_range, udata.cost
	]

	if udata.ability_id != "":
		var val_idx := clampi(star - 1, 0, udata.ability_values.size() - 1)
		var val_str := str(udata.ability_values[val_idx]) if not udata.ability_values.is_empty() else ""
		var ability_values_as_text := PackedStringArray()
		for value in udata.ability_values:
			ability_values_as_text.append(str(value))
		_ability_label.text = "✦ %s: %s" % [
			udata.ability_name,
			udata.ability_description.replace("[%s]" % "/".join(ability_values_as_text), val_str)
		]
	else:
		_ability_label.text = ""

	var item_ids: Array = inst.get("items", [])
	if item_ids.is_empty():
		_items_label.text = "No items"
	else:
		var names := item_ids.map(func(iid): return DataLoader.items.get(iid, ItemData.new()).display_name)
		_items_label.text = "Items: " + ", ".join(names)

	# Follow mouse
	global_position = get_viewport().get_mouse_position() + Vector2(16, 16)
	visible = true

func _on_hide() -> void:
	visible = false

func _process(_delta: float) -> void:
	if visible:
		global_position = get_viewport().get_mouse_position() + Vector2(16, 16)

func _star_str(star: int) -> String:
	match star:
		2: return "★★"
		3: return "★★★"
		_: return "★"
