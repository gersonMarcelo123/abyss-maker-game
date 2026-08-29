## GeneratedLevel1.gd
## Manejador de progresión por chunks:
## - El jugador comienza en el Start Chunk.
## - Al cruzar una puerta hacia un nuevo chunk, dicho chunk se activa y
##   aparecen sus enemigos.
## - La puerta hacia el siguiente chunk permanece cerrada/bloqueada hasta
##   que se eliminen TODOS los enemigos del chunk activo.
## - Al limpiar el chunk 4, se activa el teletransportador al Lobby.
class_name GeneratedLevel1
extends Node2D

@export var chunk_scene: PackedScene = preload("res://scenes/world/ProceduralChunk.tscn")
@export var player_scene: PackedScene = preload("res://scenes/entities/player/Player.tscn")
@export var return_teleport_scene: PackedScene = preload("res://scenes/world/ReturnTeleport.tscn")
@export var dummy_enemy_scene: PackedScene = preload("res://scenes/entities/enemies/DummyEnemy.tscn")
@export var melee_enemy_scene: PackedScene = preload("res://scenes/entities/enemies/MeleeEnemy.tscn")
@export var ranged_enemy_scene: PackedScene = preload("res://scenes/entities/enemies/RangedEnemy.tscn")

const CHUNK_WIDTH := 240.0 # 15 tiles * 16px
const TOTAL_CHUNKS := 4

var player_instance: Player = null
var _teleport_instance: Node2D = null

var _chunk_nodes: Array[ProceduralChunk] = []
var _chunk_activated: Array[bool] = [true, false, false, false, false]
var _chunk_enemies: Dictionary = {} # chunk_index -> Array de enemigos vivos
var _door_barriers: Dictionary = {} # chunk_index -> StaticBody2D de la barrera de salida

func _ready() -> void:
	_generate_level()

func _generate_level() -> void:
	# 1. Start Chunk (Chunk 0)
	var start_chunk := chunk_scene.instantiate() as ProceduralChunk
	start_chunk.position = Vector2(0, 0)
	start_chunk.door_right = true
	start_chunk.door_left = false
	start_chunk.door_top = false
	start_chunk.door_bottom = false
	start_chunk.interior_index = 0
	add_child(start_chunk)
	_chunk_nodes.append(start_chunk)

	# Instanciar jugador en Start Chunk
	if not player_instance:
		player_instance = player_scene.instantiate() as Player
		add_child(player_instance)
	player_instance.global_position = Vector2(80, 120)

	# Cámara
	var camera := Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	player_instance.add_child(camera)

	# Menú de Inventario
	var inventory_menu := InventoryMenu.new()
	add_child(inventory_menu)

	# 2. Generar Chunks 1 a 4 con barreras y triggers
	for i in range(1, TOTAL_CHUNKS + 1):
		var chunk_pos_x := i * CHUNK_WIDTH
		var chunk := chunk_scene.instantiate() as ProceduralChunk
		chunk.position = Vector2(chunk_pos_x, 0)
		chunk.door_left = true
		chunk.door_right = true
		chunk.door_top = false
		chunk.door_bottom = false
		chunk.interior_index = randi_range(1, 10)
		add_child(chunk)
		_chunk_nodes.append(chunk)
		_chunk_enemies[i] = []

		# Trigger en la puerta de entrada para activar el chunk al tocarla
		_create_door_trigger(i, chunk_pos_x)

		# Barrera en la puerta de salida hacia el siguiente chunk (cerrada por defecto)
		if i < TOTAL_CHUNKS:
			_create_door_barrier(i, chunk_pos_x + CHUNK_WIDTH)

	# 3. Teletransportador al final del Chunk 4 (bloqueado hasta limpiar Chunk 4)
	if return_teleport_scene:
		_teleport_instance = return_teleport_scene.instantiate() as Node2D
		_teleport_instance.position = Vector2((TOTAL_CHUNKS + 1) * CHUNK_WIDTH - 36, 120)
		_teleport_instance.visible = false
		_teleport_instance.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(_teleport_instance)

