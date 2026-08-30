## ProceduralChunk.gd
## Chunk procedimental de 15x15 tiles (240x240 px) basado en la guía visual.
## Maneja la colocación de tiles de terreno, paredes perimetrales, puertas
## y la instanciación de uno de los 10 interiores de chunk.
@tool
class_name ProceduralChunk
extends Node2D

const TILE_SIZE := 16
const GRID_SIZE := 15
const CHUNK_PIXEL_SIZE := GRID_SIZE * TILE_SIZE # 240px

@export_group("Conexiones de Puertas")
@export var door_left: bool = false:
	set(v):
		door_left = v
		_rebuild_chunk()
@export var door_right: bool = false:
	set(v):
		door_right = v
		_rebuild_chunk()
@export var door_top: bool = false:
	set(v):
		door_top = v
		_rebuild_chunk()
@export var door_bottom: bool = false:
	set(v):
		door_bottom = v
		_rebuild_chunk()

@export_group("Interior")
## Índice de interior (1 a 10). 0 = sin interior o aleatorio si se activa auto_random_interior
@export_range(0, 10) var interior_index: int = 1:
	set(v):
		interior_index = v
		_rebuild_chunk()

@export var auto_random_interior: bool = false
@export var use_tilemap: bool = true

# Colores según la guía visual
const COLOR_ESQUINA_NEGRA := Color(0.05, 0.05, 0.05)
const COLOR_PARED_TOP := Color(0.0, 0.7, 0.9)
const COLOR_PARED_BOTTOM := Color(0.95, 0.95, 0.95)
const COLOR_PARED_LEFT := Color(0.0, 0.55, 0.1)
const COLOR_PARED_RIGHT := Color(0.0, 0.85, 0.85)
const COLOR_PUERTA_ROSA := Color(1.0, 0.5, 0.7)
const COLOR_ESQUINA_TERRENO := Color(1.0, 0.5, 0.0)
const COLOR_TERRENO_TOP := Color(0.75, 0.35, 0.35)
const COLOR_TERRENO_BOTTOM := Color(0.35, 0.12, 0.05)
const COLOR_TERRENO_LEFT := Color(0.5, 0.35, 0.95)
const COLOR_TERRENO_RIGHT := Color(0.0, 0.85, 0.95)
const COLOR_TERRENO_CENTRO := Color(1.0, 0.9, 0.1)

# Mapeo provisional de atlas coords en AbyssTileset.tres
const ATLAS_MAP := {
	"esquina_negra": Vector2i(0, 0),
	"pared_top": Vector2i(1, 0),
	"pared_bottom": Vector2i(2, 0),
	"pared_left": Vector2i(0, 1),
	"pared_right": Vector2i(3, 0),
	"puerta_rosa": Vector2i(4, 0),
	"esquina_terreno": Vector2i(1, 1),
	"terreno_top": Vector2i(2, 1),
	"terreno_bottom": Vector2i(3, 1),
	"terreno_left": Vector2i(4, 1),
	"terreno_right": Vector2i(5, 1),
	"terreno_centro": Vector2i(6, 1)
}

var _interior_instance: Node = null
@onready var tilemap_ground: TileMapLayer = get_node_or_null("GroundLayer")
@onready var tilemap_walls: TileMapLayer = get_node_or_null("WallLayer")
@onready var wall_colliders: StaticBody2D = get_node_or_null("WallColliders")

func _ready() -> void:
	if auto_random_interior and interior_index <= 0:
		interior_index = randi_range(1, 10)
	_rebuild_chunk()

func _rebuild_chunk() -> void:
	if not is_inside_tree():
		return
	
	if not tilemap_ground:
		tilemap_ground = get_node_or_null("GroundLayer")
	if not tilemap_walls:
		tilemap_walls = get_node_or_null("WallLayer")
	if not wall_colliders:
		wall_colliders = get_node_or_null("WallColliders")

	_build_tilemaps()
	_build_collisions()
	_spawn_interior()
	queue_redraw()

func _build_tilemaps() -> void:
	if not tilemap_ground or not tilemap_walls:
		return

	tilemap_ground.clear()
	tilemap_walls.clear()

	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var tile_type := _get_tile_type(x, y)
			var atlas_pos: Vector2i = ATLAS_MAP.get(tile_type, Vector2i(0, 0))
			
			if _is_solid_wall(x, y):
				tilemap_walls.set_cell(Vector2i(x, y), 0, atlas_pos)
			else:
				tilemap_ground.set_cell(Vector2i(x, y), 0, atlas_pos)

