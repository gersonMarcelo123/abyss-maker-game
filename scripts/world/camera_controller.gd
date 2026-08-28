## CameraController.gd
## Cámara única y compartida (sin split-screen, como Soul Knight).
## Sigue suavemente a `follow_target` (por ahora el jugador; en el modo
## co-op de 1-4 jugadores más adelante puede apuntar a un nodo que calcule
## el punto medio entre todos los jugadores en vez de a uno solo).
##
## También expone una pequeña API de "eventos de cámara" para más adelante:
## sacudida al recibir daño, zoom en peleas de jefe, o enfocar brevemente
## un punto del escenario (una puerta que se abre, una trampa, la
## aparición de un jefe, etc.) antes de volver a seguir al jugador.
class_name CameraController
extends Camera2D

## Arrastra aquí el nodo Player (o el nodo que quieras seguir) desde el
## Inspector.
@export var follow_target: Node2D
@export var follow_smoothing_speed: float = 5.0

@export_group("Shake")
@export var shake_decay: float = 5.0 ## qué tan rápido se apaga la sacudida

var _following: bool = true
var _shake_strength: float = 0.0
var _tween: Tween

func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = follow_smoothing_speed
	make_current() # esta es LA cámara activa; no hace falta marcar nada más

func _process(delta: float) -> void:
	if _following and is_instance_valid(follow_target):
		global_position = follow_target.global_position

	if _shake_strength > 0.0:
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength
		_shake_strength = max(_shake_strength - shake_decay * delta, 0.0)
		if _shake_strength <= 0.0:
			offset = Vector2.ZERO

# ---------------------------------------------------------------------------
# Eventos de cámara — llamar desde cualquier otro script, ej:
#   camera_controller.shake(10.0)
#   camera_controller.zoom_to(Vector2(0.7, 0.7), 1.0)   # acercar (boss fight)
#   camera_controller.focus_on(door.global_position, 1.5)
# ---------------------------------------------------------------------------

## Sacude la cámara (golpes, explosiones, impacto de jefe, etc.)
func shake(strength: float = 8.0) -> void:
	_shake_strength = strength

## Zoom hacia zoom_level (Vector2(1,1) = normal; valores menores = más
## cerca, mayores = más lejos) en duration segundos.
func zoom_to(zoom_level: Vector2, duration: float = 0.5) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "zoom", zoom_level, duration).set_trans(Tween.TRANS_SINE)

## Deja de seguir a follow_target y enfoca world_position (por ejemplo, un
## jefe apareciendo o una puerta abriéndose). Si return_after > 0, vuelve a
## seguir automáticamente después de esos segundos.
func focus_on(world_position: Vector2, return_after: float = 0.0) -> void:
	_following = false
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "global_position", world_position, 0.6).set_trans(Tween.TRANS_SINE)
	if return_after > 0.0:
		await get_tree().create_timer(return_after).timeout
		resume_follow()

## Vuelve a seguir a follow_target (o a un nuevo target, si se lo pasas).
func resume_follow(target: Node2D = null) -> void:
	if target:
		follow_target = target
	_following = true