func _create_door_trigger(chunk_index: int, trigger_x: float) -> void:
	var area := Area2D.new()
	area.position = Vector2(trigger_x, 120)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 48)
	col.shape = shape
	area.add_child(col)
	add_child(area)

	area.body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("players"):
			_on_player_reached_chunk(chunk_index)
	)

func _create_door_barrier(chunk_index: int, barrier_x: float) -> void:
	var barrier := StaticBody2D.new()
	barrier.position = Vector2(barrier_x - 8, 120)
	barrier.collision_layer = 1
	barrier.collision_mask = 0

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 48)
	col.shape = shape
	barrier.add_child(col)

	# Visual de la puerta/barrera cerrada (roja translúcida)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-8, -24), Vector2(8, -24),
		Vector2(8, 24), Vector2(-8, 24)
	])
	visual.color = Color(0.85, 0.15, 0.15, 0.75)
	visual.name = "BarrierVisual"
	barrier.add_child(visual)

	add_child(barrier)
	_door_barriers[chunk_index] = barrier

func _on_player_reached_chunk(chunk_index: int) -> void:
	if _chunk_activated[chunk_index]:
		return
	_chunk_activated[chunk_index] = true
	print("[Level1] Jugador entra al Chunk %d — Spawneando enemigos..." % chunk_index)

	# Spawneo de enemigos al tocar la puerta del chunk
	var chunk_offset_x := chunk_index * CHUNK_WIDTH
	_spawn_enemies_for_chunk(chunk_index, chunk_offset_x)

func _spawn_enemies_for_chunk(chunk_index: int, offset_x: float) -> void:
	var enemy_list: Array = []

	if dummy_enemy_scene:
		var dummy1 := dummy_enemy_scene.instantiate() as Node2D
		dummy1.position = Vector2(offset_x + 100, 80)
		add_child(dummy1)
		enemy_list.append(dummy1)

		var dummy2 := dummy_enemy_scene.instantiate() as Node2D
		dummy2.position = Vector2(offset_x + 140, 160)
		add_child(dummy2)
		enemy_list.append(dummy2)

	if chunk_index >= 2 and melee_enemy_scene:
		var melee := melee_enemy_scene.instantiate() as Node2D
		melee.position = Vector2(offset_x + 80, 140)
		add_child(melee)
		enemy_list.append(melee)

	if chunk_index >= 3 and ranged_enemy_scene:
		var ranged := ranged_enemy_scene.instantiate() as Node2D
		ranged.position = Vector2(offset_x + 160, 90)
		add_child(ranged)
		enemy_list.append(ranged)

	_chunk_enemies[chunk_index] = enemy_list

	# Conectar muerte de cada enemigo para chequear cuando se limpie el chunk
	for enemy: Node in enemy_list:
		enemy.tree_exited.connect(func() -> void:
			_on_chunk_enemy_died(chunk_index, enemy)
		)

	# Si por alguna razón no se generaron enemigos, abrir de inmediato
	if enemy_list.is_empty():
		_unlock_chunk_exit(chunk_index)

func _on_chunk_enemy_died(chunk_index: int, enemy_node: Node) -> void:
	var list: Array = _chunk_enemies.get(chunk_index, [])
	list.erase(enemy_node)
	if list.is_empty():
		_unlock_chunk_exit(chunk_index)

func _unlock_chunk_exit(chunk_index: int) -> void:
	print("[Level1] ¡Chunk %d completado! Puerta abierta hacia el siguiente chunk." % chunk_index)

	# Abrir barrera al siguiente chunk
	if _door_barriers.has(chunk_index):
		var barrier: StaticBody2D = _door_barriers[chunk_index]
		if is_instance_valid(barrier):
			barrier.set_collision_layer_value(1, false)
			var visual: Polygon2D = barrier.get_node_or_null("BarrierVisual")
			if visual:
				visual.color = Color(0.2, 0.9, 0.4, 0.3) # Verde abierto / desbloqueado

	# Si completó el último chunk, activar el teletransportador
	if chunk_index == TOTAL_CHUNKS and _teleport_instance and is_instance_valid(_teleport_instance):
		_teleport_instance.visible = true
		_teleport_instance.process_mode = Node.PROCESS_MODE_INHERIT
		print("[Level1] ¡Teletransportador al Lobby activado!")
