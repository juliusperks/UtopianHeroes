## Unit — the universal unit node used for both player and AI units in combat.
## All units share this scene regardless of type; stats come from UnitData + instance data.
extends Area2D

signal died(unit_node: Node)

const HEX_SIZE := 64.0   # used for range calculations

# ── Identity ──────────────────────────────────────────────────────────────────
var unit_id: String = ""
var instance_id: String = ""
var instance_data: Dictionary = {}
var team: int = 0   # 0 = local player, 1 = opponent

# ── Loaded from UnitData + star scaling ──────────────────────────────────────
var unit_data: UnitData = null
var star: int = 1

# ── Live combat stats (reset each battle) ────────────────────────────────────
var max_hp: float = 0.0
var current_hp: float = 0.0
var current_atk: float = 0.0
var current_atk_speed: float = 0.0   # attacks per second
var current_armor: float = 0.0
var current_mr: float = 0.0
var current_mana: int = 0
var mana_max: int = 0
var atk_range: int = 1
var is_alive: bool = true

# Attack cooldown
var _atk_cooldown: float = 0.0

# Status effects
var _status_effects: StatusEffectManager

# Item effects cache (set during battle start)
var _lifesteal_ratio: float = 0.0
var _revive_hp: float = 0.0
var _has_revived: bool = false
var mr_shred_flat: float = 0.0

# Trait / item buff stacks (e.g. rageblade)
var _rage_stacks: int = 0

# Visual nodes (created in _ready)
var _sprite: Sprite2D
var _hp_bar: ProgressBar
var _mana_bar: ProgressBar
var _name_label: Label
var _star_label: Label

# Ability
var _ability: UnitAbility = null

func _ready() -> void:
	_build_visuals()
	_status_effects = StatusEffectManager.new()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _build_visuals() -> void:
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 28.0
	collision.shape = shape
	add_child(collision)

	_sprite = Sprite2D.new()
	_sprite.scale = Vector2(0.4, 0.4)
	add_child(_sprite)

	# HP bar
	_hp_bar = ProgressBar.new()
	_hp_bar.size = Vector2(56.0, 8.0)
	_hp_bar.position = Vector2(-28.0, -44.0)
	_hp_bar.min_value = 0.0
	_hp_bar.max_value = 1.0
	_hp_bar.value = 1.0
	_hp_bar.modulate = Color.GREEN
	add_child(_hp_bar)

	# Mana bar
	_mana_bar = ProgressBar.new()
	_mana_bar.size = Vector2(56.0, 5.0)
	_mana_bar.position = Vector2(-28.0, -35.0)
	_mana_bar.min_value = 0.0
	_mana_bar.max_value = 1.0
	_mana_bar.value = 0.0
	_mana_bar.modulate = Color.DODGER_BLUE
	add_child(_mana_bar)

	# Name label
	_name_label = Label.new()
	_name_label.text = ""
	_name_label.add_theme_font_size_override("font_size", 10)
	_name_label.position = Vector2(-28.0, 30.0)
	_name_label.size = Vector2(56.0, 16.0)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.visible = false
	add_child(_name_label)

	# Star label
	_star_label = Label.new()
	_star_label.add_theme_font_size_override("font_size", 12)
	_star_label.position = Vector2(-20.0, -60.0)
	_star_label.size = Vector2(40.0, 16.0)
	_star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_star_label)

# ── Initialization ────────────────────────────────────────────────────────────

func init_from_data(inst_data: Dictionary) -> void:
	instance_data = inst_data
	instance_id   = inst_data.get("instance_id", "")
	unit_id       = inst_data.get("unit_id", "")
	star          = inst_data.get("star", 1)
	unit_data     = DataLoader.units.get(unit_id, null)

	if unit_data == null:
		push_error("[Unit] Unknown unit_id: %s" % unit_id)
		return

	_name_label.text = unit_data.display_name
	_star_label.text = _star_text(star)

	# Try to load sprite
	if ResourceLoader.exists(unit_data.sprite_path):
		_sprite.texture = load(unit_data.sprite_path)

	# Set ability
	_ability = _create_ability()

## Called by BattleSystem before combat starts. Applies trait and item bonuses.
func setup_combat_stats(synergy_bonuses: Dictionary) -> void:
	if unit_data == null:
		return

	var hp_pct: float      = float(synergy_bonuses.get("hp_pct", 0))
	var atk_pct: float     = float(synergy_bonuses.get("atk_pct", 0))
	var armor_flat: float  = float(synergy_bonuses.get("armor_flat", 0))
	var mr_flat: float     = float(synergy_bonuses.get("mr_flat", 0))
	var speed_pct: float   = float(synergy_bonuses.get("atk_speed_pct", 0))
	mr_shred_flat          = float(synergy_bonuses.get("mr_shred_flat", 0))

	max_hp         = unit_data.get_stat_at_star(unit_data.base_hp, star) * (1.0 + hp_pct / 100.0)
	current_hp     = max_hp
	current_atk    = unit_data.get_stat_at_star(unit_data.base_atk, star) * (1.0 + atk_pct / 100.0)
	current_armor  = unit_data.base_armor + armor_flat
	current_mr     = unit_data.base_mr + mr_flat
	current_atk_speed = unit_data.atk_speed * (1.0 + speed_pct / 100.0)
	atk_range      = unit_data.atk_range
	mana_max       = unit_data.ability_mana_cost
	current_mana   = synergy_bonuses.get("mana_flat", 0)

	# Apply items
	_apply_item_bonuses(instance_data.get("items", []))

	_atk_cooldown = 0.0
	is_alive = true
	_has_revived = false
	_rage_stacks = 0

	_update_bars()

