## AttackComponent.gd
## Controla el ciclo de auto-ataque:
##  - Si el objetivo está fuera de rango, indica que hay que ACERCARSE.
##  - Al entrar en rango y con cooldown listo, arranca un "windup"
##    (retraso previo al golpe, para animación) de attack_windup_duration
##    segundos. Al terminar el windup, recién ahí se aplica el golpe real
##    (attack_fired) — mele instantáneo o proyectil, según Player.gd.
##  - La cadencia real (attacks_per_second, que depende de la agilidad vía
##    CharacterStats) sigue gobernando cada cuánto se puede INICIAR un
##    nuevo windup, exactamente igual que antes.
##  - Se cancela al soltar el botón, pulsar cancelar, o perder el objetivo
##    — incluso a mitad de un windup.
class_name AttackComponent
extends Node

enum AttackType { MELEE, RANGED }

@export var attack_type: AttackType = AttackType.MELEE
@export var attack_range: float = 60.0 ## rango de golpe mele o distancia mínima de disparo
@export var attacks_per_second: float = 1.2
@export var attack_windup_duration: float = 0.4 ## retraso antes del golpe, para la animación de ataque

var is_attacking: bool = false      ## true mientras está "trabado" con el objetivo (windup o esperando cooldown)
var is_winding_up: bool = false     ## true solo durante el retraso previo al golpe

var _cooldown: float = 0.0          ## tiempo hasta poder INICIAR el próximo windup
var _windup_remaining: float = -1.0 ## -1 = no hay windup en curso
var _pending_target: Node2D = null

## Se emite justo cuando ARRANCA el retraso, antes del golpe — conéctalo
## para disparar la animación de "cargando ataque".
signal attack_windup_started(target: Node2D)
## Se emite cuando el golpe realmente ocurre (al final del windup) — este
## es el que ya usa Player.gd para aplicar daño o lanzar el proyectil.
signal attack_fired(target: Node2D)
signal attack_started
signal attack_cancelled

func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

	if _windup_remaining >= 0.0:
		_windup_remaining -= delta
		if _windup_remaining <= 0.0:
			_windup_remaining = -1.0
			is_winding_up = false
			var target := _pending_target
			_pending_target = null
			if is_instance_valid(target):
				attack_fired.emit(target)

## owner_body: el jugador (para leer su posición).
## target: enemigo actual seleccionado (puede ser null).
## want_attack: true si el botón de atacar está sostenido y no se canceló.
## Devuelve true si Player.gd debe MOVER al personaje hacia el objetivo
## este frame (todavía fuera de rango). Devuelve false si debe quedarse
## quieto (ya sea porque está atacando/en windup, o porque no hay nada que hacer).
func process_attack(owner_body: Node2D, target: Node2D, want_attack: bool) -> bool:
	if not want_attack or not is_instance_valid(target):
		_stop_attacking()
		return false

	var distance := owner_body.global_position.distance_to(target.global_position)
	var start_strike_range := attack_range * 0.7 if attack_type == AttackType.MELEE else attack_range * 0.95
	var keep_strike_range := attack_range * 1.4

	# Si ya está cargando el golpe, no lo cancela a menos que el objetivo escape mucho del rango
	if is_winding_up:
		if distance > keep_strike_range:
			_stop_attacking()
			return true
		return false

	var in_strike_range := distance <= start_strike_range

	if not in_strike_range:
		is_attacking = false
		return true

	if not is_attacking:
		is_attacking = true
		attack_started.emit()

	if _windup_remaining < 0.0 and _cooldown <= 0.0:
		var effective_windup := attack_windup_duration
		if attack_type == AttackType.MELEE:
			effective_windup = min(attack_windup_duration, 0.18)
		_windup_remaining = effective_windup
		_pending_target = target
		_cooldown = 1.0 / max(attacks_per_second, 0.01)
		is_winding_up = true
		attack_windup_started.emit(target)

	return false

func cancel() -> void:
	_stop_attacking()

func _stop_attacking() -> void:
	if is_attacking:
		is_attacking = false
		attack_cancelled.emit()
	# Cancela también cualquier windup en curso — si sueltas el botón a
	# mitad de la animación de carga, el golpe no debe salir igual.
	_windup_remaining = -1.0
	is_winding_up = false
	_pending_target = null
