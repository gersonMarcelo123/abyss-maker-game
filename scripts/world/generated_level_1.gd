## GeneratedLevel1.gd
## Nivel generado procedimentalmente:
## - 1 Start Chunk (pequeño/inicio, donde aparece el jugador)
## - 4 Chunks procedimentales de 15x15 conectados con interiores aleatorios
## - Teletransportador al final para regresar al Lobby
## - Spawneo de enemigos en los chunks para probar combate y navegación
class_name GeneratedLevel1
extends Node2D

@export var chunk_scene: PackedScene = preload("res://scenes/world/ProceduralChunk.tscn")
@export var player_scene: PackedScene = preload("res://scenes/entities/player/Player.tscn")
@export var return_teleport_scene: PackedScene = preload("res://scenes/world/ReturnTeleport.tscn")
@export var dummy_enemy_scene: PackedScene = preload("res://scenes/entities/enemies/DummyEnemy.tscn")
@export var melee_enemy_scene: PackedScene = preload("res://scenes/entities/enemies/MeleeEnemy.tscn")

const CHUNK_WIDTH := 240.0 # 15 tiles * 16px

var player_instance: Player = null

func _ready() -> void:
	_generate_level()

func _generate_level() -> void:
	# 1. Start Chunk (Inicio pequeño / despejado con puerta a la derecha)
	var start_chunk := chunk_scene.instantiate() as ProceduralChunk
	start_chunk.position = Vector2(0, 0)
	start_chunk.door_right = true
	start_chunk.door_left = false
	start_chunk.door_top = false
	start_chunk.door_bottom = false
	start_chunk.interior_index = 0 # Centro despejado para el spawn
	add_child(start_chunk)

	# Instanciar o posicionar Jugador en el Start Chunk
	if not player_instance:
		player_instance = player_scene.instantiate() as Player
		add_child(player_instance)
	player_instance.global_position = Vector2(80, 120)

	# Configurar cámara para seguir al jugador
	var camera := Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	player_instance.add_child(camera)

	# 2. Generar 4 Chunks conectados
	var current_pos_x := CHUNK_WIDTH
	for i in range(1, 5):
		var chunk := chunk_scene.instantiate() as ProceduralChunk
		chunk.position = Vector2(current_pos_x, 0)
		chunk.door_left = true
		chunk.door_right = true
		chunk.door_top = false
		chunk.door_bottom = false
		chunk.interior_index = randi_range(1, 10)
		add_child(chunk)

		# Spawner de enemigos de prueba en el centro de cada chunk
		_spawn_chunk_enemies(current_pos_x, i)
		current_pos_x += CHUNK_WIDTH

	# 3. Teletransportador de regreso al Lobby al final del último chunk
	if return_teleport_scene:
		var teleport := return_teleport_scene.instantiate() as Node2D
		teleport.position = Vector2(current_pos_x - 36, 120)
		add_child(teleport)

func _spawn_chunk_enemies(chunk_offset_x: float, chunk_num: int) -> void:
	if dummy_enemy_scene:
		var dummy := dummy_enemy_scene.instantiate() as Node2D
		dummy.position = Vector2(chunk_offset_x + 120, 90)
		add_child(dummy)

		var dummy2 := dummy_enemy_scene.instantiate() as Node2D
		dummy2.position = Vector2(chunk_offset_x + 150, 140)
		add_child(dummy2)

	if chunk_num >= 2 and melee_enemy_scene:
		var enemy := melee_enemy_scene.instantiate() as Node2D
		enemy.position = Vector2(chunk_offset_x + 90, 150)
		add_child(enemy)
