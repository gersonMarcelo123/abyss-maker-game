## Piso modular de 16px. Detecta plataformas vecinas y usa borde/esquina/centro.
class_name FloorPlatform
extends Node2D

@export var tile_size := 16
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("floor_platforms")
	call_deferred("refresh_tile")
	call_deferred("refresh_neighbours")

func refresh_neighbours() -> void:
	for floor_tile in get_tree().get_nodes_in_group("floor_platforms"):
		if floor_tile != self and floor_tile.has_method("refresh_tile"): floor_tile.refresh_tile()

func refresh_tile() -> void:
	var has_left := _has_floor(Vector2.LEFT)
	var has_right := _has_floor(Vector2.RIGHT)
	var has_up := _has_floor(Vector2.UP)
	var has_down := _has_floor(Vector2.DOWN)
	var source := Vector2(64, 48) # centro de piso del Tileset
	if not has_up and not has_left: source = Vector2(48, 48)
	elif not has_up and not has_right: source = Vector2(80, 48)
	elif not has_down and not has_left: source = Vector2(48, 64)
	elif not has_down and not has_right: source = Vector2(80, 64)
	elif not has_up: source = Vector2(64, 32)
	elif not has_down: source = Vector2(64, 64)
	elif not has_left: source = Vector2(48, 48)
	elif not has_right: source = Vector2(80, 48)
	sprite.region_rect = Rect2(source, Vector2(16, 16))

func _has_floor(direction: Vector2) -> bool:
	var expected := global_position + direction * tile_size
	for floor_tile in get_tree().get_nodes_in_group("floor_platforms"):
		if floor_tile != self and floor_tile.global_position == expected: return true
	return false
