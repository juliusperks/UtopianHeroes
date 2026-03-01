## ShopPanel — displays the 5-slot shop, reroll, and buy-XP buttons.
## Reads from GameState.local_player().shop_slots and reacts to SignalBus.
extends PanelContainer

const ShopSlotScene := preload("res://scenes/shop/ShopSlot.tscn")

var _slot_nodes: Array = []   # Array[ShopSlot]
var _reroll_btn: Button
var _xp_btn: Button
var _gold_label: Label
var _level_label: Label

func _ready() -> void:
	_build_ui()
	_connect_signals()
	_refresh()

func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# Slot row
	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 6)
	vbox.add_child(slot_row)

	for i in 5:
		var slot: Node = ShopSlotScene.instantiate()
		slot.slot_index = i
		slot.purchase_requested.connect(_on_purchase_requested)
		slot_row.add_child(slot)
		_slot_nodes.append(slot)

	# Button row
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	_reroll_btn = Button.new()
	_reroll_btn.text = "Reroll (2g)"
	_reroll_btn.pressed.connect(_on_reroll)
	btn_row.add_child(_reroll_btn)

	_xp_btn = Button.new()
	_xp_btn.text = "Buy XP (4g)"
	_xp_btn.pressed.connect(_on_buy_xp)
	btn_row.add_child(_xp_btn)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 14)
	_gold_label.modulate = Color.GOLD
	btn_row.add_child(_gold_label)

	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 12)
	btn_row.add_child(_level_label)

func _connect_signals() -> void:
	SignalBus.shop_refreshed.connect(_on_shop_refreshed)
	SignalBus.gold_changed.connect(_on_gold_changed)
	SignalBus.player_leveled_up.connect(_on_player_leveled_up)

func _refresh() -> void:
	var ps := GameState.local_player()
	if ps == null:
		return

	for i in _slot_nodes.size():
		var unit_id := ps.shop_slots[i] if i < ps.shop_slots.size() else ""
		_slot_nodes[i].set_unit(unit_id)
		_slot_nodes[i].set_affordable(ps.gold >= _get_unit_cost(unit_id))

	_gold_label.text = "%dg" % ps.gold
	_level_label.text = "Lv.%d (%d/%d xp)" % [ps.level, ps.xp, EconomyManager.xp_needed(ps.level)]

	var can_reroll := ps.gold >= DataLoader.economy.get("reroll_cost", 2) or ps.free_rerolls_remaining > 0
	_reroll_btn.disabled = not can_reroll
	_xp_btn.disabled = ps.gold < DataLoader.economy.get("xp_buy_cost", 4)

func _get_unit_cost(unit_id: String) -> int:
	var eid := unit_id.substr(7) if unit_id.begins_with("LOCKED:") else unit_id
	if eid == "" or not DataLoader.units.has(eid):
		return 999
	return DataLoader.units[eid].cost

func _on_purchase_requested(slot_idx: int) -> void:
	ShopManager.buy_unit(GameState.local_player_id, slot_idx)
	_refresh()

func _on_reroll() -> void:
	ShopManager.reroll_shop(GameState.local_player_id)

func _on_buy_xp() -> void:
	EconomyManager.buy_xp(GameState.local_player_id)
	_refresh()

func _on_shop_refreshed(player_id: int) -> void:
	if player_id == GameState.local_player_id:
		_refresh()

func _on_gold_changed(player_id: int, _amount: int) -> void:
	if player_id == GameState.local_player_id:
		_refresh()

func _on_player_leveled_up(player_id: int, _level: int) -> void:
	if player_id == GameState.local_player_id:
		_refresh()
