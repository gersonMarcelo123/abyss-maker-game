## DummySpawner.gd
## Pon este script en un Node2D dentro de tu escena de pruebas, asigna
## `dummy_scene` = DummyEnemy.tscn en el Inspector, y listo: instancia
## `count` dummies en fila, separados por `spacing` píxeles, para que
## nunca queden superpuestos por accidente.
extends Node2D

@export var dummy_scene: PackedScene
@export var count: int = 5
@export var spacing: float = 140.0

func _ready() -> void:
	if dummy_scene == null:
		push_warning("DummySpawner: asigna 'dummy_scene' en el Inspector (DummyEnemy.tscn)")
		return
	for i in range(count):
		var dummy := dummy_scene.instantiate()
		add_child(dummy)
		# Los reparte en fila, centrados respecto al spawner.
		dummy.position = Vector2((i - (count - 1) / 2.0) * spacing, 0)
