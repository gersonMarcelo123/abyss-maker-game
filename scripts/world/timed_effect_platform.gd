## TimedEffectPlatform.gd
## Plataforma reutilizable que aplica un efecto cada `interval` segundos a
## cualquier jugador que esté PARADO ENCIMA en ese momento. Un solo script
## cubre daño, curación, atributos y bonificaciones — solo cambia
## `effect_type` (y `amount` si hace falta) en el Inspector.
## en el Inspector de cada instancia:
##
##   Daño   → effect_type = DAMAGE, amount = 10, interval = 2
##   Cura   → effect_type = HEAL,   amount = 10, interval = 2
##   Fuerza → effect_type = ATTR_STRENGTH,     amount = 1, interval = 2
##   Intel. → effect_type = ATTR_INTELLIGENCE, amount = 1, interval = 2
##   Agil.  → effect_type = ATTR_AGILITY,      amount = 1, interval = 2
##   Resist.→ effect_type = ATTR_RESISTANCE,   amount = 1, interval = 2
##
## Funciona detectando cuerpos en el grupo "players" (Player.gd ya se
## agrega solo a ese grupo en _ready()), así que no hace falta configurar
## capas/máscaras de colisión: basta con que el Area2D y el CharacterBody2D
## del jugador estén en las capas por defecto (así vienen de fábrica).
class_name TimedEffectPlatform
extends Area2D

## Los primeros seis valores se conservan para no alterar las plataformas ya
## colocadas en niveles existentes.
enum EffectType {
	DAMAGE, HEAL, ATTR_STRENGTH, ATTR_INTELLIGENCE, ATTR_AGILITY, ATTR_RESISTANCE,
	PHYSICAL_DAMAGE, MAGIC_DAMAGE, MOVEMENT_SPEED, COOLDOWN_REDUCTION,
	HEALING_BONUS, RANGED_ATTACK_RANGE, CAST_RANGE, ARMOR, RESET_STATS, SPAWN_ENCOUNTER
}

@export var effect_type: EffectType = EffectType.DAMAGE
@export_group("Daño")
## Físico recibe la reducción de armadura. Mágico y verdadero se reservan
## para fuentes que explícitamente deban ignorarla.
@export_enum("Físico", "Mágico", "Verdadero") var damage_type: int = CharacterStats.DamageType.PHYSICAL
@export_group("Aplicación")
@export var amount: float = 10.0
@export var interval: float = 2.0
@export var platform_size: Vector2 = Vector2(80, 80)
@export var color: Color = Color(0.8, 0.2, 0.2, 0.6)
@export_group("Invocación")
@export var melee_enemy_scene: PackedScene
@export var ranged_enemy_scene: PackedScene

var _bodies_on_platform: Array = []
var _spawned_enemies: Array[Node] = []

@onready var visual: Polygon2D = $Visual
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var timer: Timer = $Timer

func _ready() -> void:
	# La forma de colisión viene de un sub_resource compartido por todas
	# las instancias de la escena; se duplica para que cada plataforma
	# pueda tener su propio platform_size sin afectar a las demás.
	if collision.shape:
		collision.shape = collision.shape.duplicate()
		collision.shape.size = platform_size

	_build_visual()
	_build_label()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	timer.wait_time = interval
	timer.one_shot = false
	timer.timeout.connect(_on_timer_timeout)
	timer.start()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("players") and not _bodies_on_platform.has(body):
		_bodies_on_platform.append(body)

func _on_body_exited(body: Node) -> void:
	_bodies_on_platform.erase(body)

func _on_timer_timeout() -> void:
	for body in _bodies_on_platform.duplicate():
		if not is_instance_valid(body):
			_bodies_on_platform.erase(body)
			continue
		_apply_effect(body)

