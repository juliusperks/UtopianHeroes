## TraitInfoPopup — hover tooltip for synergy entries in the SynergyPanel.
## Shows the trait description and a per-tier bonus breakdown with the active
## tier highlighted and annotated.
extends PanelContainer

var _name_label: Label
var _type_label: Label
var _desc_label: Label
var _tiers_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(230, 80)
	visible = false
	z_index = 100
	_build_ui()
	SignalBus.show_trait_tooltip.connect(_on_show)
	SignalBus.hide_trait_tooltip.connect(_on_hide)

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.modulate = Color.GOLD
	vbox.add_child(_name_label)

	_type_label = Label.new()
	_type_label.add_theme_font_size_override("font_size", 10)
	_type_label.modulate = Color(0.65, 0.65, 0.65)
	vbox.add_child(_type_label)

	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override("font_size", 11)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_desc_label.custom_minimum_size = Vector2(210, 0)
	vbox.add_child(_desc_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	_tiers_label = Label.new()
	_tiers_label.add_theme_font_size_override("font_size", 11)
	_tiers_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_tiers_label)

func _on_show(tdata: TraitData, count: int, active_tier: int) -> void:
	_name_label.text = tdata.display_name
	_type_label.text = "Origin trait" if tdata.trait_type == "origin" else "Class trait"
	_desc_label.text = tdata.description

	var lines := PackedStringArray()
	for i in tdata.thresholds.size():
		var threshold: int = tdata.thresholds[i]
		var bonus_dict: Dictionary = {}
		if i < tdata.tiers.size():
			bonus_dict = tdata.tiers[i].get("bonuses", {})
		var bonus_str := _format_bonuses(bonus_dict)
		var pip: String
		if i + 1 < active_tier:
			pip = "●"
		elif i + 1 == active_tier:
			pip = "●"
		else:
			pip = "○"
		var line := "%s %d:  %s" % [pip, threshold, bonus_str]
		if i + 1 == active_tier:
			line += "  ◄ active"
		lines.append(line)
	# Show how many more units are needed for the next tier.
	var next_threshold := _next_threshold(tdata, active_tier)
	if next_threshold > 0:
		lines.append("Need %d more for next tier" % (next_threshold - count))
	_tiers_label.text = "\n".join(lines)

	_reposition()
	visible = true

func _on_hide() -> void:
	visible = false

func _process(_delta: float) -> void:
	if visible:
		_reposition()

func _reposition() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	var mouse := get_viewport().get_mouse_position()
	var pos := mouse + Vector2(16.0, 8.0)
	pos.x = minf(pos.x, vp_size.x - size.x - 4.0)
	pos.y = minf(pos.y, vp_size.y - size.y - 4.0)
	global_position = pos

func _next_threshold(tdata: TraitData, active_tier: int) -> int:
	if active_tier < tdata.thresholds.size():
		return tdata.thresholds[active_tier]
	return 0  # already at max tier

func _format_bonuses(bonuses: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in bonuses:
		var val = bonuses[key]
		match key:
			"hp_pct":          parts.append("+%d%% HP" % val)
			"atk_pct":         parts.append("+%d%% ATK" % val)
			"armor_flat":      parts.append("+%d Armor" % val)
			"mr_flat":         parts.append("+%d MR" % val)
			"atk_speed_pct":   parts.append("+%d%% ATK Spd" % val)
			"dmg_amp_pct":     parts.append("+%d%% Damage" % val)
			"gold_per_round":  parts.append("+%d Gold/Round" % val)
			"ability_dmg_pct": parts.append("+%d%% Abil Dmg" % val)
			"dodge_pct":       parts.append("+%d%% Dodge" % val)
			"heal_on_kill":    parts.append("+%d Heal on Kill" % val)
			"mr_shred_flat":   parts.append("-%d enemy MR" % val)
	if parts.is_empty():
		return "(no bonus)"
	return ", ".join(parts)
