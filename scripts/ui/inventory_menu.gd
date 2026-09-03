## Inventario pausado compartido: hasta cuatro paneles compactos caben en la
## pantalla. Cada jugador conserva sus propios seis espacios activos y tres
## de almacenamiento.
class_name InventoryMenu
extends CanvasLayer

@export var panel_size: Vector2 = Vector2(152, 220)
@export var panel_spacing: float = 8.0
@export var slot_size: float = 21.0

var _is_open := false
var _root: Control
var _sheets_container: HBoxContainer
var _selected_slot: Dictionary = {}
var _accessory_tooltip: AccessoryTooltip = null
var _info_panel: PanelContainer = null


func _ready() -> void:
	add_to_group("inventory_menus")
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
	for chest in get_tree().get_nodes_in_group("artifact_chests"):
		if chest.has_method("is_menu_open") and chest.is_menu_open():
			return
	for chest in get_tree().get_nodes_in_group("weapon_chests"):
		if chest.has_method("is_menu_open") and chest.is_menu_open():
			return
	_is_open = true
	visible = true
	get_tree().paused = true
	_refresh_sheets()

func close() -> void:
	_is_open = false
	visible = false
	_selected_slot.clear()
	_clear_accessory_tooltip()
	_clear_info_panel()
	get_tree().paused = false

func is_open() -> bool:
	return _is_open

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# Fondo oscuro
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	# --- Título centrado en la parte superior ---
	var header := VBoxContainer.new()
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.anchor_left = 0.0
	header.anchor_right = 1.0
	header.anchor_top = 0.0
	header.anchor_bottom = 0.0
	header.offset_top = 10
	header.offset_bottom = 52
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 2)
	_root.add_child(header)

	var title := Label.new()
	title.text = "INVENTARIO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color.WHITE)
	header.add_child(title)

	var hint := Label.new()
	hint.text = "I: cerrar  ·  clic: mover  ·  L2: tirar"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	header.add_child(hint)

	# --- Paneles de jugadores, centrados y debajo del header ---
	var sheets_wrapper := CenterContainer.new()
	sheets_wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheets_wrapper.offset_top = 58  # deja espacio al header
	_root.add_child(sheets_wrapper)

	_sheets_container = HBoxContainer.new()
	_sheets_container.add_theme_constant_override("separation", int(panel_spacing))
	sheets_wrapper.add_child(_sheets_container)


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
	box.add_child(_label("Vida: %d · Maná: %d · Velocidad de ataque: %.1f" % [stats.current_health, stats.current_mana, stats.attack_speed], 6, Color(0.75, 0.85, 1.0)))
	box.add_child(_label("Fuerza: %d · Inteligencia: %d" % [stats.get_total_strength(), stats.get_total_intelligence()], 6, Color(0.9, 0.85, 0.5)))
	box.add_child(_label("Agilidad: %d · Resistencia: %d" % [stats.get_total_agility(), stats.get_total_resistance()], 6, Color(0.9, 0.85, 0.5)))
	box.add_child(_label("Daño físico: %.0f · Daño mágico: %.0f · Armadura: %.0f" % [stats.physical_damage, stats.magic_damage, stats.armor], 6, Color(0.72, 0.82, 0.95)))
	box.add_child(_label("Activos", 7, Color(0.85, 0.9, 0.55)))
	# Los dos slots especiales quedan exactamente al lado derecho de los
	# activos y alineados con sus dos filas, como la referencia visual.
	var active_row := HBoxContainer.new()
	active_row.add_theme_constant_override("separation", 14)
	active_row.add_child(_build_slot_grid(player, "active", 6, Color(0.25, 0.38, 0.26)))
	var special_slots := VBoxContainer.new()
	special_slots.add_theme_constant_override("separation", 3)
	special_slots.add_child(_build_weapon_slot(player))
	special_slots.add_child(_build_tool_slot(player))
	active_row.add_child(special_slots)
	box.add_child(active_row)
	box.add_child(_label("Guardado", 7, Color(0.65, 0.65, 0.7)))
	box.add_child(_build_slot_grid(player, "storage", 3, Color(0.25, 0.25, 0.3)))
	box.add_child(_label("Accesorios", 7, Color(0.4, 0.8, 1.0)))
	box.add_child(_build_accessory_grid(player))

	return panel

func _build_weapon_slot(player: Node) -> Button:
	var item: Dictionary = player.get_inventory_item("weapon", 0)
	var slot := _build_slot(player, "weapon", 0, item, Color(0.1, 0.1, 0.14))
	slot.custom_minimum_size = Vector2(slot_size, slot_size)
	slot.tooltip_text = "Arma: " + str(item.get("name", "Vacío"))
	return slot

func _build_tool_slot(player: Node) -> Button:
	var item: Dictionary = player.get_inventory_item("tool", 0)
	var slot := _build_slot(player, "tool", 0, item, Color(0.1, 0.1, 0.14))
	slot.custom_minimum_size = Vector2(slot_size, slot_size)
	slot.tooltip_text = "Herramienta: " + str(item.get("name", "Vacío"))
	return slot

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
		if item.is_empty():
			_clear_info_panel()
			return
		_selected_slot = {"player": player, "group": slot_group, "index": index}
		_show_info_panel(item, player, slot_group, index)
	elif _selected_slot.player == player and _selected_slot.group == slot_group and _selected_slot.index == index:
		## Segundo clic izquierdo en el mismo objeto: se tira al suelo.
		_drop_selected()
		return
	else:
		_selected_slot.player.swap_inventory_slots(_selected_slot.group, _selected_slot.index, slot_group, index)
		_selected_slot.clear()
		_clear_info_panel()
	_refresh_sheets()

