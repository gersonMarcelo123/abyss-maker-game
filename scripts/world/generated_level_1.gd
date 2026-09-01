## Nivel generado 1: una ruta raíz que se abre en dos ramas y luego vuelve a unirse.
## Cada arista tiene siempre un pasillo físico; por eso no se generan puertas al vacío.
class_name GeneratedLevel1
extends Node2D

@export var chunk_scene: PackedScene = preload("res://scenes/world/ProceduralChunk.tscn")
@export var corridor_scene: PackedScene = preload("res://scenes/world/ProceduralCorridor.tscn")
@export var player_scene: PackedScene = preload("res://scenes/entities/player/Player.tscn")
@export var return_teleport_scene: PackedScene = preload("res://scenes/world/ReturnTeleport.tscn")
@export var melee_enemy_scene: PackedScene = preload("res://scenes/entities/enemies/MeleeEnemy.tscn")
@export var ranged_enemy_scene: PackedScene = preload("res://scenes/entities/enemies/RangedEnemy.tscn")

const ROOM_TILES := 25 # Entero: conserva tiles de 16×16 sin escalar texturas.
const START_TILES := 13
const TILE_SIZE := 16.0
const ROOM_SIZE := ROOM_TILES * TILE_SIZE
const START_SIZE := START_TILES * TILE_SIZE
const CORRIDOR_GAP := 96.0

var player_instance: Player = null
var _teleport_instance: Node2D = null
var _rooms: Dictionary = {} # id -> { center, size, exits, activated, cleared }
var _room_enemies: Dictionary = {}
var _exit_barriers: Dictionary = {} # id -> Array[StaticBody2D]

func _ready() -> void:
	_generate_level()

func _generate_level() -> void:
	var axis: Vector2 = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP].pick_random()
	var side := Vector2(-axis.y, axis.x)
	var start_center := Vector2.ZERO
	var root_center := axis * (START_SIZE * 0.5 + CORRIDOR_GAP + ROOM_SIZE * 0.5)
	var branch_a := root_center - side * (ROOM_SIZE + CORRIDOR_GAP)
	var branch_b := root_center + side * (ROOM_SIZE + CORRIDOR_GAP)
	var route_a := branch_a + axis * (ROOM_SIZE + CORRIDOR_GAP)
	var route_b := branch_b + axis * (ROOM_SIZE + CORRIDOR_GAP)
	var merge := root_center + axis * (ROOM_SIZE + CORRIDOR_GAP)
	var final_room := merge + axis * (ROOM_SIZE + CORRIDOR_GAP)
	_add_room("spawn", start_center, START_SIZE, 0)
	# Por ahora se dejan libres los interiores: la malla de navegación puede
	# cruzar las salas y los muros que bloquean son únicamente los generados.
	_add_room("root", root_center, ROOM_SIZE, 0)
	_add_room("rama_a", branch_a, ROOM_SIZE, 0)
	_add_room("rama_b", branch_b, ROOM_SIZE, 0)
	_add_room("ruta_a", route_a, ROOM_SIZE, 0)
	_add_room("ruta_b", route_b, ROOM_SIZE, 0)
	_add_room("union", merge, ROOM_SIZE, 0)
	_add_room("final", final_room, ROOM_SIZE, 0)
	_connect_rooms("spawn", "root", false)
	_connect_rooms("root", "rama_a", true)
	_connect_rooms("root", "rama_b", true)
	_connect_rooms("rama_a", "ruta_a", true)
	_connect_rooms("rama_b", "ruta_b", true)
	_connect_rooms("ruta_a", "union", true)
	_connect_rooms("ruta_b", "union", true)
	_connect_rooms("union", "final", true)
	_build_world()
	_spawn_player(start_center)
	_create_teleport(final_room + axis * (ROOM_SIZE * 0.5 - 52.0))

func _add_room(id: String, center: Vector2, size: float, interior: int) -> void:
	_rooms[id] = {"center": center, "size": size, "interior": interior, "neighbors": [], "activated": id == "spawn", "cleared": id == "spawn"}

func _connect_rooms(from_id: String, to_id: String, locked: bool) -> void:
	var from_room: Dictionary = _rooms[from_id]
	var to_room: Dictionary = _rooms[to_id]
	var direction := _direction_between(from_room.center, to_room.center)
	from_room.neighbors.append({"id": to_id, "direction": direction, "locked": locked})
	to_room.neighbors.append({"id": from_id, "direction": -direction, "locked": false})
	_rooms[from_id] = from_room
	_rooms[to_id] = to_room

func _direction_between(a: Vector2, b: Vector2) -> Vector2:
	var delta := b - a
	return Vector2(signf(delta.x), 0) if absf(delta.x) > absf(delta.y) else Vector2(0, signf(delta.y))

