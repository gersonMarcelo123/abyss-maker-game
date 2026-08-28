## Projectile.gd
## Proyectil simple: viaja en línea recta hacia `target` y aplica daño al
## impactar (o cuando pasa lo bastante cerca). No usa colisión física —
## detecta el impacto por distancia, así que no necesitas configurar capas
## ni máscaras de colisión para probarlo.
##
## IMPORTANTE: asigna `target` (y opcionalmente `damage`) ANTES de agregar
## esta instancia al árbol de escena, porque _ready() ya usa `target` para
## calcular la dirección inicial. Ver Player.gd → _spawn_projectile().
class_name Projectile
extends Node2D

@export var speed: float = 700.0
@export var damage: float = 15.0
@export var hit_distance: float = 12.0 ## qué tan cerca del objetivo cuenta como "impacto"
@export var max_lifetime: float = 3.0  ## por si el objetivo desaparece y nunca "impacta"
@export var color: Color = Color(1.0, 0.85, 0.3)

var target: Node2D
var damage_type: int = CharacterStats.DamageType.PHYSICAL

var _direction: Vector2 = Vector2.RIGHT
var _life_elapsed: float = 0.0

@onready var visual: Polygon2D = $Visual

func _ready() -> void:
	_build_visual()
	if is_instance_valid(target):
		_direction = (target.global_position - global_position).normalized()
	rotation = _direction.angle()

func _physics_process(delta: float) -> void:
	_life_elapsed += delta
	if _life_elapsed >= max_lifetime:
		queue_free()
		return

	if is_instance_valid(target):
		# Persigue levemente al objetivo (útil si se mueve mientras vuela).
		_direction = (target.global_position - global_position).normalized()
		if global_position.distance_to(target.global_position) <= hit_distance:
			_hit(target)
			return
	# Si el objetivo ya no es válido (murió en pleno vuelo), el proyectil
	# sigue de largo en línea recta hasta que expire max_lifetime.

	global_position += _direction * speed * delta
	rotation = _direction.angle()

func _hit(hit_target: Node2D) -> void:
	if is_instance_valid(hit_target) and hit_target.has_method("take_damage"):
		hit_target.take_damage(damage, global_position, damage_type)
	queue_free()

func _build_visual() -> void:
	# Triangulito simple apuntando hacia adelante — reemplázalo por un
	# sprite real cuando tengas arte de proyectiles.
	visual.polygon = PackedVector2Array([
		Vector2(10, 0), Vector2(-6, 5), Vector2(-6, -5),
	])
	visual.color = color
