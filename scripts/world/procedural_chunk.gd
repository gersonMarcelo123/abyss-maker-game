## Chunk visual 15x15. Los colores replican la guía; sustituye cada color
## por el tile del atlas que prefieras cuando definas el TileSet definitivo.
class_name ProceduralChunk
extends Node2D

@export var layout_index := 0
const TILE := 16
const SIZE := 15

func _draw() -> void:
	for y in range(SIZE):
		for x in range(SIZE):
			var color := _color_for(x, y)
			draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), color)
			if _is_interior_wall(x, y): draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), Color(0.18, 0.08, 0.05))

func _color_for(x: int, y: int) -> Color:
	if (x == 0 or x == 14) and (y == 0 or y == 14): return Color.BLACK
	if y == 0 or y == 14: return Color(0.85, 0.9, 0.95)
	if x == 0 or x == 14: return Color(0, 0.45, 0)
	if y == 1: return Color(0.05, 0.6, 0.75)
	if y == 2: return Color(0.8, 0.3, 0.3)
	if y == 12: return Color(0.4, 0.1, 0.05)
	if x == 1 or x == 13: return Color(0.55, 0.35, 0.9)
	if x == 2 or x == 12: return Color(0.1, 0.85, 0.85)
	return Color(0.95, 0.82, 0.05)

func _is_interior_wall(x: int, y: int) -> bool:
	match layout_index:
		0: return x == 7 and y > 4 and y < 10
		1: return y == 7 and x > 4 and x < 10
		2: return (x == 5 or x == 9) and y > 5 and y < 10
		3: return (y == 5 or y == 9) and x > 5 and x < 10
		4: return x == y and x > 4 and x < 10
		5: return x + y == 14 and x > 4 and x < 10
		6: return x == 5 and y > 4 and y < 10 or y == 9 and x > 5 and x < 10
		7: return x == 9 and y > 4 and y < 10 or y == 5 and x > 5 and x < 10
		8: return (x == 5 or x == 9) and (y == 5 or y == 9)
		_: return x == 7 and y == 7
