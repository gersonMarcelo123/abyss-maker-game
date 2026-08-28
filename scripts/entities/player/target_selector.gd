## TargetSelector.gd
## Elige el objetivo más adecuado según hacia dónde apunta el jugador
## (mouse o stick derecho), dentro de un cono y un rango máximo.
## Los enemigos deben pertenecer al grupo "enemies" (y ser Node2D).
class_name TargetSelector
extends Node

@export var max_range: float = 500.0
@export var cone_half_angle_deg: float = 24.0
@export var enemy_group: String = "enemies"

var current_target: Node2D = null

## Se emite con (objetivo_anterior, objetivo_nuevo) cada vez que cambia el
## objetivo, incluyendo cuando el objetivo anterior muere/desaparece.
## Útil para resaltar visualmente al enemigo seleccionado.
signal target_changed(old_target: Node2D, new_target: Node2D)

## Llamar cada physics_process con la posición del jugador y su dirección
## de apuntado actual. Si aim_dir es Vector2.ZERO (p. ej. mando sin mover
## el stick derecho) se conserva el último objetivo válido en vez de
## perderlo cada frame.
func update(origin: Vector2, aim_dir: Vector2) -> Node2D:
	_drop_target_if_invalid()

	if aim_dir == Vector2.ZERO:
		return current_target

	var best: Node2D = null
	var best_score: float = INF

	for enemy in get_tree().get_nodes_in_group(enemy_group):
		if not (enemy is Node2D) or not is_instance_valid(enemy):
			continue
		var to_enemy: Vector2 = enemy.global_position - origin
		var dist := to_enemy.length()
		if dist > max_range or dist < 0.001:
			continue
		var angle_to_enemy := aim_dir.angle_to(to_enemy.normalized())
		if absf(angle_to_enemy) > deg_to_rad(cone_half_angle_deg):
			continue
		# El objetivo cercano tiene prioridad dentro del cono de apuntado.
		var score: float = dist + absf(angle_to_enemy) * 150.0
		if score < best_score:
			best_score = score
			best = enemy

	# Revalida OTRA VEZ justo antes de comparar/emitir: cierra cualquier
	# ventana en la que current_target se haya vuelto inválido durante el
	# recorrido de arriba (por ejemplo, si murió en este mismo frame).
	_drop_target_if_invalid()

	if best == null and current_target != null:
		var previous_target: Node2D = current_target
		current_target = null
		target_changed.emit(previous_target, null)
	elif best != null and best != current_target:
		var old_target: Node2D = current_target
		current_target = best
		target_changed.emit(old_target, current_target)

	return current_target

func clear_target() -> void:
	_drop_target_if_invalid()
	if current_target != null:
		var old_target := current_target
		current_target = null
		target_changed.emit(old_target, null)

## Si current_target quedó apuntando a un nodo ya liberado, lo limpia y
## avisa con (null, null) — nunca se manda una referencia liberada a
## través de la señal (eso es lo que causaba "Cannot convert ... Object").
func _drop_target_if_invalid() -> void:
	if current_target != null and not is_instance_valid(current_target):
		current_target = null
		target_changed.emit(null, null)