func _get_tile_type(x: int, y: int) -> String:
	# 4 Esquinas exteriores
	if (x == 0 or x == 14) and (y == 0 or y == 14):
		return "esquina_negra"

	# Borde superior (y = 0)
	if y == 0:
		if door_top and (x >= 6 and x <= 8):
			return "puerta_rosa"
		return "pared_top"

	# Borde inferior (y = 14)
	if y == 14:
		if door_bottom and (x >= 6 and x <= 8):
			return "puerta_rosa"
		return "pared_bottom"

	# Borde izquierdo (x = 0)
	if x == 0:
		if door_left and (y >= 6 and y <= 8):
			return "puerta_rosa"
		return "pared_left"

	# Borde derecho (x = 14)
	if x == 14:
		if door_right and (y >= 6 and y <= 8):
			return "puerta_rosa"
		return "pared_right"

	# 4 Esquinas de terreno (anillo interior)
	if (x == 1 or x == 13) and (y == 1 or y == 13):
		return "esquina_terreno"

	# Anillo interior de terreno
	if y == 1:
		return "terreno_top"
	if y == 13:
		return "terreno_bottom"
	if x == 1:
		return "terreno_left"
	if x == 13:
		return "terreno_right"

	# Centro del terreno (11x11)
	return "terreno_centro"

func _is_solid_wall(x: int, y: int) -> bool:
	if (x == 0 or x == 14) and (y == 0 or y == 14):
		return true
	if y == 0:
		return not (door_top and x >= 6 and x <= 8)
	if y == 14:
		return not (door_bottom and x >= 6 and x <= 8)
	if x == 0:
		return not (door_left and y >= 6 and y <= 8)
	if x == 14:
		return not (door_right and y >= 6 and y <= 8)
	return false

func _color_for_tile(type: String) -> Color:
	match type:
		"esquina_negra": return COLOR_ESQUINA_NEGRA
		"pared_top": return COLOR_PARED_TOP
		"pared_bottom": return COLOR_PARED_BOTTOM
		"pared_left": return COLOR_PARED_LEFT
		"pared_right": return COLOR_PARED_RIGHT
		"puerta_rosa": return COLOR_PUERTA_ROSA
		"esquina_terreno": return COLOR_ESQUINA_TERRENO
		"terreno_top": return COLOR_TERRENO_TOP
		"terreno_bottom": return COLOR_TERRENO_BOTTOM
		"terreno_left": return COLOR_TERRENO_LEFT
		"terreno_right": return COLOR_TERRENO_RIGHT
		_: return COLOR_TERRENO_CENTRO

func _build_collisions() -> void:
	if not wall_colliders:
		return

	for child in wall_colliders.get_children():
		child.queue_free()

	# Colisiones perimetrales con hueco en las puertas (x/y = 6..8 -> 96..144 px)
	# Pared Superior (y=0)
	if door_top:
		_add_collider_rect(Rect2(0, 0, 96, 16))
		_add_collider_rect(Rect2(144, 0, 96, 16))
	else:
		_add_collider_rect(Rect2(0, 0, 240, 16))

	# Pared Inferior (y=224)
	if door_bottom:
		_add_collider_rect(Rect2(0, 224, 96, 16))
		_add_collider_rect(Rect2(144, 224, 96, 16))
	else:
		_add_collider_rect(Rect2(0, 224, 240, 16))

	# Pared Izquierda (x=0)
	if door_left:
		_add_collider_rect(Rect2(0, 16, 16, 80))
		_add_collider_rect(Rect2(0, 144, 16, 80))
	else:
		_add_collider_rect(Rect2(0, 16, 16, 208))

	# Pared Derecha (x=224)
	if door_right:
		_add_collider_rect(Rect2(224, 16, 16, 80))
		_add_collider_rect(Rect2(224, 144, 16, 80))
	else:
		_add_collider_rect(Rect2(224, 16, 16, 208))

func _add_collider_rect(rect: Rect2) -> void:
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	col.shape = shape
	col.position = rect.position + rect.size * 0.5
	wall_colliders.add_child(col)

func _spawn_interior() -> void:
	if _interior_instance and is_instance_valid(_interior_instance):
		_interior_instance.queue_free()
		_interior_instance = null

	if interior_index < 1 or interior_index > 10:
		return

	var path := "res://scenes/world/chunk_interiors/ChunkInterior%02d.tscn" % interior_index
	if ResourceLoader.exists(path):
		var scene := load(path) as PackedScene
		if scene:
			_interior_instance = scene.instantiate()
			add_child(_interior_instance)
