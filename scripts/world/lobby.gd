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
	room.grid_size = 25
	room.interior_index = 0
	add_child(room)

	# 2. Instanciar jugador y cámara
	player_instance = player_scene.instantiate() as Player
	player_instance.position = Vector2(200, 210)
	add_child(player_instance)

	var camera := Camera2D.new()
	camera.position_smoothing_enabled = true
	player_instance.add_child(camera)

	# 3. Baúl de Artefactos en el centro
	if artifact_chest_scene:
		var chest := artifact_chest_scene.instantiate()
		chest.position = Vector2(200, 105)
		add_child(chest)

	# 4. Menú de Inventario y Economía
	var inventory_menu_class := preload("res://scripts/ui/inventory_menu.gd")
	add_child(inventory_menu_class.new())
	var economy_hud_class := preload("res://scripts/ui/economy_hud.gd")
	var economy_hud = economy_hud_class.new()
	economy_hud.show_materials = true
	add_child(economy_hud)

	# Seis plataformas pisables: cinco crean un tipo de artefacto y una vacía el baúl.
	var forge_class := preload("res://scripts/world/artifact_forge_platform.gd")
	var forge_types: Array[String] = ["Runa", "Libreta", "Pulsera", "Lente", "Anillo"]
	for index in range(forge_types.size()):
		var forge = forge_class.new()
		forge.artifact_type = forge_types[index]
		forge.position = Vector2(55 + index * 72, 310)
		add_child(forge)
	var clear_forge = forge_class.new()
	clear_forge.clear_chest = true
	clear_forge.position = Vector2(200, 365)
	add_child(clear_forge)

	# 5. Teleport a Test Level (izquierda)
	var tp_test := _create_teleport("res://scenes/levels/TestLevel.tscn", "Test Level")
	tp_test.position = Vector2(55, 190)
	add_child(tp_test)

	# 5. Teleport a Nivel Generado 1 (derecha)
	var tp_gen := _create_teleport("res://scenes/levels/GeneratedLevel1.tscn", "Nivel Generado 1")
	tp_gen.position = Vector2(345, 190)
	add_child(tp_gen)

func _create_teleport(target_scene: String, label_text: String) -> Area2D:
	var area := Area2D.new()
	area.collision_mask = 2
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
