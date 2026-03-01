## ShopSlot — one of 5 shop cards showing a purchasable unit.
## Created and managed by ShopPanel.
extends PanelContainer

signal purchase_requested(slot_index: int)

var slot_index: int = 0
var unit_id: String = ""

var _name_label: Label
var _cost_label: Label
var _origin_label: Label
var _class_label: Label
var _buy_button: Button
var _locked_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(110, 150)
	_build_ui()

func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.text = "—"
	vbox.add_child(_name_label)

	_origin_label = Label.new()
	_origin_label.add_theme_font_size_override("font_size", 10)
	_origin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_origin_label.modulate = Color(0.7, 0.9, 1.0)
	vbox.add_child(_origin_label)

	_class_label = Label.new()
	_class_label.add_theme_font_size_override("font_size", 10)
	_class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_class_label.modulate = Color(1.0, 0.85, 0.6)
	vbox.add_child(_class_label)

	_cost_label = Label.new()
	_cost_label.add_theme_font_size_override("font_size", 14)
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.modulate = Color.GOLD
	vbox.add_child(_cost_label)

	_buy_button = Button.new()
	_buy_button.text = "Buy"
	_buy_button.pressed.connect(func(): purchase_requested.emit(slot_index))
	vbox.add_child(_buy_button)

	_locked_label = Label.new()
	_locked_label.text = "LOCKED"
	_locked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_locked_label.modulate = Color.LIGHT_YELLOW
	_locked_label.visible = false
	vbox.add_child(_locked_label)

func set_unit(p_unit_id: String) -> void:
	unit_id = p_unit_id
	var is_locked := p_unit_id.begins_with("LOCKED:")
	var effective_id := p_unit_id.substr(7) if is_locked else p_unit_id

	_locked_label.visible = is_locked

	if effective_id == "":
		_name_label.text = "Empty"
		_origin_label.text = ""
		_class_label.text = ""
		_cost_label.text = ""
		_buy_button.visible = false
		return

	_buy_button.visible = true
	var udata: UnitData = DataLoader.units.get(effective_id, null)
	if udata == null:
		return

	_name_label.text = udata.display_name
	_origin_label.text = udata.origin.capitalize()
	_class_label.text = udata.unit_class.capitalize()
	_cost_label.text = "%d ★" % udata.cost
	_buy_button.disabled = is_locked

	# Color background by cost tier
	var panel_color := _cost_color(udata.cost)
	var sb := StyleBoxFlat.new()
	sb.bg_color = panel_color
	sb.border_width_bottom = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_color = panel_color.lightened(0.3)
	add_theme_stylebox_override("panel", sb)

func _cost_color(cost: int) -> Color:
	match cost:
		1: return Color(0.55, 0.55, 0.55, 0.9)
		2: return Color(0.2, 0.5, 0.2, 0.9)
		3: return Color(0.1, 0.3, 0.7, 0.9)
		4: return Color(0.55, 0.1, 0.55, 0.9)
		5: return Color(0.8, 0.6, 0.0, 0.9)
		_: return Color(0.3, 0.3, 0.3, 0.9)

func set_affordable(can_afford: bool) -> void:
	_buy_button.disabled = not can_afford or unit_id.begins_with("LOCKED:")
