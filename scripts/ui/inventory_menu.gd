## Inventario pausado compartido: hasta cuatro paneles compactos caben en la
## pantalla. Cada jugador conserva sus propios seis espacios activos y tres
## de almacenamiento.
class_name InventoryMenu
extends CanvasLayer

@export var panel_size: Vector2 = Vector2(140, 230)
@export var panel_spacing: float = 8.0
@export var slot_size: float = 30.0

var _is_open := false
var _root: Control
var _sheets_container: HBoxContainer
var _selected_slot: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build_ui()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I:
		toggle()
		get_viewport().set_input_as_handled()
	if _is_open and event is InputEventJoypadMotion and event.axis == JOY_AXIS_TRIGGER_LEFT and event.axis_value > 0.5:
		_drop_selected()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if _is_open: close()
	else: open()

func open() -> void:
	_is_open = true
	visible = true
	get_tree().paused = true
	_refresh_sheets()

func close() -> void:
	_is_open = false
	visible = false
	_selected_slot.clear()
	get_tree().paused = false

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var title := Label.new()
	title.text = "INVENTARIO"
	title.position = Vector2(12, 8)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color.WHITE)
	_root.add_child(title)
	var hint := Label.new()
	hint.text = "I: cerrar · clic: mover · L2: tirar"
	hint.position = Vector2(12, 29)
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	_root.add_child(hint)
	var drop_button := Button.new()
	drop_button.text = "Tirar seleccionado"
	drop_button.position = Vector2(210, 8)
	drop_button.size = Vector2(130, 27)
	drop_button.add_theme_font_size_override("font_size", 10)
	drop_button.pressed.connect(_drop_selected)
	_root.add_child(drop_button)
	_sheets_container = HBoxContainer.new()
	_sheets_container.position = Vector2(12, 48)
	_sheets_container.add_theme_constant_override("separation", int(panel_spacing))
	_root.add_child(_sheets_container)

func _refresh_sheets() -> void:
	for child in _sheets_container.get_children(): child.queue_free()
	var players := get_tree().get_nodes_in_group("players")
	players.sort_custom(func(a, b): return a.player_index < b.player_index)
	for player in players:
		_sheets_container.add_child(_build_player_sheet(player))

func _build_player_sheet(player: Node) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = panel_size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14, 0.96)
	style.set_corner_radius_all(5)
	style.set_border_width_all(1)
	style.border_color = Color(0.4, 0.4, 0.5)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var stats: CharacterStats = player.stats
	box.add_child(_label("Jugador %d" % (player.player_index + 1), 12, Color.WHITE))
	box.add_child(_label("HP %d/%d  MP %d/%d  AS %.2f" % [stats.current_health, stats.max_health, stats.current_mana, stats.max_mana, stats.attack_speed], 8, Color(0.75, 0.85, 1.0)))
	box.add_child(_label("STR %d INT %d AGI %d RES %d" % [stats.get_total_strength(), stats.get_total_intelligence(), stats.get_total_agility(), stats.get_total_resistance()], 8, Color(0.9, 0.85, 0.5)))
	box.add_child(_label("FIS %.0f MAG %.0f ARM %.0f (%.0f%%)" % [stats.physical_damage, stats.magic_damage, stats.armor, stats.armor_damage_reduction * 100.0], 8, Color(0.72, 0.82, 0.95)))
	box.add_child(_label("MOV %.0f HR %.1f MR %.1f" % [stats.movement_speed, stats.health_regen, stats.mana_regen], 8, Color(0.8, 0.8, 0.8)))
	box.add_child(_label("CDR %.0f%% CUR +%.0f%%" % [stats.get_total_cooldown_reduction_percent(), stats.get_total_healing_bonus_percent()], 8, Color(0.72, 0.9, 0.75)))
	box.add_child(_label("RATK +%.0f CAST +%.0f" % [stats.get_total_ranged_attack_range_bonus(), stats.get_total_cast_range_bonus()], 8, Color(0.95, 0.78, 0.55)))
	box.add_child(_label("Activos (habilitados)", 9, Color(0.85, 0.9, 0.55)))
	box.add_child(_build_slot_grid(player, "active", 6, Color(0.25, 0.38, 0.26)))
	box.add_child(_label("Almacenamiento (inactivo)", 9, Color(0.65, 0.65, 0.7)))
	box.add_child(_build_slot_grid(player, "storage", 3, Color(0.25, 0.25, 0.3)))
	return panel

func _build_slot_grid(player: Node, slot_group: String, count: int, empty_color: Color) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	for index in range(count):
		var item: Dictionary = player.get_inventory_item(slot_group, index)
		grid.add_child(_build_slot(player, slot_group, index, item, empty_color))
	return grid

func _build_slot(player: Node, slot_group: String, index: int, item: Dictionary, empty_color: Color) -> Button:
	var slot := Button.new()
	slot.custom_minimum_size = Vector2(slot_size, slot_size)
	slot.tooltip_text = item.get("name", "Vacío")
	slot.text = item.get("short_name", "·")
	slot.add_theme_font_size_override("font_size", 9)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.75, 0.62, 0.2) if not item.is_empty() else empty_color
	style.set_corner_radius_all(3)
	style.set_border_width_all(2 if _is_selected(player, slot_group, index) else 1)
	style.border_color = Color(1.0, 0.95, 0.35) if _is_selected(player, slot_group, index) else Color(0.55, 0.55, 0.62)
	slot.add_theme_stylebox_override("normal", style)
	slot.pressed.connect(func(): _on_slot_pressed(player, slot_group, index))
	return slot

func _label(text_value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	return label

func _on_slot_pressed(player: Node, slot_group: String, index: int) -> void:
	var item: Dictionary = player.get_inventory_item(slot_group, index)
	if _selected_slot.is_empty():
		if item.is_empty(): return
		_selected_slot = {"player": player, "group": slot_group, "index": index}
	elif _selected_slot.player == player and _selected_slot.group == slot_group and _selected_slot.index == index:
		## Segundo clic izquierdo en el mismo objeto: se tira al suelo.
		_drop_selected()
		return
	else:
		_selected_slot.player.swap_inventory_slots(_selected_slot.group, _selected_slot.index, slot_group, index)
		_selected_slot.clear()
	_refresh_sheets()

func _is_selected(player: Node, slot_group: String, index: int) -> bool:
	return not _selected_slot.is_empty() and _selected_slot.player == player and _selected_slot.group == slot_group and _selected_slot.index == index

func _drop_selected() -> void:
	if _selected_slot.is_empty(): return
	_selected_slot.player.drop_inventory_item(_selected_slot.group, _selected_slot.index)
	_selected_slot.clear()
	_refresh_sheets()
