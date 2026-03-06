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
const MAIN_BG_PATH := "res://assets/art/backgrounds/battlefield_bg.png"
const MAIN_BG_SCALE  := Vector2(0.43, 0.43)
# World-space center of the 7×4 hex grid (world-local, independent of world scale):
#   board offset (-240,-280) + grid half-size (240, 96) = (0, -184)
const MAIN_BG_OFFSET := Vector2(0.0, -184.0)
# Scales the board + battle arena 40% larger on the 1920×1080 canvas.
# CanvasLayer nodes (shop, HUD, synergy, player list) are unaffected by this scale.
const WORLD_SCALE    := Vector2(1.4, 1.4)

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
	var vp := get_viewport().get_visible_rect().size
	var vw := vp.x
	var vh := vp.y

	# Base fallback backdrop behind the world.
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.1, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Game world node — centred horizontally, shifted up vertically so the
	# board+bench occupies the upper ~56% of the screen and the shop panel
	# sits permanently in the lower ~30%.
	# Math: board top = world_y + (-312)*scale ≥ HUD_h (68px)
	#       bench bottom = world_y + 60*scale ≤ shop_y (vh*0.565)
	#       → world_y ≈ vh*0.475 centres the play area in the available zone.
	var world := Node2D.new()
	world.position = Vector2(vw * 0.5, vh * 0.475)
	world.scale    = WORLD_SCALE
	add_child(world)

	# Battlefield art is positioned in world space so it aligns with board coordinates.
	if ResourceLoader.exists(MAIN_BG_PATH):
		var bg_sprite := Sprite2D.new()
		bg_sprite.texture = load(MAIN_BG_PATH)
		bg_sprite.centered = true
		bg_sprite.position = MAIN_BG_OFFSET
		bg_sprite.scale = MAIN_BG_SCALE
		world.add_child(bg_sprite)

	# Board — offset centres the 7×4 grid around world origin.
	# The exact pixel offsets preserve hex alignment regardless of viewport size
	# because the board lives in world space (scaled by WORLD_SCALE).
	_board = BoardScene.instantiate()
	_board.position = Vector2(-240.0, -280.0)
	world.add_child(_board)

	# Battle arena — same world offset as the board so hex positions align exactly.
	_battle_arena = BattleArenaScene.instantiate()
	_battle_arena.position = Vector2(-240.0, -280.0)
	_battle_arena.visible = false
	world.add_child(_battle_arena)

	# HUD (CanvasLayer)
	_hud = HUDScene.instantiate()
	add_child(_hud)

	# Result banner
	_result_banner = RoundResultBannerScene.instantiate()
	add_child(_result_banner)

	# Unit info popup + trait info popup + advisor offer popup (shared CanvasLayer, always on top)
	var popup_layer := CanvasLayer.new()
	add_child(popup_layer)
	_unit_info_popup = UnitInfoPopupScene.instantiate()
	popup_layer.add_child(_unit_info_popup)
	var trait_popup: Node = load("res://scenes/ui/TraitInfoPopup.gd").new()
	popup_layer.add_child(trait_popup)
	var advisor_popup: Node = load("res://scenes/ui/AdvisorOfferPopup.gd").new()
	popup_layer.add_child(advisor_popup)

	# Shop panel — permanent bottom bar, always visible.
	# Bench bottom lands at roughly vh*0.555; shop starts 8px below that.
	var shop_layer := CanvasLayer.new()
	add_child(shop_layer)
	_shop_panel = ShopPanelScene.instantiate()
	_shop_panel.position = Vector2(vw * 0.297, vh * 0.565)
	shop_layer.add_child(_shop_panel)

	# Synergy panel — left side, below HUD bar (HUD bar ≈ vh*0.063)
	var ui_layer := CanvasLayer.new()
	add_child(ui_layer)
	_synergy_panel = SynergyPanelScene.instantiate()
	_synergy_panel.position = Vector2(4, vh * 0.067)
	ui_layer.add_child(_synergy_panel)

	# Player list — right side, below HUD bar.
	# Position x = vw - panel_min_width - 4px margin so it hugs the right edge.
	var pl_w := int(vw * 0.109) + 4   # panel min width + margin
	_player_list = PlayerListScene.instantiate()
	_player_list.position = Vector2(vw - pl_w, vh * 0.067)
	ui_layer.add_child(_player_list)

	# Listen for phase changes to swap board / arena visibility
	SignalBus.phase_changed.connect(_on_phase_changed)
	SignalBus.game_over.connect(_on_game_over)

func _start_game() -> void:
	RoundManager.start_game()

func _on_phase_changed(phase: int) -> void:
	# Shop + bench are always visible — players plan next round during combat.
	# Board manages its own hex/unit visibility internally via _set_board_visible().
	match phase:
		RoundManager.Phase.COMBAT:
			_battle_arena.visible = true
		RoundManager.Phase.PREP, RoundManager.Phase.RESULTS:
			_battle_arena.visible = false
		RoundManager.Phase.GAME_OVER:
			_battle_arena.visible = false
			_shop_panel.visible = false

func _on_game_over(winner_id: int) -> void:
	var msg := "You Win! 🎉" if winner_id == GameState.local_player_id else "Game Over!"
	SignalBus.show_message.emit(msg, 10.0)
	# After 5 seconds, return to main menu
	await get_tree().create_timer(5.0).timeout
	get_tree().change_scene_to_file("res://scenes/menus/MainMenu.tscn")
