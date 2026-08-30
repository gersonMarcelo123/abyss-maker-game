class_name AccessoryPresentation
extends RefCounted

static func icon_for(accessory: Dictionary) -> String:
	match str(accessory.get("type", "")):
		"Runa": return "🔹"
		"Manual": return "📘"
		"Pulsera": return "📿"
		"Lente": return "🔍"
		"Anillo": return "💍"
		_: return "▫"

static func stat_name(key: String) -> String:
	var names := {"physical_damage":"Daño físico", "magic_damage":"Daño mágico", "strength":"Fuerza", "intelligence":"Inteligencia", "agility":"Agilidad", "resistance":"Resistencia", "armor":"Armadura", "move_speed_percent":"Vel. movimiento", "cooldown_reduction_percent":"CDR", "healing_bonus_percent":"Bono curación", "ranged_attack_range":"Rango ataque", "cast_range":"Rango casteo"}
	return names.get(key, key)

static func format_stat(key: String, value: Variant) -> String:
	var suffix := "%" if key.ends_with("percent") else ""
	return "%s +%s%s" % [stat_name(key), str(value), suffix]

static func tier_of(accessory: Dictionary) -> int:
	return clampi(int(accessory.get("tier", 1)), 1, 5)

static func tier_color(accessory: Dictionary) -> Color:
	match tier_of(accessory):
		2: return Color(0.25, 0.9, 0.35) # verde
		3: return Color(0.28, 0.55, 1.0) # azul
		4: return Color(0.72, 0.35, 0.95) # violeta
		5: return Color(1.0, 0.58, 0.15) # naranja
		_: return Color(0.7, 0.7, 0.7) # gris

static func tier_slot_style(accessory: Dictionary, highlighted: bool = false, unavailable: bool = false) -> StyleBoxFlat:
	var tier_tint := tier_color(accessory)
	var style := StyleBoxFlat.new()
	var brightness := 0.34 if highlighted else 0.22
	if unavailable:
		brightness = 0.12
	style.bg_color = Color(tier_tint.r * brightness, tier_tint.g * brightness, tier_tint.b * brightness, 0.98)
	style.border_color = tier_tint.darkened(0.35) if unavailable else tier_tint
	style.set_border_width_all(2 if highlighted else 1)
	style.set_corner_radius_all(3)
	return style