func _is_selected(player: Node, slot_group: String, index: int) -> bool:
	return not _selected_slot.is_empty() and _selected_slot.player == player and _selected_slot.group == slot_group and _selected_slot.index == index

func _drop_selected() -> void:
	if _selected_slot.is_empty(): return
	_selected_slot.player.drop_inventory_item(_selected_slot.group, _selected_slot.index)
	_selected_slot.clear()
	_clear_info_panel()
	_refresh_sheets()

func _clear_info_panel() -> void:
	if is_instance_valid(_info_panel):
		_info_panel.queue_free()
	_info_panel = null

func _show_info_panel(item: Dictionary, player: Node, slot_group: String, index: int) -> void:
	_clear_info_panel()
	if item.is_empty(): return

	_info_panel = PanelContainer.new()
	_info_panel.anchor_left = 0.5
	_info_panel.anchor_right = 0.5
	_info_panel.anchor_top = 1.0
	_info_panel.anchor_bottom = 1.0
	_info_panel.offset_left = -220
	_info_panel.offset_right = 220
	_info_panel.offset_top = -92
	_info_panel.offset_bottom = -6

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.98)
	style.border_color = AccessoryPresentation.tier_color(item)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_info_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_info_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	_info_panel.add_child(vbox)

	# Fila 1: Nombre + Tier + Categoría
	var header_row := HBoxContainer.new()
	vbox.add_child(header_row)

	var name_lbl := Label.new()
	name_lbl.text = str(item.get("name", "Objeto"))
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", AccessoryPresentation.tier_color(item))
	header_row.add_child(name_lbl)

	var tier_val: int = int(item.get("tier", 1))
	var kind_val: String = str(item.get("kind", "item")).capitalize()
	var lvl_str := (" · Nivel %d" % int(item.get("level", 1))) if item.has("level") else ""
	var tag_lbl := Label.new()
	tag_lbl.text = " [Tier %d] · %s%s" % [tier_val, kind_val, lvl_str]
	tag_lbl.add_theme_font_size_override("font_size", 8)
	tag_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	header_row.add_child(tag_lbl)

	# Fila 2: Descripción y Atributos
	var desc_text := str(item.get("description", ""))
	if desc_text.is_empty():
		var parts: Array[String] = []
		var bonuses: Dictionary = item.get("bonuses", {})
		for k in bonuses: parts.append(AccessoryPresentation.format_stat(k, bonuses[k]))
		desc_text = ", ".join(parts)

	var desc_lbl := Label.new()
	desc_lbl.text = desc_text
	desc_lbl.add_theme_font_size_override("font_size", 8)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	# Fila 3: Menú de Contexto
	var actions_row := HBoxContainer.new()
	actions_row.add_theme_constant_override("separation", 6)
	vbox.add_child(actions_row)

	# Opción Usar en Jugador si es consumible
	if item.get("is_consumable", false):
		var players := get_tree().get_nodes_in_group("players")
		for p in players:
			var btn := Button.new()
			btn.text = "Usar en J%d" % (p.player_index + 1)
			btn.add_theme_font_size_override("font_size", 8)
			btn.pressed.connect(func():
				player.use_item_from_inventory(slot_group, index, p)
				_selected_slot.clear()
				_clear_info_panel()
				_refresh_sheets()
			)
			actions_row.add_child(btn)

	# Mover a casilla inactiva o activa
	if slot_group == "active":
		var btn_store := Button.new()
		btn_store.text = "Guardar en casilla inactiva"
		btn_store.add_theme_font_size_override("font_size", 8)
		btn_store.pressed.connect(func():
			_move_to_first_free(player, "active", index, "storage")
		)
		actions_row.add_child(btn_store)
	elif slot_group == "storage":
		var btn_act := Button.new()
		btn_act.text = "Mover a casilla activa"
		btn_act.add_theme_font_size_override("font_size", 8)
		btn_act.pressed.connect(func():
			_move_to_first_free(player, "storage", index, "active")
		)
		actions_row.add_child(btn_act)

	# Botón Soltar
	var btn_drop := Button.new()
	btn_drop.text = "Soltar al suelo"
	btn_drop.add_theme_font_size_override("font_size", 8)
	btn_drop.pressed.connect(_drop_selected)
	actions_row.add_child(btn_drop)

	# Botón Cerrar selección
	var btn_close := Button.new()
	btn_close.text = "✕"
	btn_close.add_theme_font_size_override("font_size", 8)
	btn_close.pressed.connect(func():
		_selected_slot.clear()
		_clear_info_panel()
		_refresh_sheets()
	)
	actions_row.add_child(btn_close)

func _move_to_first_free(player: Node, from_group: String, from_index: int, to_group: String) -> void:
	var target_inv: Array = player._get_inventory_group(to_group)
	for i in range(target_inv.size()):
		if target_inv[i].is_empty():
			player.swap_inventory_slots(from_group, from_index, to_group, i)
			_selected_slot.clear()
			_clear_info_panel()
			_refresh_sheets()
			return
	_selected_slot.clear()
	_clear_info_panel()
	_refresh_sheets()
