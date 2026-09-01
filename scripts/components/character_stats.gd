## Estadísticas y etiquetas de combate compartidas por todos los personajes.
class_name CharacterStats
extends Node

## La armadura solo reduce PHYSICAL; MAGICAL queda separado para una futura resistencia mágica.
enum DamageType { PHYSICAL, MAGICAL, TRUE }
## Solo REDUCIBLE_ABILITY recibe CDR. Objetos y sistemas usan etiquetas fijas.
enum CooldownTag { REDUCIBLE_ABILITY, FIXED_ITEM, FIXED_SYSTEM }

@export_group("Atributos principales")
@export var strength: int = 0:
	set(value):
		strength = max(value, 0)
		_recalculate()
@export var intelligence: int = 0:
	set(value):
		intelligence = max(value, 0)
		_recalculate()
@export var agility: int = 0:
	set(value):
		agility = max(value, 0)
		_recalculate()
@export var resistance: int = 0:
	set(value):
		resistance = max(value, 0)
		_recalculate()

@export_group("Base (antes de atributos, buffs e ítems)")
@export var base_max_health: float = 100.0
@export var base_max_mana: float = 100.0
@export var base_attack_speed: float = 1.0
@export var base_physical_damage: float = 10.0
@export var base_magic_damage: float = 0.0
@export var base_move_speed: float = 160.0
@export var base_armor: float = 0.0

@export_group("Balance de armadura")
## K=100: 100 armadura = 50%; 200 = 66.7%; nunca llega al 100%.
@export var armor_constant: float = 100.0

var physical_damage_bonus: float = 0.0
var magic_damage_bonus: float = 0.0
var movement_speed_bonus_percent: float = 0.0
var cooldown_reduction_percent: float = 0.0
var healing_bonus_percent: float = 0.0
var ranged_attack_range_bonus: float = 0.0
var cast_range_bonus: float = 0.0
var armor_bonus: float = 0.0
## Bonos recalculados desde los artefactos equipados (inventario activo).
var item_strength: int = 0
var item_intelligence: int = 0
var item_agility: int = 0
var item_resistance: int = 0
var item_physical_damage_bonus: float = 0.0
var item_magic_damage_bonus: float = 0.0
var item_movement_speed_bonus_percent: float = 0.0
var item_cooldown_reduction_percent: float = 0.0
var item_healing_bonus_percent: float = 0.0
var item_ranged_attack_range_bonus: float = 0.0
var item_cast_range_bonus: float = 0.0
var item_armor_bonus: float = 0.0
var accessory_bonuses: Dictionary = {}

var max_health: float
var max_mana: float
var attack_speed: float
var physical_damage: float
var magic_damage: float
var movement_speed: float
var armor: float
var armor_damage_reduction: float
var ability_cooldown_multiplier: float = 1.0
var health_regen: float
var mana_regen: float

var current_health: float
var current_mana: float

signal stats_changed
signal health_changed(current: float, maximum: float)
signal mana_changed(current: float, maximum: float)
## Expone el valor final para UI, efectos de impacto o registro de combate.
signal damage_received(raw_damage: float, final_damage: float, damage_type: int)
signal died

func _ready() -> void:
	_recalculate()
	current_health = max_health
	current_mana = max_mana
	health_changed.emit(current_health, max_health)
	mana_changed.emit(current_mana, max_mana)

func _process(delta: float) -> void:
	if health_regen > 0.0 and current_health < max_health:
		current_health = min(current_health + health_regen * delta, max_health)
		health_changed.emit(current_health, max_health)
	if mana_regen > 0.0 and current_mana < max_mana:
		current_mana = min(current_mana + mana_regen * delta, max_mana)
		mana_changed.emit(current_mana, max_mana)

func add_attribute_points(strength_delta: int, intelligence_delta: int, agility_delta: int, resistance_delta: int = 0) -> void:
	if strength_delta != 0: strength += strength_delta
	if intelligence_delta != 0: intelligence += intelligence_delta
	if agility_delta != 0: agility += agility_delta
	if resistance_delta != 0: resistance += resistance_delta

func add_physical_damage(amount: float) -> void:
	physical_damage_bonus += amount
	_recalculate()

