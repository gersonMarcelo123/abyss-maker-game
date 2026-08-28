## CustomizableWall.gd
## Pared estática modificable con tamaño, color y colisión ajustables desde el Inspector.
@tool
class_name CustomizableWall
extends StaticBody2D

@export var wall_size: Vector2 = Vector2(32.0, 32.0):
	set(value):
		wall_size = value
		_update_wall()

@export var wall_color: Color = Color(0.18, 0.2, 0.26, 1.0):
	set(value):
		wall_color = value
		_update_wall()

@export var texture: Texture2D = null:
	set(value):
		texture = value
		_update_wall()

@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var visual: Polygon2D = get_node_or_null("Visual")

func _ready() -> void:
	add_to_group("walls")
	_update_wall()

func _update_wall() -> void:
	if not is_inside_tree():
		return
	if not collision_shape:
		collision_shape = get_node_or_null("CollisionShape2D")
	if not visual:
		visual = get_node_or_null("Visual")

	var half_w := wall_size.x * 0.5
	var half_h := wall_size.y * 0.5

	if collision_shape:
		var rect_shape := collision_shape.shape as RectangleShape2D
		if not rect_shape:
			rect_shape = RectangleShape2D.new()
			collision_shape.shape = rect_shape
		rect_shape.size = wall_size
		collision_shape.position = Vector2(half_w, half_h)

	if visual:
		visual.polygon = PackedVector2Array([
			Vector2(0, 0),
			Vector2(wall_size.x, 0),
			Vector2(wall_size.x, wall_size.y),
			Vector2(0, wall_size.y)
		])
		visual.color = wall_color
		visual.texture = texture
