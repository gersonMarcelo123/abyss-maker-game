## Enemigo base con navegación, agro y dos modos: melee o rango.
class_name CombatEnemy
extends CharacterBody2D

enum CombatMode { MELEE, RANGED }
@export var combat_mode: CombatMode = CombatMode.MELEE
@export var max_health := 80.0
@export var move_speed := 85.0
@export var attack_damage := 8.0
@export var attack_range := 30.0
@export var preferred_range := 150.0
@export var attack_cooldown := 1.2
@export var projectile_scene: PackedScene

var health: float
var target: Node2D
var _forced_target: Node2D
var _agro_time := 0.0
var _cooldown := 0.0
var _dps_damage := 0.0
var _dps_time := 0.0
var _wander_destination := Vector2.ZERO
var _wander_time := 0.0
var _idle_time := 0.0
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var health_fill: Polygon2D = $HealthBar/Fill
@onready var health_bg: Polygon2D = $HealthBar/Background

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	health_bg.polygon = _rect(34, 4)
	health_bg.color = Color(0, 0, 0, 0.7)
	_update_health_bar()

func _physics_process(delta: float) -> void:
	_cooldown = max(_cooldown - delta, 0.0)
	_dps_time += delta
	if _dps_time >= 1.0:
		_dps_time = 0.0
		_dps_damage = 0.0
	_agro_time = max(_agro_time - delta, 0.0)
	if _agro_time <= 0.0: _forced_target = null
	target = _choose_target()
	if not is_instance_valid(target):
		_wander(delta)
		move_and_slide()
		return
	var distance := global_position.distance_to(target.global_position)
	var has_line_of_sight := _has_clear_path(target)
	if combat_mode == CombatMode.MELEE:
		if distance > attack_range or not has_line_of_sight: _move_to(target.global_position)
		else:
			velocity = Vector2.ZERO
			if has_line_of_sight: _attack()
	else:
		if distance < preferred_range * 0.72:
			# Huye pero sigue disparando mientras se aleja
			_move_to(global_position + (global_position - target.global_position).normalized() * 90.0)
			if has_line_of_sight: _attack()
		elif distance > preferred_range:
			_move_to(target.global_position)
		else:
			velocity = Vector2.ZERO
			if has_line_of_sight: _attack()
	velocity += _get_separation_vector() * 40.0
	move_and_slide()

func _get_separation_vector() -> Vector2:
	var separation := Vector2.ZERO
	var neighbors := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy != self and enemy is Node2D and is_instance_valid(enemy):
			var other_pos: Vector2 = (enemy as Node2D).global_position
			var diff: Vector2 = global_position - other_pos
			var dist: float = diff.length()
			if dist < 24.0 and dist > 0.001:
				separation += diff.normalized() * (1.0 - (dist / 24.0))
				neighbors += 1
	return separation.normalized() if neighbors > 0 else Vector2.ZERO

func provoke(new_target: Node2D, duration: float = 3.0) -> void:
	if is_instance_valid(new_target):
		_forced_target = new_target
		_agro_time = max(duration, 0.0)

func take_damage(amount: float, source_position: Vector2 = Vector2.INF, _damage_type: int = CharacterStats.DamageType.PHYSICAL) -> void:
	health = max(health - amount, 0.0)
	_dps_damage += amount
	_show_text("-%.1f" % amount, Color(1.0, 0.2, 0.2), Vector2(0, -46))
	_show_text("DPS %.1f" % (_dps_damage / maxf(_dps_time, 0.05)), Color.WHITE, Vector2(0, -61))
	if source_position != Vector2.INF and source_position is Vector2:
		var provoking_player := _nearest_player_to(source_position)
		if provoking_player: provoke(provoking_player, 4.0)
	_update_health_bar()
	if health <= 0.0: queue_free()

func _choose_target() -> Node2D:
	if is_instance_valid(_forced_target): return _forced_target
	var closest: Node2D = null
	var closest_distance := INF
	for player in get_tree().get_nodes_in_group("players"):
		if player is Node2D and is_instance_valid(player) and (not player.has_method("is_alive") or player.is_alive()):
			var distance := global_position.distance_to(player.global_position)
			if distance < closest_distance:
				closest = player
				closest_distance = distance
	return closest

func _nearest_player_to(position_to_check: Vector2) -> Node2D:
	var closest: Node2D = null
	var closest_distance := INF
	for player in get_tree().get_nodes_in_group("players"):
		if player is Node2D and position_to_check.distance_to(player.global_position) < closest_distance:
			closest = player
			closest_distance = position_to_check.distance_to(player.global_position)
	return closest

func _move_to(destination: Vector2) -> void:
	## El agente queda listo para regiones de navegación de futuras paredes.
	navigation_agent.target_position = destination
	var next_point := navigation_agent.get_next_path_position()
	if not navigation_agent.is_navigation_finished():
		velocity = global_position.direction_to(next_point) * move_speed
	else:
		velocity = global_position.direction_to(destination) * move_speed

func _has_clear_path(other: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, other.global_position, 1)
	query.exclude = [get_rid(), other.get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty()

func _wander(delta: float) -> void:
	if _idle_time > 0.0:
		_idle_time -= delta
		velocity = Vector2.ZERO
		return
	_wander_time -= delta
	if _wander_time <= 0.0 or global_position.distance_to(_wander_destination) < 8.0:
		if randf() < 0.35:
			_idle_time = randf_range(0.5, 1.5)
			velocity = Vector2.ZERO
			return
		_wander_destination = global_position + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * randf_range(30.0, 90.0)
		_wander_time = randf_range(1.2, 2.8)
	velocity = global_position.direction_to(_wander_destination) * move_speed * 0.55

func _attack() -> void:
	if _cooldown > 0.0: return
	_cooldown = attack_cooldown
	if combat_mode == CombatMode.RANGED and projectile_scene:
		var projectile := projectile_scene.instantiate()
		projectile.target = target
		projectile.damage = attack_damage
		projectile.damage_type = CharacterStats.DamageType.PHYSICAL
		projectile.position = global_position
		get_tree().current_scene.add_child(projectile)
	elif target.has_method("take_damage"):
		target.take_damage(attack_damage, global_position, CharacterStats.DamageType.PHYSICAL)

func set_targeted(value: bool) -> void:
	modulate = Color(1.2, 1.2, 0.6) if value else Color.WHITE

func _update_health_bar() -> void:
	var ratio: float = health / maxf(max_health, 0.001)
	health_fill.polygon = _bar_rect(34 * ratio, 4)
	health_fill.color = Color(0.85, 0.18, 0.18)

func _rect(width: float, height: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-width / 2.0, 0), Vector2(width / 2.0, 0), Vector2(width / 2.0, height), Vector2(-width / 2.0, height)])

func _bar_rect(width: float, height: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-17, 0), Vector2(-17 + width, 0), Vector2(-17 + width, height), Vector2(-17, height)])

func _show_text(value: String, text_color: Color, offset: Vector2) -> void:
	var indicator := FloatingCombatText.new()
	add_child(indicator)
	indicator.show_value(value, text_color, offset)
