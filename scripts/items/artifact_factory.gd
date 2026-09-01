class_name ArtifactFactory
extends RefCounted

const MAIN_STATS := {
	"Runa": ["strength", "intelligence", "agility", "resistance", "physical_damage", "magic_damage"],
	"Libreta": ["magic_damage", "physical_damage", "armor", "attack_speed", "strength", "intelligence", "agility", "resistance"],
	"Pulsera": ["attack_speed", "ranged_attack_range", "move_speed_percent", "max_health", "max_mana"],
	"Lente": ["magic_damage", "physical_damage", "physical_damage", "magic_damage"],
	"Anillo": ["max_health", "max_mana"],
}
const SECONDARY_STATS: Array[String] = ["strength", "intelligence", "agility", "resistance", "physical_damage", "magic_damage", "armor", "attack_speed", "ranged_attack_range", "move_speed_percent", "max_health", "max_mana"]

static func create(type: String) -> Dictionary:
	var tier := randi_range(1, 5)
	var main_pool: Array = MAIN_STATS.get(type, SECONDARY_STATS)
	var main_stat: String = str(main_pool.pick_random())
	var bonuses: Dictionary = {main_stat: _primary_value(main_stat, tier)}
	var candidates: Array[String] = SECONDARY_STATS.duplicate()
	candidates.erase(main_stat)
	for secondary_index in range(tier - 1):
		if candidates.is_empty(): break
		var stat: String = candidates.pick_random()
		candidates.erase(stat)
		bonuses[stat] = _secondary_value(stat, tier, secondary_index)
	var id := "%s_%d_%d" % [type.to_lower(), Time.get_ticks_msec(), randi_range(1000, 9999)]
	return {"id": id, "name": "%s tier %d" % [type, tier], "type": type, "tier": tier, "bonuses": bonuses}

static func _primary_value(stat: String, tier: int) -> float:
	var multiplier := 1.0
	if stat == "max_health" or stat == "max_mana": multiplier = 5.0
	elif stat == "ranged_attack_range": multiplier = 4.0
	elif stat == "attack_speed": multiplier = 0.04
	elif stat == "move_speed_percent": multiplier = 1.5
	return (3.0 + (tier - 1) * 2.0) * multiplier

static func _secondary_value(stat: String, _tier: int, secondary_index: int) -> float:
	var multiplier := 1.0
	if stat == "max_health" or stat == "max_mana": multiplier = 5.0
	elif stat == "ranged_attack_range": multiplier = 4.0
	elif stat == "attack_speed": multiplier = 0.04
	elif stat == "move_speed_percent": multiplier = 1.5
	return (1.0 + secondary_index * 0.5) * multiplier
