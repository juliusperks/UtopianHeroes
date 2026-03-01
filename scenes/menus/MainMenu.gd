## MainMenu — entry point. Starts a new game on button press.
extends Control

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "UtopianHeroes"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color.GOLD
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "A Utopia-Game themed auto-battler"
	sub.add_theme_font_size_override("font_size", 18)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(0.7, 0.85, 1.0)
	vbox.add_child(sub)

	var play_btn := Button.new()
	play_btn.text = "Play (vs AI)"
	play_btn.custom_minimum_size = Vector2(200, 50)
	play_btn.pressed.connect(_on_play_pressed)
	vbox.add_child(play_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Quit"
	quit_btn.custom_minimum_size = Vector2(200, 50)
	quit_btn.pressed.connect(func(): get_tree().quit())
	vbox.add_child(quit_btn)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