func _apply_item_bonuses(item_ids: Array) -> void:
	for item_id in item_ids:
		var item: ItemData = DataLoader.items.get(item_id, null)
		if item == null:
			continue
		max_hp         += item.hp_bonus
		current_hp     += item.hp_bonus
		current_atk    += item.atk_bonus
		current_armor  += item.armor_bonus
		current_mr     += item.mr_bonus
		current_atk_speed += item.atk_speed_bonus
		current_mana   += item.mana_bonus
		# Cache special effects
		match item.effect_id:
			"lifesteal":
				_lifesteal_ratio = item.effect_value
			"revive":
				_revive_hp = item.effect_value

# ── Battle tick (called by BattleSystem every 0.1 seconds) ───────────────────

func battle_tick(delta: float, allies: Array, enemies: Array) -> void:
	if not is_alive:
		return

	# Tick status effects
	var expired := _status_effects.tick(delta)
	if _status_effects.is_stunned():
		return

	# HP regen (Shepherd trait)
	var regen_pct: float = 0.0  # set during setup from synergy bonuses
	if regen_pct > 0.0:
		receive_heal(max_hp * (regen_pct / 100.0) * delta)

	# Attack logic
	_atk_cooldown -= delta
	if _atk_cooldown <= 0.0:
		var target := TargetSelector.get_target(self, enemies)
		if target == null:
			return  # No enemies left

		var speed_mult := _status_effects.atk_speed_multiplier()
		var effective_speed := current_atk_speed * speed_mult
		_atk_cooldown = 1.0 / maxf(effective_speed, 0.1)

		if TargetSelector.is_in_range(self, target, atk_range, HEX_SIZE):
			_do_attack(target)
		else:
			# Move toward target
			var step := HEX_SIZE * 0.3  # pixels per tick
			global_position = TargetSelector.step_toward(global_position, target.global_position, step)

	# Ability logic — fire when mana is full
	if current_mana >= mana_max and _ability != null:
		current_mana = 0
		_ability.execute(allies, enemies)
		_update_bars()

func _do_attack(target: Node) -> void:
	var final_dmg := DamageCalculator.physical(current_atk, target.current_armor)
	target.take_damage(final_dmg, true)

	# Mana gain on attack
	current_mana += 10
	current_mana = mini(current_mana, mana_max)

	# Rageblade stack
	if _rage_stacks < 8:
		_rage_stacks += 1
		current_atk_speed *= 1.05

	_update_bars()

# ── Damage / Healing ──────────────────────────────────────────────────────────

func take_damage(amount: float, is_physical: bool) -> void:
	if not is_alive:
		return
	current_hp -= amount
	# Lifesteal: the attacker heals (handled by the attacker calling this)
	if current_hp <= 0.0:
		_on_death()
	_update_bars()

func receive_heal(amount: float) -> void:
	current_hp = minf(current_hp + amount, max_hp)
	_update_bars()

func apply_buff(effect_id: String, value: float, duration: float) -> void:
	_status_effects.apply(effect_id, value, duration)

func get_ability_dmg_bonus() -> float:
	# Returns total ability damage % bonus from items (trait bonuses applied in setup_combat_stats)
	var bonus := 0.0
	for item_id in instance_data.get("items", []):
		var item: ItemData = DataLoader.items.get(item_id, null)
		if item != null:
			bonus += item.effect_value if item.effect_id == "ability_dmg_pct" else 0.0
	return bonus

func _on_death() -> void:
	# Guardian Angel revive
	if _revive_hp > 0.0 and not _has_revived:
		_has_revived = true
		current_hp = _revive_hp
		_update_bars()
		return

	is_alive = false
	modulate = Color(0.5, 0.5, 0.5, 0.5)
	died.emit(self)
	SignalBus.unit_died.emit(instance_id, team)

# ── Visuals ───────────────────────────────────────────────────────────────────

func _update_bars() -> void:
	if max_hp > 0.0:
		_hp_bar.value = current_hp / max_hp
	_mana_bar.value = float(current_mana) / float(mana_max) if mana_max > 0 else 0.0

	# Color HP bar by percentage
	var hp_ratio := current_hp / max_hp if max_hp > 0.0 else 0.0
	if hp_ratio > 0.5:
		_hp_bar.modulate = Color.GREEN
	elif hp_ratio > 0.25:
		_hp_bar.modulate = Color.YELLOW
	else:
		_hp_bar.modulate = Color.RED

func _star_text(s: int) -> String:
	match s:
		2: return "★★"
		3: return "★★★"
		_: return "★"

func _on_mouse_entered() -> void:
	_name_label.visible = true
	if unit_data != null:
		SignalBus.show_unit_tooltip.emit(unit_data, instance_data)

func _on_mouse_exited() -> void:
	_name_label.visible = false
	SignalBus.hide_unit_tooltip.emit()

# ── Ability factory ───────────────────────────────────────────────────────────

func _create_ability() -> UnitAbility:
	if unit_data == null or unit_data.ability_id == "":
		return null
	var ability_id := unit_data.ability_id
	var script_path := "res://scenes/units/abilities/%s.gd" % ability_id
	if ResourceLoader.exists(script_path):
		var script: GDScript = load(script_path)
		return script.new(unit_data, self, star)
	# Fallback: generic ability that just deals magic damage to nearest enemy
	return _GenericMagicAbility.new(unit_data, self, star)

# ── Generic fallback ability ──────────────────────────────────────────────────
class _GenericMagicAbility extends UnitAbility:
	func execute(allies: Array, enemies: Array) -> void:
		var target := TargetSelector.get_target(caster, enemies)
		if target != null:
			deal_magic_damage(target, get_value())
