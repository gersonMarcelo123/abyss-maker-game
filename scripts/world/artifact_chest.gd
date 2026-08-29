## Armario de accesorios persistentes. Cada artefacto ocupa un tipo único
## (Runa, Manual, Pulsera, Lente o Anillo) para un único jugador.
class_name ArtifactChest
extends Area2D

const ACCESSORIES: Array[Dictionary] = [
	{"id":"runa_valor","name":"Runa de Valor","type":"Runa","bonuses":{"physical_damage":10.0,"strength":3}},
	{"id":"runa_sabiduria","name":"Runa de Sabiduría","type":"Runa","bonuses":{"magic_damage":10.0,"intelligence":3}},
	{"id":"runa_guardia","name":"Runa de Guardia","type":"Runa","bonuses":{"armor":8.0}},
	{"id":"manual_estrategia","name":"Manual de Estrategia","type":"Manual","bonuses":{"cooldown_reduction_percent":8.0}},
	{"id":"manual_marcial","name":"Manual Marcial","type":"Manual","bonuses":{"move_speed_percent":8.0}},
	{"id":"manual_curacion","name":"Manual de Curación","type":"Manual","bonuses":{"healing_bonus_percent":12.0}},
	{"id":"pulsera_vitalidad","name":"Pulsera de Vitalidad","type":"Pulsera","bonuses":{"resistance":4,"armor":5.0}},
	{"id":"pulsera_rapidez","name":"Pulsera de Rapidez","type":"Pulsera","bonuses":{"agility":4,"move_speed_percent":5.0}},
	{"id":"pulsera_fuerza","name":"Pulsera de Fuerza","type":"Pulsera","bonuses":{"strength":4}},
	{"id":"lente_enfoque","name":"Lente de Enfoque","type":"Lente","bonuses":{"ranged_attack_range":20.0,"cast_range":20.0}},
	{"id":"lente_mistico","name":"Lente Místico","type":"Lente","bonuses":{"magic_damage":15.0}},
	{"id":"lente_precision","name":"Lente de Precisión","type":"Lente","bonuses":{"physical_damage":7.0,"ranged_attack_range":12.0}},
	{"id":"anillo_poder","name":"Anillo de Poder","type":"Anillo","bonuses":{"physical_damage":12.0,"magic_damage":12.0}},
	{"id":"anillo_vida","name":"Anillo de Vida","type":"Anillo","bonuses":{"healing_bonus_percent":15.0}},
	{"id":"anillo_barrera","name":"Anillo de Barrera","type":"Anillo","bonuses":{"armor":12.0}},
]

var _player_nearby: Player = null
var _menu_root: CanvasLayer = null
var _selected_player_index := 0
var _focused_accessory: Dictionary = {}
var _l2_held := false
var _tooltip: AccessoryTooltip = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_visual()

func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby == null:
		return
	var pressed_e: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E
	var pressed_joy: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_LEFT_SHOULDER
	if pressed_e or pressed_joy:
		if _menu_root == null: _open_chest_menu()
		else: _close_chest_menu()
		get_viewport().set_input_as_handled()
	if _menu_root != null and event is InputEventJoypadMotion and event.axis == JOY_AXIS_TRIGGER_LEFT:
		if event.axis_value < 0.2:
			_l2_held = false
		elif event.axis_value > 0.5 and not _l2_held and not _focused_accessory.is_empty():
			_l2_held = true
			_toggle_accessory(_focused_accessory)
			get_viewport().set_input_as_handled()

func _on_body_entered(body: Node) -> void:
	if body is Player: _player_nearby = body

func _on_body_exited(body: Node) -> void:
	if body == _player_nearby:
		_player_nearby = null
		_close_chest_menu()

func _build_visual() -> void:
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([Vector2(-12,-10),Vector2(12,-10),Vector2(12,10),Vector2(-12,10)])
	visual.color = Color(0.85, 0.65, 0.2)
	add_child(visual)
	var label := Label.new()
	label.text = "Baúl [E]"
	label.position = Vector2(-30, -28)
	label.add_theme_font_size_override("font_size", 10)
	add_child(label)

