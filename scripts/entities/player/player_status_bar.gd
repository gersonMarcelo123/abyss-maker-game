## PlayerStatusBar.gd
## Barra de vida (roja) y maná (azul) flotando sobre la cabeza del jugador,
## en el MUNDO (no en pantalla) — así que lo sigue automáticamente, y se ve
## más chica/grande según el zoom de la cámara.
##
## La barra de vida tiene además una franja BLANCA ("daño rezagado"): al
## recibir daño, se queda marcando por un instante cuánta vida tenías antes
## del golpe, y luego desciende suavemente hasta alcanzar la vida actual —
## efecto clásico de WoW/Diablo para que el ojo note cuánto perdiste.
##
## Ponla como hija directa de Player (NO de BodyPlaceholder, para que no
## herede su rotación). Player.gd la detecta y la conecta sola si existe.
##
## `horizontal_scale` / `vertical_scale` son para las pruebas de tamaño.
class_name PlayerStatusBar
extends Node2D

@export var offset: Vector2 = Vector2(0, -42) ## posición relativa a los pies del jugador
@export var bar_width: float = 40.0
@export var bar_height: float = 5.0
@export var bar_spacing: float = 2.0
@export var horizontal_scale: float = 1.0
@export var vertical_scale: float = 1.0

@export_group("Daño rezagado (barra blanca)")
@export var damage_flash_delay: float = 0.3   ## pausa antes de empezar a bajar, tras recibir daño
@export var damage_flash_speed: float = 60.0  ## puntos de vida por segundo a los que baja la franja blanca

var _health_ratio: float = 1.0
var _mana_ratio: float = 1.0

var _health_current: float = 100.0
var _health_max: float = 100.0
var _flash_health: float = 100.0     ## valor (absoluto, no ratio) que muestra la franja blanca
var _flash_delay_timer: float = 0.0

@onready var _health_bg: Polygon2D = $HealthBG
@onready var _health_flash: Polygon2D = $HealthFlash
@onready var _health_fill: Polygon2D = $HealthFill
@onready var _mana_bg: Polygon2D = $ManaBG
@onready var _mana_fill: Polygon2D = $ManaFill

func _ready() -> void:
	_health_bg.color = Color(0, 0, 0, 0.55)
	_health_flash.color = Color(1.0, 1.0, 1.0, 0.85)
	_health_fill.color = Color(0.85, 0.2, 0.2)
	_mana_bg.color = Color(0, 0, 0, 0.55)
	_mana_fill.color = Color(0.25, 0.45, 0.9)
	_rebuild()

func _process(delta: float) -> void:
	if _flash_health > _health_current:
		if _flash_delay_timer > 0.0:
			_flash_delay_timer -= delta
		else:
			_flash_health = max(_flash_health - damage_flash_speed * delta, _health_current)
		_rebuild()

## Conecta la barra a las stats de su jugador. Player.gd la llama solo si
## este nodo existe en la escena.
func bind(stats: CharacterStats) -> void:
	if not stats.health_changed.is_connected(_on_health_changed):
		stats.health_changed.connect(_on_health_changed)
	if not stats.mana_changed.is_connected(_on_mana_changed):
		stats.mana_changed.connect(_on_mana_changed)
	_health_current = stats.current_health
	_health_max = stats.max_health
	_flash_health = stats.current_health
	_on_health_changed(stats.current_health, stats.max_health)
	_on_mana_changed(stats.current_mana, stats.max_mana)

func _on_health_changed(current: float, max_value: float) -> void:
	var lost := _health_current - current # positivo si la vida bajó
	_health_current = current
	_health_max = max_value
	_health_ratio = clamp(current / max(max_value, 0.001), 0.0, 1.0)

	if lost > 0.0:
		# Bajó vida: la franja blanca arranca (o sigue) desde donde estaba,
		# nunca por debajo del nuevo actual, y reinicia la pausa antes de
		# empezar a descender.
		_flash_health = max(_flash_health, current + lost)
		_flash_delay_timer = damage_flash_delay

	# Nunca debe quedar por debajo de la vida actual (p. ej. si te curan de
	# golpe). Fuera de eso NO se toca en curaciones/regeneración pasiva —
	# así la resistencia regenerando de a poquito no cancela el rastro de
	# un golpe reciente en cada tick.
	_flash_health = max(_flash_health, _health_current)

	_rebuild()

func _on_mana_changed(current: float, max_value: float) -> void:
	_mana_ratio = clamp(current / max(max_value, 0.001), 0.0, 1.0)
	_rebuild()

func _rebuild() -> void:
	var w := bar_width * horizontal_scale
	var h := bar_height * vertical_scale
	var gap := bar_spacing * vertical_scale
	var top_left := offset - Vector2(w / 2.0, 0)

	var flash_ratio: float = clampf(_flash_health / max(_health_max, 0.001), 0.0, 1.0)

	_health_bg.polygon = _rect(w, h)
	_health_bg.position = top_left
	_health_flash.polygon = _rect(w * flash_ratio, h)
	_health_flash.position = top_left
	_health_fill.polygon = _rect(w * _health_ratio, h)
	_health_fill.position = top_left

	var mana_top_left := top_left + Vector2(0, h + gap)
	_mana_bg.polygon = _rect(w, h)
	_mana_bg.position = mana_top_left
	_mana_fill.polygon = _rect(w * _mana_ratio, h)
	_mana_fill.position = mana_top_left

func _rect(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)])
