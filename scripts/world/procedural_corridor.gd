## Pasillo corto exclusivamente para unir dos salas existentes.
class_name ProceduralCorridor
extends Node2D

const FLOOR_ATLAS := Vector2i(6, 1)
const WALL_H_ATLAS := Vector2i(1, 0)
const WALL_V_ATLAS := Vector2i(0, 1)
const TILESET := preload("res://assets/tiles/AbyssTileset.tres")

func configure(from_center: Vector2, from_half: float, to_center: Vector2, to_half: float) -> void:
	var horizontal := absf(to_center.x - from_center.x) > absf(to_center.y - from_center.y)
	var ground := TileMapLayer.new()
	ground.tile_set = TILESET
	ground.z_index = -10
	var walls := TileMapLayer.new()
	walls.tile_set = TILESET
	walls.z_index = -9
	var body := StaticBody2D.new()
	body.collision_layer = 1
	add_child(ground); add_child(walls); add_child(body)
	if horizontal:
		var left := minf(from_center.x + signf(to_center.x - from_center.x) * from_half, to_center.x + signf(from_center.x - to_center.x) * to_half)
		position = Vector2(left, from_center.y - 40.0)
		for x in range(6):
			for y in range(5): (walls if y == 0 or y == 4 else ground).set_cell(Vector2i(x, y), 0, WALL_H_ATLAS if y == 0 or y == 4 else FLOOR_ATLAS)
		_add_collision(body, Rect2(0, 0, 96, 16)); _add_collision(body, Rect2(0, 64, 96, 16))
		_add_navigation_region(Rect2(-16, 16, 128, 48))
	else:
		var top := minf(from_center.y + signf(to_center.y - from_center.y) * from_half, to_center.y + signf(from_center.y - to_center.y) * to_half)
		position = Vector2(from_center.x - 40.0, top)
		for x in range(5):
			for y in range(6): (walls if x == 0 or x == 4 else ground).set_cell(Vector2i(x, y), 0, WALL_V_ATLAS if x == 0 or x == 4 else FLOOR_ATLAS)
		_add_collision(body, Rect2(0, 0, 16, 96)); _add_collision(body, Rect2(64, 0, 16, 96))
		_add_navigation_region(Rect2(16, -16, 48, 128))

func _add_collision(body: StaticBody2D, rect: Rect2) -> void:
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	collision.position = rect.position + rect.size * 0.5
	body.add_child(collision)

func _add_navigation_region(rect: Rect2) -> void:
	var region := NavigationRegion2D.new()
	var polygon := NavigationPolygon.new()
	polygon.vertices = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	polygon.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_polygon = polygon
	add_child(region)
