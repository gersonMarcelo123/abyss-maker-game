## Restablece estado global al entrar a un nivel; evita que una pausa del
## inventario de la escena anterior congele el nivel nuevo.
extends Node2D

func _ready() -> void:
	get_tree().paused = false
