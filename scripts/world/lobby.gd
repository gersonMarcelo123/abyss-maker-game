## LobbyRoom.gd
## Escena/habitación 2D interactuable del Lobby:
## - El jugador camina libremente.
## - Teleports hacia Test Level y Nivel Generado 1.
## - Baúl de Artefactos para configurar accesorios.
class_name LobbyRoom
extends Node2D

@export var player_scene: PackedScene = preload("res://scenes/entities/player/Player.tscn")
@export var chunk_scene: PackedScene = preload("res://scenes/world/ProceduralChunk.tscn")
@export var artifact_chest_scene: PackedScene = preload("res://scenes/world/ArtifactChest.tscn")

var player_instance: Player = null

func _ready() -> void:
	get_tree().paused = false
	# 1. Crear habitación (ProceduralChunk despejado 15x15)
	var room := chunk_scene.instantiate() as ProceduralChunk
	room.position = Vector2.ZERO
	room.door_left = false
	room.door_right = false
	room.door_top = false
	room.door_bottom = false
	room.interior_index = 0
	add_child(room)

	# 2. Instanciar jugador y cámara
	player_instance = player_scene.instantiate() as Player
	player_instance.position = Vector2(120, 150)
	add_child(player_instance)

	var camera := Camera2D.new()
	camera.position_smoothing_enabled = true
	player_instance.add_child(camera)

	# 3. Baúl de Artefactos en el centro
	if artifact_chest_scene:
		var chest := artifact_chest_scene.instantiate()
		chest.position = Vector2(120, 80)
		add_child(chest)

	# 4. Menú de Inventario
	var inventory_menu := InventoryMenu.new()
	add_child(inventory_menu)

	# 5. Teleport a Test Level (izquierda)
	var tp_test := _create_teleport("res://scenes/levels/TestLevel.tscn", "Test Level")
	tp_test.position = Vector2(50, 120)
	add_child(tp_test)

	# 5. Teleport a Nivel Generado 1 (derecha)
	var tp_gen := _create_teleport("res://scenes/levels/GeneratedLevel1.tscn", "Nivel Generado 1")
	tp_gen.position = Vector2(190, 120)
	add_child(tp_gen)

func _create_teleport(target_scene: String, label_text: String) -> Area2D:
	var area := Area2D.new()
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 16.0
	col.shape = shape
	area.add_child(col)

	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-14, 0), Vector2(0, -14),
		Vector2(14, 0), Vector2(0, 14)
	])
	visual.color = Color(0.3, 0.7, 1.0, 0.8)
	area.add_child(visual)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.position = Vector2(-35, -28)
	lbl.add_theme_font_size_override("font_size", 9)
	area.add_child(lbl)

	area.body_entered.connect(func(body: Node2D):
		if body.is_in_group("players"):
			get_tree().paused = false
			get_tree().change_scene_to_file(target_scene)
	)
	return area
