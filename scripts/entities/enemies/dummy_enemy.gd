## DummyEnemy.gd
## Enemigo de prueba reutilizable. No depende de ninguna imagen: dibuja un
## círculo procedural con Polygon2D, así que es visible apenas lo instancias.
## Cambia de color cuando algún jugador lo tiene seleccionado como objetivo
## (ver Player.gd → _on_target_changed), para poder comprobar a simple vista
## que el targeting cambia correctamente entre varios dummies.
class_name DummyEnemy
extends Node2D

@export var max_health: float = 100.0
@export var radius: float = 20.0
@export var body_color: Color = Color(0.75, 0.25, 0.25)
@export var targeted_color: Color = Color(1.0, 0.9, 0.2)

var health: float

@onready var visual: Polygon2D = $Visual
@onready var label: Label = $HealthLabel

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	_build_circle_visual()
	_update_label()

func take_damage(amount: float, _source_position: Vector2 = Vector2.INF, _damage_type: int = CharacterStats.DamageType.PHYSICAL) -> void:
	health = max(health - amount, 0.0)
	_update_label()
	print("%s recibe %.0f de daño (vida: %.0f/%.0f)" % [name, amount, health, max_health])
	if health <= 0.0:
		queue_free()

## Llamado desde Player.gd cuando este dummy pasa a ser (o deja de ser)
## el objetivo seleccionado.
func set_targeted(is_targeted: bool) -> void:
	visual.color = targeted_color if is_targeted else body_color

func _build_circle_visual() -> void:
	var points := PackedVector2Array()
	var segments := 16
	for i in range(segments):
		var angle := TAU * i / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	visual.polygon = points
	visual.color = body_color

func _update_label() -> void:
	if label:
		label.text = "%d/%d" % [int(health), int(max_health)]
