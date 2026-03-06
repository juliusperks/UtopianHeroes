## PlayerList — shows all 8 players' HP and alive/dead status.
## All sizes are derived from viewport dimensions at startup.
extends PanelContainer

var _rows: Array = []

func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	custom_minimum_size = Vector2(int(vp.x * 0.109), int(vp.y * 0.324))  # 210×350 @ 1080p
	_build_ui()
	SignalBus.hp_changed.connect(_on_hp_changed)
	SignalBus.player_eliminated.connect(_on_player_eliminated)

func _build_ui() -> void:
	var vp  := get_viewport().get_visible_rect().size
	var vw  := vp.x
	var vh  := vp.y

	var pad      := int(vh * 0.009)    # 10px
	var sep      := int(vh * 0.007)    # 8px between rows
	var fnt_hdr  := int(vh * 0.017)    # 18px header
	var bar_w    := int(vw * 0.068)    # 130px HP bar
	var bar_h    := int(vh * 0.019)    # 20px HP bar
	var fnt_hp   := int(vh * 0.014)    # 15px HP number
	var hp_lbl_w := int(vw * 0.019)    # 36px HP label min width
	var fnt_name := int(vh * 0.014)    # 15px player name

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   pad)
	margin.add_theme_constant_override("margin_right",  pad)
	margin.add_theme_constant_override("margin_top",    pad)
	margin.add_theme_constant_override("margin_bottom", pad)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", sep)
	margin.add_child(vbox)

	var header := Label.new()
	header.text = "Players"
	header.add_theme_font_size_override("font_size", fnt_hdr)
	header.add_theme_constant_override("outline_size", 2)
	header.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	header.modulate = Color.GOLD
	vbox.add_child(header)

	for i in GameState.PLAYER_COUNT:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(vw * 0.003))
		vbox.add_child(row)

		var hp_bar := ProgressBar.new()
		hp_bar.custom_minimum_size = Vector2(bar_w, bar_h)
		hp_bar.min_value = 0.0
		hp_bar.max_value = DataLoader.economy.get("starting_hp", 100)
		hp_bar.value = DataLoader.economy.get("starting_hp", 100)
		hp_bar.modulate = Color.LIME_GREEN
		row.add_child(hp_bar)

		var hp_label := Label.new()
		hp_label.add_theme_font_size_override("font_size", fnt_hp)
		hp_label.text = "100"
		hp_label.modulate = Color.WHITE
		hp_label.custom_minimum_size = Vector2(hp_lbl_w, 0)
		row.add_child(hp_label)

		var name_label := Label.new()
		name_label.add_theme_font_size_override("font_size", fnt_name)
		name_label.text = "Player %d" % i if i != GameState.local_player_id else "You"
		name_label.modulate = Color.AQUA if i == GameState.local_player_id else Color.WHITE
		row.add_child(name_label)

		_rows.append({"row": row, "hp_bar": hp_bar, "hp_label": hp_label})

func _on_hp_changed(player_id: int, new_hp: int) -> void:
	if player_id >= _rows.size():
		return
	var row_data: Dictionary = _rows[player_id]
	row_data["hp_label"].text = "%d" % maxi(0, new_hp)
	row_data["hp_bar"].value = maxi(0, new_hp)
	var ratio := float(new_hp) / float(DataLoader.economy.get("starting_hp", 100))
	if ratio > 0.5:
		row_data["hp_bar"].modulate = Color.LIME_GREEN
	elif ratio > 0.25:
		row_data["hp_bar"].modulate = Color.YELLOW
	else:
		row_data["hp_bar"].modulate = Color.TOMATO

func _on_player_eliminated(player_id: int) -> void:
	if player_id >= _rows.size():
		return
	var row_data: Dictionary = _rows[player_id]
	row_data["row"].modulate = Color(0.4, 0.4, 0.4, 0.6)
	row_data["hp_label"].text = "✗"