func _build_world() -> void:
	for room_id in _rooms:
		var room: Dictionary = _rooms[room_id]
		var chunk := chunk_scene.instantiate() as ProceduralChunk
		chunk.grid_size = int(room.size / TILE_SIZE)
		chunk.interior_index = int(room.interior)
		chunk.position = room.center - Vector2.ONE * room.size * 0.5
		for neighbor in room.neighbors: _set_chunk_door(chunk, neighbor.direction)
		add_child(chunk)
		_create_navigation_region(room.center, room.size)
		_create_room_trigger(room_id, room.center, room.size)
		for exit_data in room.neighbors:
			if exit_data.locked: _create_exit_barrier(room_id, room, exit_data.direction)
	for room_id in _rooms:
		for neighbor in _rooms[room_id].neighbors:
			if room_id < str(neighbor.id): _create_corridor(_rooms[room_id], _rooms[neighbor.id])

func _create_navigation_region(center: Vector2, size: float) -> void:
	var region := NavigationRegion2D.new()
	region.global_position = center
	var half := size * 0.5 - 8.0
	var polygon := NavigationPolygon.new()
	polygon.vertices = PackedVector2Array([Vector2(-half,-half), Vector2(half,-half), Vector2(half,half), Vector2(-half,half)])
	polygon.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_polygon = polygon
	add_child(region)

func _set_chunk_door(chunk: ProceduralChunk, direction: Vector2) -> void:
	if direction.x < 0: chunk.door_left = true
	elif direction.x > 0: chunk.door_right = true
	elif direction.y < 0: chunk.door_top = true
	else: chunk.door_bottom = true

func _create_corridor(a: Dictionary, b: Dictionary) -> void:
	var corridor := corridor_scene.instantiate() as ProceduralCorridor
	add_child(corridor)
	corridor.configure(a.center, a.size * 0.5, b.center, b.size * 0.5)

func _create_room_trigger(room_id: String, center: Vector2, size: float) -> void:
	if room_id == "spawn": return
	var area := Area2D.new()
	area.collision_mask = 2
	area.global_position = center
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2.ONE * (size - 64.0)
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
	area.body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("players"): _activate_room(room_id)
	)

func _create_exit_barrier(room_id: String, room: Dictionary, direction: Vector2) -> void:
	var barrier := StaticBody2D.new()
	barrier.global_position = room.center + direction * (room.size * 0.5 - 8.0)
	barrier.collision_layer = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 48) if direction.x != 0 else Vector2(48, 16)
	collision.shape = shape
	barrier.add_child(collision)
	var visual := Polygon2D.new()
	var half := shape.size * 0.5
	visual.polygon = PackedVector2Array([Vector2(-half.x,-half.y), Vector2(half.x,-half.y), Vector2(half.x,half.y), Vector2(-half.x,half.y)])
	visual.color = Color(0.85, 0.16, 0.16, 0.82)
	barrier.add_child(visual)
	add_child(barrier)
	if not _exit_barriers.has(room_id): _exit_barriers[room_id] = []
	_exit_barriers[room_id].append(barrier)

func _spawn_player(start_center: Vector2) -> void:
	player_instance = player_scene.instantiate() as Player
	add_child(player_instance)
	player_instance.global_position = start_center
	var camera := Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	player_instance.add_child(camera)
	add_child(InventoryMenu.new())
	add_child(EconomyHUD.new())

func _create_teleport(at_position: Vector2) -> void:
	_teleport_instance = return_teleport_scene.instantiate() as Node2D
	_teleport_instance.global_position = at_position
	_teleport_instance.visible = false
	_teleport_instance.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_teleport_instance)

func _activate_room(room_id: String) -> void:
	var room: Dictionary = _rooms[room_id]
	if room.activated: return
	room.activated = true
	_rooms[room_id] = room
	var living: Array = []
	for index in range(randi_range(1, 3)):
		var enemy_scene: PackedScene = melee_enemy_scene if randf() < 0.58 else ranged_enemy_scene
		var enemy := enemy_scene.instantiate() as Node2D
		enemy.global_position = room.center + Vector2(randf_range(-room.size * 0.25, room.size * 0.25), randf_range(-room.size * 0.25, room.size * 0.25))
		add_child(enemy)
		living.append(enemy)
		enemy.tree_exited.connect(func() -> void: _on_enemy_died(room_id, enemy))
	_room_enemies[room_id] = living

func _on_enemy_died(room_id: String, enemy: Node) -> void:
	var living: Array = _room_enemies.get(room_id, [])
	living.erase(enemy)
	if living.is_empty(): _clear_room(room_id)

func _clear_room(room_id: String) -> void:
	var room: Dictionary = _rooms[room_id]
	if room.cleared: return
	room.cleared = true
	_rooms[room_id] = room
	for barrier in _exit_barriers.get(room_id, []):
		if is_instance_valid(barrier): barrier.queue_free()
	if room_id == "final" and is_instance_valid(_teleport_instance):
		_teleport_instance.visible = true
		_teleport_instance.process_mode = Node.PROCESS_MODE_INHERIT