func _open_chest_menu() -> void:
	_selected_player_index = _player_nearby.player_index
	_menu_root = CanvasLayer.new()
	_menu_root.layer = 15
	_menu_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_menu_root)
	var dim := ColorRect.new()
	dim.color = Color(0,0,0,0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_root.add_child(dim)
	_rebuild_chest_menu()

func _rebuild_chest_menu() -> void:
	for child in _menu_root.get_children():
		if child is Control and child.name != "Dim": child.queue_free()
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 16; scroll.offset_top = 12; scroll.offset_right = -16; scroll.offset_bottom = -12
	_menu_root.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	box.add_child(_text("BAÚL DE ACCESORIOS", 13, Color.WHITE))
	box.add_child(_text("Clic/L2: equipar o desequipar.", 8, Color(0.8,0.8,0.85)))
	box.add_child(_build_player_equipment())
	box.add_child(_text("Artefactos almacenados", 13, Color(0.9,0.8,0.4)))
	for start in range(0, ACCESSORIES.size(), 24):
		box.add_child(_build_accessory_section(start))
	var close := Button.new()
	close.text = "Cerrar"
	close.pressed.connect(_close_chest_menu)
	box.add_child(close)

func _build_player_equipment() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 5)
	for player_index in range(4):
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(98, 80)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.15,0.25,0.38) if player_index == _selected_player_index else Color(0.1,0.1,0.14)
		style.set_border_width_all(1)
		style.border_color = Color(0.35,0.7,1.0)
		panel.add_theme_stylebox_override("panel", style)
		var rows := VBoxContainer.new()
		panel.add_child(rows)
		var header := Button.new()
		header.text = "Jugador %d" % (player_index + 1)
		header.add_theme_font_size_override("font_size", 8)
		header.pressed.connect(func(): _selected_player_index = player_index; _rebuild_chest_menu())
		rows.add_child(header)
		var equipped: Dictionary = GameState.get_accessories(player_index)
		for slot_name in Player.ACCESSORY_SLOTS:
			var acc: Dictionary = equipped.get(slot_name, {})
			rows.add_child(_text("%s %s" % [AccessoryPresentation.icon_for(acc) if not acc.is_empty() else "▫", slot_name.left(3)], 7, AccessoryPresentation.tier_color(acc) if not acc.is_empty() else Color(0.55,0.55,0.6)))
		grid.add_child(panel)
	return grid

func _build_accessory_section(start: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for index in range(start, min(start + 24, ACCESSORIES.size())):
		var accessory: Dictionary = _prepared_accessory(ACCESSORIES[index], index)
		var button := Button.new()
		button.custom_minimum_size = Vector2(94, 24)
		var in_use: bool = GameState.is_equipped_by_other_player(str(accessory.get("id", "")), _selected_player_index)
		button.disabled = in_use
		button.text = AccessoryPresentation.icon_for(accessory)
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_color_override("font_color", AccessoryPresentation.tier_color(accessory))
		button.add_theme_color_override("font_disabled_color", AccessoryPresentation.tier_color(accessory).darkened(0.55))
		button.add_theme_stylebox_override("normal", AccessoryPresentation.tier_slot_style(accessory))
		button.add_theme_stylebox_override("hover", AccessoryPresentation.tier_slot_style(accessory, true))
		button.add_theme_stylebox_override("pressed", AccessoryPresentation.tier_slot_style(accessory, true))
		button.add_theme_stylebox_override("disabled", AccessoryPresentation.tier_slot_style(accessory, false, true))
		button.tooltip_text = "Ocupado" if in_use else "Equipar en Jugador %d" % (_selected_player_index + 1)
		button.pressed.connect(func(): _toggle_accessory(accessory))
		button.focus_entered.connect(func(): _focused_accessory = accessory)
		button.mouse_entered.connect(func(): _show_tooltip(accessory, button.global_position))
		button.mouse_exited.connect(_clear_tooltip)
		grid.add_child(button)
	return grid

func _toggle_accessory(accessory: Dictionary) -> void:
	var slot_name: String = str(accessory.get("type", ""))
	var equipped: Dictionary = GameState.get_accessories(_selected_player_index)
	var current: Dictionary = equipped.get(slot_name, {})
	GameState.set_accessory(_selected_player_index, slot_name, {} if current.get("id", "") == accessory.get("id", "") else accessory)
	if _player_nearby.player_index == _selected_player_index:
		_player_nearby.accessory_inventory = GameState.get_accessories(_selected_player_index)
		_player_nearby.refresh_accessory_bonuses()
	_rebuild_chest_menu()

func _prepared_accessory(source: Dictionary, index: int) -> Dictionary:
	var accessory: Dictionary = source.duplicate(true)
	var tier: int = index % 5 + 1
	accessory["tier"] = tier
	var bonuses: Dictionary = accessory.get("bonuses", {}).duplicate(true)
	var keys: Array = bonuses.keys()
	if not keys.is_empty():
		var main_key := str(keys[0])
		bonuses[main_key] = 3.0 + (tier - 1) * 2.0
	var secondary_pool: Array[String] = ["armor", "agility", "resistance", "move_speed_percent", "cast_range"]
	for secondary_index in range(tier - 1):
		var key: String = secondary_pool[secondary_index]
		if not bonuses.has(key): bonuses[key] = 1.0 + secondary_index * 0.5
	accessory["bonuses"] = bonuses
	return accessory

func _show_tooltip(accessory: Dictionary, at_position: Vector2) -> void:
	_clear_tooltip()
	_tooltip = AccessoryTooltip.new()
	_menu_root.add_child(_tooltip)
	_tooltip.show_accessory(accessory, at_position)

func _clear_tooltip() -> void:
	if is_instance_valid(_tooltip): _tooltip.queue_free()
	_tooltip = null

func _text(value: String, font_size: int, text_color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", text_color)
	return label

func _close_chest_menu() -> void:
	if _menu_root:
		_clear_tooltip()
		_menu_root.queue_free()
		_menu_root = null