func add_magic_damage(amount: float) -> void:
	magic_damage_bonus += amount
	_recalculate()

func add_movement_speed_percent(amount: float) -> void:
	movement_speed_bonus_percent = max(movement_speed_bonus_percent + amount, -90.0)
	_recalculate()

func add_cooldown_reduction_percent(amount: float) -> void:
	## El límite evita enfriamientos casi nulos.
	cooldown_reduction_percent = clampf(cooldown_reduction_percent + amount, 0.0, 75.0)
	_recalculate()

func add_healing_bonus_percent(amount: float) -> void:
	healing_bonus_percent = max(healing_bonus_percent + amount, -100.0)
	_recalculate()

func add_ranged_attack_range(amount: float) -> void:
	ranged_attack_range_bonus = max(ranged_attack_range_bonus + amount, 0.0)
	stats_changed.emit()

func add_cast_range(amount: float) -> void:
	cast_range_bonus = max(cast_range_bonus + amount, 0.0)
	stats_changed.emit()

func add_armor(amount: float) -> void:
	armor_bonus += amount
	_recalculate()

## Conserva solo los valores base configurados en la escena del personaje.
func reset_received_stats() -> void:
	strength = 0
	intelligence = 0
	agility = 0
	resistance = 0
	physical_damage_bonus = 0.0
	magic_damage_bonus = 0.0
	movement_speed_bonus_percent = 0.0
	cooldown_reduction_percent = 0.0
	healing_bonus_percent = 0.0
	ranged_attack_range_bonus = 0.0
	cast_range_bonus = 0.0
	armor_bonus = 0.0
	_recalculate()
	current_health = max_health
	current_mana = max_mana
	health_changed.emit(current_health, max_health)
	mana_changed.emit(current_mana, max_mana)

## Reemplaza (no acumula) los bonos de los artefactos actualmente activos.
func set_item_bonuses(bonuses: Dictionary) -> void:
	item_strength = int(bonuses.get("strength", 0))
	item_intelligence = int(bonuses.get("intelligence", 0))
	item_agility = int(bonuses.get("agility", 0))
	item_resistance = int(bonuses.get("resistance", 0))
	item_physical_damage_bonus = float(bonuses.get("physical_damage", 0.0))
	item_magic_damage_bonus = float(bonuses.get("magic_damage", 0.0))
	item_movement_speed_bonus_percent = float(bonuses.get("move_speed_percent", 0.0))
	item_cooldown_reduction_percent = float(bonuses.get("cooldown_reduction_percent", 0.0))
	item_healing_bonus_percent = float(bonuses.get("healing_bonus_percent", 0.0))
	item_ranged_attack_range_bonus = float(bonuses.get("ranged_attack_range", 0.0))
	item_cast_range_bonus = float(bonuses.get("cast_range", 0.0))
	item_armor_bonus = float(bonuses.get("armor", 0.0))
	_recalculate()

func set_accessory_bonuses(bonuses: Dictionary) -> void:
	accessory_bonuses = bonuses.duplicate(true)
	_recalculate()

func _accessory_value(key: String) -> float:
	return float(accessory_bonuses.get(key, 0.0))

func set_base_move_speed(value: float) -> void:
	base_move_speed = max(value, 0.0)
	_recalculate()

func get_damage(damage_type: int) -> float:
	match damage_type:
		DamageType.MAGICAL:
			return magic_damage
		DamageType.TRUE:
			return 0.0
		_:
			return physical_damage

func get_cooldown_duration(base_seconds: float, cooldown_tag: int) -> float:
	if cooldown_tag == CooldownTag.REDUCIBLE_ABILITY:
		return max(base_seconds * ability_cooldown_multiplier, 0.0)
	return max(base_seconds, 0.0)

func get_total_cooldown_reduction_percent() -> float:
	return clampf(cooldown_reduction_percent + item_cooldown_reduction_percent + _accessory_value("cooldown_reduction_percent"), 0.0, 75.0)

func get_total_strength() -> int:
	return strength + item_strength + int(_accessory_value("strength"))

func get_total_intelligence() -> int:
	return intelligence + item_intelligence + int(_accessory_value("intelligence"))

