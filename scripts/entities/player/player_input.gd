## PlayerInput.gd
## Componente de entrada por jugador. Soporta teclado+mouse (device_id = -1)
## o mando/gamepad (device_id = 0..3). Se agrega como hijo de cada Player.
##
## Lee el hardware directamente en vez de depender del InputMap de
## Project Settings, así que funciona apenas agregas el script: no hace
## falta configurar nada en el editor. Esto también evita el problema de
## que dos jugadores "compartan" la misma acción del InputMap.
class_name PlayerInput
extends Node

## -1 = teclado/mouse | 0, 1, 2, 3 = índice del mando (Input.get_connected_joypads())
@export var device_id: int = -1

const STICK_DEADZONE := 0.2
const AIM_STICK_DEADZONE := 0.42
const TRIGGER_THRESHOLD := 0.5
const MOUSE_AIM_MIN_DIST := 4.0

const BUTTON_ACTIONS := [
	"attack", "cancel_attack",
	"ability_1", "ability_2", "ability_3", "ultimate",
	"gadget", "sprint", "inventory", "pause",
	"revive", "interact_pickup", "use_tool",
]

var _held: Dictionary = {}
var _held_prev: Dictionary = {}

func _ready() -> void:
	for action in BUTTON_ACTIONS:
		_held[action] = false
		_held_prev[action] = false

# Se actualiza en physics_process (no en _process) para que quede sincronizado
# con Player.gd, que también corre su lógica en _physics_process.
func _physics_process(_delta: float) -> void:
	_held_prev = _held.duplicate()
	for action in BUTTON_ACTIONS:
		_held[action] = _read_raw_button(action)

# ---------------------------------------------------------------------------
# Consultas públicas (usadas desde Player.gd)
# ---------------------------------------------------------------------------

func is_pressed(action: String) -> bool:
	return _held.get(action, false)

func is_just_pressed(action: String) -> bool:
	return _held.get(action, false) and not _held_prev.get(action, false)

func is_just_released(action: String) -> bool:
	return not _held.get(action, false) and _held_prev.get(action, false)

## Vector de movimiento normalizado (-1..1 en cada eje). WASD o stick izq.
func get_move_vector() -> Vector2:
	var v := Vector2.ZERO
	if device_id == -1:
		v.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
		v.y = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	else:
		v.x = Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
		v.y = Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
		if v.length() < STICK_DEADZONE:
			return Vector2.ZERO
	return v.limit_length(1.0)

## Dirección de apuntado desde la posición del jugador (para elegir objetivo).
## Teclado: hacia el mouse. Mando: dirección del stick derecho.
## Devuelve Vector2.ZERO si no hay una dirección "intencional" clara
## (mouse casi encima del jugador, o stick derecho centrado / dentro de deadzone).
func get_aim_vector(from_node: Node2D) -> Vector2:
	if device_id == -1:
		var mouse_pos := from_node.get_global_mouse_position()
		var to_mouse := mouse_pos - from_node.global_position
		if to_mouse.length() < MOUSE_AIM_MIN_DIST:
			return Vector2.ZERO
		return to_mouse.normalized()
	else:
		var v := Vector2(
			Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X),
			Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y)
		)
		if v.length() < AIM_STICK_DEADZONE:
			return Vector2.ZERO
		return v.normalized()

# ---------------------------------------------------------------------------
# Lectura directa de hardware
# ---------------------------------------------------------------------------

func _read_raw_button(action: String) -> bool:
	if device_id == -1:
		return _read_keyboard_mouse(action)
	return _read_gamepad(action)

func _read_keyboard_mouse(action: String) -> bool:
	match action:
		"attack":
			return Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		"cancel_attack":
			return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		"ability_1":
			return Input.is_key_pressed(KEY_1)
		"ability_2":
			return Input.is_key_pressed(KEY_2)
		"ability_3":
			return Input.is_key_pressed(KEY_3)
		"ultimate":
			return Input.is_key_pressed(KEY_4)
		"gadget":
			return Input.is_key_pressed(KEY_E)
		"sprint":
			return Input.is_key_pressed(KEY_SHIFT)
		"inventory":
			return Input.is_key_pressed(KEY_I)
		"pause":
			return Input.is_key_pressed(KEY_ESCAPE)
		"revive":
			return Input.is_key_pressed(KEY_U)
		"interact_pickup":
			return Input.is_key_pressed(KEY_F)
		"use_tool":
			return Input.is_key_pressed(KEY_R)
	return false

func _read_gamepad(action: String) -> bool:
	match action:
		"attack":
			return Input.get_joy_axis(device_id, JOY_AXIS_TRIGGER_RIGHT) > TRIGGER_THRESHOLD
		"cancel_attack":
			return Input.get_joy_axis(device_id, JOY_AXIS_TRIGGER_LEFT) > TRIGGER_THRESHOLD
		"ability_1":
			return Input.is_joy_button_pressed(device_id, JOY_BUTTON_Y)
		"ability_2":
			return Input.is_joy_button_pressed(device_id, JOY_BUTTON_A)
		"ability_3":
			return Input.is_joy_button_pressed(device_id, JOY_BUTTON_B)
		"ultimate":
			return Input.is_joy_button_pressed(device_id, JOY_BUTTON_RIGHT_STICK)
		"gadget":
			return Input.is_joy_button_pressed(device_id, JOY_BUTTON_LEFT_SHOULDER)
		"sprint":
			return Input.is_joy_button_pressed(device_id, JOY_BUTTON_LEFT_STICK)
		"inventory":
			return Input.is_joy_button_pressed(device_id, JOY_BUTTON_BACK)
		"pause":
			return Input.is_joy_button_pressed(device_id, JOY_BUTTON_START)
		"revive":
			return Input.is_joy_button_pressed(device_id, JOY_BUTTON_DPAD_UP)
		"interact_pickup":
			return Input.is_joy_button_pressed(device_id, JOY_BUTTON_X)
		"use_tool":
			return Input.is_joy_button_pressed(device_id, JOY_BUTTON_RIGHT_SHOULDER)
	return false