func _apply_effect(body: Node) -> void:
	match effect_type:
		EffectType.DAMAGE:
			if body.has_method("take_damage"):
				body.take_damage(amount, global_position, damage_type)
		EffectType.HEAL:
			if body.has_method("heal"):
				body.heal(amount)
		EffectType.ATTR_STRENGTH:
			if body.has_method("add_attribute_points"):
				body.add_attribute_points(int(amount), 0, 0, 0)
		EffectType.ATTR_INTELLIGENCE:
			if body.has_method("add_attribute_points"):
				body.add_attribute_points(0, int(amount), 0, 0)
		EffectType.ATTR_AGILITY:
			if body.has_method("add_attribute_points"):
				body.add_attribute_points(0, 0, int(amount), 0)
		EffectType.ATTR_RESISTANCE:
			if body.has_method("add_attribute_points"):
				body.add_attribute_points(0, 0, 0, int(amount))
		EffectType.PHYSICAL_DAMAGE:
			if body.has_method("add_physical_damage"):
				body.add_physical_damage(amount)
		EffectType.MAGIC_DAMAGE:
			if body.has_method("add_magic_damage"):
				body.add_magic_damage(amount)
		EffectType.MOVEMENT_SPEED:
			if body.has_method("add_movement_speed_percent"):
				body.add_movement_speed_percent(amount)
		EffectType.COOLDOWN_REDUCTION:
			if body.has_method("add_cooldown_reduction_percent"):
				body.add_cooldown_reduction_percent(amount)
		EffectType.HEALING_BONUS:
			if body.has_method("add_healing_bonus_percent"):
				body.add_healing_bonus_percent(amount)
		EffectType.RANGED_ATTACK_RANGE:
			if body.has_method("add_ranged_attack_range"):
				body.add_ranged_attack_range(amount)
		EffectType.CAST_RANGE:
			if body.has_method("add_cast_range"):
				body.add_cast_range(amount)
		EffectType.ARMOR:
			if body.has_method("add_armor"):
				body.add_armor(amount)
		EffectType.RESET_STATS:
			if body.has_method("reset_received_stats"):
				body.reset_received_stats()
		EffectType.SPAWN_ENCOUNTER:
			_spawn_encounter()

func _spawn_encounter() -> void:
	if melee_enemy_scene == null or ranged_enemy_scene == null:
		return
	for enemy in _spawned_enemies:
		if is_instance_valid(enemy):
			return
	_spawned_enemies.clear()
	var melee_enemy := melee_enemy_scene.instantiate()
	var ranged_enemy := ranged_enemy_scene.instantiate()
	melee_enemy.global_position = global_position + Vector2(-45, 0)
	ranged_enemy.global_position = global_position + Vector2(45, 0)
	get_tree().current_scene.add_child(melee_enemy)
	get_tree().current_scene.add_child(ranged_enemy)
	_spawned_enemies = [melee_enemy, ranged_enemy]

func _build_visual() -> void:
	var half := platform_size / 2.0
	visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	visual.color = color

func _build_label() -> void:
	var label := Label.new()
	label.text = _effect_label()
	label.position = Vector2(-platform_size.x / 2.0, -platform_size.y / 2.0 - 18.0)
	label.size = Vector2(platform_size.x, 16.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

func _effect_label() -> String:
	match effect_type:
		EffectType.DAMAGE:
			return _damage_label()
		EffectType.HEAL:
			return "Curación"
		EffectType.ATTR_STRENGTH:
			return "Fuerza"
		EffectType.ATTR_INTELLIGENCE:
			return "Inteligencia"
		EffectType.ATTR_AGILITY:
			return "Agilidad"
		EffectType.ATTR_RESISTANCE:
			return "Resistencia"
		EffectType.PHYSICAL_DAMAGE:
			return "Daño fís."
		EffectType.MAGIC_DAMAGE:
			return "Daño mág."
		EffectType.MOVEMENT_SPEED:
			return "Vel. mov."
		EffectType.COOLDOWN_REDUCTION:
			return "CDR"
		EffectType.HEALING_BONUS:
			return "Bono cura"
		EffectType.RANGED_ATTACK_RANGE:
			return "Rango atk."
		EffectType.CAST_RANGE:
			return "Rango cast"
		EffectType.ARMOR:
			return "Armadura"
		EffectType.RESET_STATS:
			return "Restablecer"
		EffectType.SPAWN_ENCOUNTER:
			return "Invocar"
		_:
			return "Efecto"

func _damage_label() -> String:
	match damage_type:
		CharacterStats.DamageType.MAGICAL:
			return "Daño mág."
		CharacterStats.DamageType.TRUE:
			return "Daño verdadero"
		_:
			return "Daño fís."