func get_total_agility() -> int:
	return agility + item_agility + int(_accessory_value("agility"))

func get_total_resistance() -> int:
	return resistance + item_resistance + int(_accessory_value("resistance"))

func get_total_healing_bonus_percent() -> float:
	return max(healing_bonus_percent + item_healing_bonus_percent + _accessory_value("healing_bonus_percent"), -100.0)

func get_total_ranged_attack_range_bonus() -> float:
	return ranged_attack_range_bonus + item_ranged_attack_range_bonus + _accessory_value("ranged_attack_range")

func get_total_cast_range_bonus() -> float:
	return cast_range_bonus + item_cast_range_bonus + _accessory_value("cast_range")

## El bono amplifica la curación realizada. Además, cada 1% agrega 0.02%
## de la vida máxima del sanador: los personajes con más vida lo aprovechan mejor.
func calculate_healing(base_amount: float) -> float:
	if base_amount <= 0.0: return 0.0
	var total_bonus := get_total_healing_bonus_percent()
	var amplified := base_amount * (1.0 + total_bonus / 100.0)
	var vitality_bonus := max_health * total_bonus * 0.0002
	return max(amplified + vitality_bonus, 0.0)

func take_damage(amount: float, damage_type: int = DamageType.PHYSICAL) -> void:
	if amount <= 0.0: return
	var final_damage := amount * get_damage_multiplier(damage_type)
	current_health = max(current_health - final_damage, 0.0)
	damage_received.emit(amount, final_damage, damage_type)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0: died.emit()

func heal(amount: float) -> void:
	if amount <= 0.0: return
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)

func spend_mana(amount: float) -> bool:
	if current_mana < amount: return false
	current_mana -= amount
	mana_changed.emit(current_mana, max_mana)
	return true

func restore_mana(amount: float) -> void:
	current_mana = min(current_mana + amount, max_mana)
	mana_changed.emit(current_mana, max_mana)

func get_damage_multiplier(damage_type: int) -> float:
	if damage_type != DamageType.PHYSICAL:
		return 1.0
	return _physical_damage_multiplier()

func _physical_damage_multiplier() -> float:
	## 1 - armor/(armor + K); con armadura negativa aumenta el daño.
	return armor_constant / max(armor_constant + armor, 1.0)

func _recalculate() -> void:
	var old_max_health := max_health
	var old_max_mana := max_mana
	max_health = base_max_health + (strength + item_strength + int(_accessory_value("strength"))) * 10.0 + _accessory_value("max_health")
	max_mana = base_max_mana + (intelligence + item_intelligence + int(_accessory_value("intelligence"))) * 10.0 + _accessory_value("max_mana")
	attack_speed = base_attack_speed * (1.0 + (agility + item_agility + int(_accessory_value("agility"))) * 0.01) + _accessory_value("attack_speed")
	physical_damage = base_physical_damage + physical_damage_bonus + item_physical_damage_bonus + _accessory_value("physical_damage")
	magic_damage = base_magic_damage + magic_damage_bonus + item_magic_damage_bonus + _accessory_value("magic_damage")
	movement_speed = base_move_speed * (1.0 + (movement_speed_bonus_percent + item_movement_speed_bonus_percent + _accessory_value("move_speed_percent")) / 100.0)
	armor = base_armor + armor_bonus + item_armor_bonus + _accessory_value("armor")
	armor_damage_reduction = max(armor, 0.0) / (max(armor, 0.0) + armor_constant)
	health_regen = (resistance + item_resistance + int(_accessory_value("resistance"))) * 0.5
	mana_regen = (resistance + item_resistance + int(_accessory_value("resistance"))) * 0.5
	ability_cooldown_multiplier = 1.0 - get_total_cooldown_reduction_percent() / 100.0
	if old_max_health > 0.0 and max_health != old_max_health:
		current_health += max_health - old_max_health
		health_changed.emit(current_health, max_health)
	if old_max_mana > 0.0 and max_mana != old_max_mana:
		current_mana += max_mana - old_max_mana
		mana_changed.emit(current_mana, max_mana)
	stats_changed.emit()
