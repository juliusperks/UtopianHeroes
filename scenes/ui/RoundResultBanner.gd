## RoundResultBanner — brief banner shown at the end of a combat round.
extends CanvasLayer

var _banner: Label
var _anim_timer: float = 0.0

func _ready() -> void:
	_banner = Label.new()
	_banner.add_theme_font_size_override("font_size", 32)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.position = Vector2(490, 310)
	_banner.size = Vector2(300, 60)
	_banner.visible = false
	add_child(_banner)

	SignalBus.combat_ended.connect(_on_combat_ended)

func _process(delta: float) -> void:
	if _anim_timer > 0.0:
		_anim_timer -= delta
		_banner.modulate.a = minf(1.0, _anim_timer * 2.0)
		if _anim_timer <= 0.0:
			_banner.visible = false

func _on_combat_ended(winner_id: int, _loser_id: int, damage: int) -> void:
	if winner_id == GameState.local_player_id:
		_show("VICTORY!", Color.LIME_GREEN)
	else:
		_show("DEFEAT  -%d HP" % damage, Color.TOMATO)

func _show(text: String, color: Color) -> void:
	_banner.text = text
	_banner.modulate = color
	_banner.visible = true
	_anim_timer = 3.0
