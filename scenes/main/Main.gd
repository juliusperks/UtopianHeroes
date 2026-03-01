## Main — root scene that wires everything together and starts the game.
extends Node

const BoardScene      := preload("res://scenes/board/Board.tscn")
const BattleArenaScene := preload("res://scenes/battle/BattleArena.tscn")
const ShopPanelScene  := preload("res://scenes/shop/ShopPanel.tscn")
const HUDScene        := preload("res://scenes/ui/HUD.tscn")
const SynergyPanelScene := preload("res://scenes/ui/SynergyPanel.tscn")
const PlayerListScene := preload("res://scenes/ui/PlayerList.tscn")
const UnitInfoPopupScene := preload("res://scenes/ui/UnitInfoPopup.tscn")
const RoundResultBannerScene := preload("res://scenes/ui/RoundResultBanner.tscn")

var _board: Node
var _battle_arena: Node
var _shop_panel: Node
var _hud: Node
var _synergy_panel: Node
var _player_list: Node
var _unit_info_popup: Node
var _result_banner: Node

func _ready() -> void:
	_build_scene()
	_start_game()

func _build_scene() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.12, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Game world node (2D space for board + battle)
	var world := Node2D.new()
	world.position = Vector2(640, 360)  # center of 1280x720
	add_child(world)

	# Board — offset to center the 7×4 grid on screen (world origin is at 640, 360)
	# Board bounding box: x≈0..481, y≈0..224; bench adds y up to ~376
	# This places board top-left at screen (400, 80), bench bottom at ~(400, 456)
	_board = BoardScene.instantiate()
	_board.position = Vector2(-240.0, -280.0)
	world.add_child(_board)

	# Battle arena (overlaid, visible only during combat)
	_battle_arena = BattleArenaScene.instantiate()
	_battle_arena.visible = false
	world.add_child(_battle_arena)

	# HUD (CanvasLayer)
	_hud = HUDScene.instantiate()
	add_child(_hud)

	# Result banner
	_result_banner = RoundResultBannerScene.instantiate()
	add_child(_result_banner)

	# Unit info popup (CanvasLayer)
	var popup_layer := CanvasLayer.new()
	add_child(popup_layer)
	_unit_info_popup = UnitInfoPopupScene.instantiate()
	popup_layer.add_child(_unit_info_popup)

	# Shop panel — bottom of screen
	# ShopSlot min size is 110×150; 5 slots + padding ≈ 590×218px total panel size.
	# Placed at absolute y=495 so it fits within the 720px viewport (ends ~y=713).
	var shop_layer := CanvasLayer.new()
	add_child(shop_layer)
	_shop_panel = ShopPanelScene.instantiate()
	_shop_panel.position = Vector2(0, 495)
	shop_layer.add_child(_shop_panel)

	# Synergy panel — left side
	var ui_layer := CanvasLayer.new()
	add_child(ui_layer)
	_synergy_panel = SynergyPanelScene.instantiate()
	_synergy_panel.position = Vector2(4, 50)
	ui_layer.add_child(_synergy_panel)

	# Player list — right side
	_player_list = PlayerListScene.instantiate()
	_player_list.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_player_list.position = Vector2(1120, 50)
	ui_layer.add_child(_player_list)

	# Listen for phase changes to swap board / arena visibility
	SignalBus.phase_changed.connect(_on_phase_changed)
	SignalBus.game_over.connect(_on_game_over)

func _start_game() -> void:
	RoundManager.start_game()

func _on_phase_changed(phase: int) -> void:
	match phase:
		RoundManager.Phase.PREP:
			_board.visible = true
			_battle_arena.visible = false
			_shop_panel.visible = true
		RoundManager.Phase.COMBAT:
			_board.visible = false
			_battle_arena.visible = true
			_shop_panel.visible = false
		RoundManager.Phase.RESULTS:
			_board.visible = true
			_battle_arena.visible = false
			_shop_panel.visible = false
		RoundManager.Phase.GAME_OVER:
			pass

func _on_game_over(winner_id: int) -> void:
	var msg := "You Win! 🎉" if winner_id == GameState.local_player_id else "Game Over!"
	SignalBus.show_message.emit(msg, 10.0)
	# After 5 seconds, return to main menu
	await get_tree().create_timer(5.0).timeout
	get_tree().change_scene_to_file("res://scenes/menus/MainMenu.tscn")
