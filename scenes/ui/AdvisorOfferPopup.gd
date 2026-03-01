## AdvisorOfferPopup — shown when the player reaches a new synergy tier.
## Displays up to 3 advisor cards (name, description, cost, bonus).
## The player can buy one, or close the popup to skip the offer.
extends PanelContainer

var _title_label: Label
var _cards_container: HBoxContainer
var _close_btn: Button

# Current offer data so we can rebuild if shown again
var _current_player_id: int = -1
var _current_choices: Array = []

func _ready() -> void:
	custom_minimum_size = Vector2(540, 0)
	visible = false
	z_index = 200
	_build_ui()
	SignalBus.advisor_offer_ready.connect(_on_offer_ready)

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 15)
	_title_label.modulate = Color.GOLD
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_cards_container = HBoxContainer.new()
	_cards_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_cards_container)

	_close_btn = Button.new()
	_close_btn.text = "Dismiss"
	_close_btn.pressed.connect(func(): visible = false)
	vbox.add_child(_close_btn)

func _on_offer_ready(player_id: int, trait_id: String, choices: Array) -> void:
	_current_player_id = player_id
	_current_choices = choices

	# Title reflects which synergy triggered the offer
	var tdata: TraitData = DataLoader.traits.get(trait_id, null)
	var trait_name := tdata.display_name if tdata else trait_id.capitalize()
	_title_label.text = "New %s Advisor Available!" % trait_name

	# Clear previous cards
	for child in _cards_container.get_children():
		child.queue_free()

	for advisor in choices:
		_cards_container.add_child(_make_card(advisor))

	_reposition()
	visible = true

func _make_card(advisor: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(155, 0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = advisor.get("name", "?")
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.modulate = Color.GOLD
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = advisor.get("description", "")
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.custom_minimum_size = Vector2(139, 0)
	vbox.add_child(desc_lbl)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Owned count + sell button row (if already owned)
	var ps := GameState.local_player()
	var owned_count: int = 0
	if ps != null:
		for aid in ps.advisors:
			if aid == advisor.get("id", ""):
				owned_count += 1

	if owned_count > 0:
		var owned_lbl := Label.new()
		owned_lbl.text = "Owned: %d" % owned_count
		owned_lbl.add_theme_font_size_override("font_size", 10)
		owned_lbl.modulate = Color(0.6, 1.0, 0.6)
		vbox.add_child(owned_lbl)

	var cost: int = int(advisor.get("cost", 3))
	var buy_btn := Button.new()
	buy_btn.text = "Buy (%dg)" % cost
	var advisor_id: String = advisor.get("id", "")
	buy_btn.pressed.connect(_on_buy_pressed.bind(advisor_id, buy_btn))
	vbox.add_child(buy_btn)

	return panel

func _on_buy_pressed(advisor_id: String, btn: Button) -> void:
	var success := AdvisorManager.purchase(advisor_id)
	if success:
		# Dim the button after purchase so it's clear the action happened
		btn.text = "Purchased!"
		btn.disabled = true

func _reposition() -> void:
	# Center horizontally, sit just above the bottom shop area
	var vp_size := get_viewport().get_visible_rect().size
	await get_tree().process_frame  # let size be computed first
	var pos_x := (vp_size.x - size.x) * 0.5
	var pos_y := vp_size.y - size.y - 240.0  # above shop panel (~495px)
	pos_y = maxf(pos_y, 50.0)
	global_position = Vector2(pos_x, pos_y)
