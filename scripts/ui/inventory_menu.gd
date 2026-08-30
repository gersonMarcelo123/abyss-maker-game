## Inventario pausado compartido: hasta cuatro paneles compactos caben en la
## pantalla. Cada jugador conserva sus propios seis espacios activos y tres
## de almacenamiento.
class_name InventoryMenu
extends CanvasLayer

@export var panel_size: Vector2 = Vector2(116, 220)
@export var panel_spacing: float = 8.0
@export var slot_size: float = 21.0

var _is_open := false
var _root: Control
var _sheets_container: HBoxContainer
var _selected_slot: Dictionary = {}
var _accessory_tooltip: AccessoryTooltip = null

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
	_clear_accessory_tooltip()
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
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color.WHITE)
	_root.add_child(title)
	var hint := Label.new()
	hint.text = "I: cerrar · clic: mover · L2: tirar"
	hint.position = Vector2(12, 29)
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	_root.add_child(hint)
	var drop_button := Button.new()
	drop_button.text = "Tirar seleccionado"
	drop_button.position = Vector2(145, 6)
	drop_button.size = Vector2(92, 19)
	drop_button.add_theme_font_size_override("font_size", 7)
	drop_button.pressed.connect(_drop_selected)
	_root.add_child(drop_button)
	_sheets_container = HBoxContainer.new()
	_sheets_container.position = Vector2(8, 33)
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
	box.add_child(_label("J%d" % (player.player_index + 1), 9, Color.WHITE))
	box.add_child(_label("HP %d MP %d AS %.1f" % [stats.current_health, stats.current_mana, stats.attack_speed], 6, Color(0.75, 0.85, 1.0)))
	box.add_child(_label("S%d I%d A%d R%d" % [stats.get_total_strength(), stats.get_total_intelligence(), stats.get_total_agility(), stats.get_total_resistance()], 6, Color(0.9, 0.85, 0.5)))
	box.add_child(_label("F%.0f M%.0f Ar%.0f" % [stats.physical_damage, stats.magic_damage, stats.armor], 6, Color(0.72, 0.82, 0.95)))
	box.add_child(_label("Activos", 7, Color(0.85, 0.9, 0.55)))
	box.add_child(_build_slot_grid(player, "active", 6, Color(0.25, 0.38, 0.26)))
	box.add_child(_label("Guardado", 7, Color(0.65, 0.65, 0.7)))
	box.add_child(_build_slot_grid(player, "storage", 3, Color(0.25, 0.25, 0.3)))
	box.add_child(_label("Accesorios", 7, Color(0.4, 0.8, 1.0)))
	box.add_child(_build_accessory_grid(player))
	return panel

func _build_accessory_grid(player: Node) -> GridContainer:
	var container := GridContainer.new()
	container.columns = 5
	for acc_name in Player.ACCESSORY_SLOTS:
		var item: Dictionary = player.accessory_inventory.get(acc_name, {})
		var icon := Button.new()
		icon.custom_minimum_size = Vector2(18, 18)
		icon.text = AccessoryPresentation.icon_for(item) if not item.is_empty() else "▫"
		icon.add_theme_color_override("font_color", AccessoryPresentation.tier_color(item) if not item.is_empty() else Color(0.55, 0.55, 0.6))
		icon.add_theme_stylebox_override("normal", AccessoryPresentation.tier_slot_style(item))
		icon.add_theme_stylebox_override("hover", AccessoryPresentation.tier_slot_style(item, true))
		icon.add_theme_stylebox_override("pressed", AccessoryPresentation.tier_slot_style(item, true))
		icon.focus_mode = Control.FOCUS_NONE
		icon.tooltip_text = acc_name
		if not item.is_empty():
			icon.mouse_filter = Control.MOUSE_FILTER_STOP
			icon.mouse_entered.connect(func(): _show_accessory_tooltip(item, icon.global_position))
			icon.mouse_exited.connect(_clear_accessory_tooltip)
		container.add_child(icon)
	return container

func _show_accessory_tooltip(accessory: Dictionary, at_position: Vector2) -> void:
	_clear_accessory_tooltip()
	_accessory_tooltip = AccessoryTooltip.new()
	_root.add_child(_accessory_tooltip)
	_accessory_tooltip.show_accessory(accessory, at_position)

func _clear_accessory_tooltip() -> void:
	if is_instance_valid(_accessory_tooltip): _accessory_tooltip.queue_free()
	_accessory_tooltip = null

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
