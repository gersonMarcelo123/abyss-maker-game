## Baúl de Armamento: Menú de pantalla completa 16:9 con Inventario de Jugadores (60%) y Baúl (40%).
class_name WeaponChest
extends Area2D

var _nearby_player: Player = null
var _canvas: CanvasLayer = null
var _selected: Dictionary = {}
var _player_selected_items: Dictionary = {} # player_index -> item Dictionary

func _ready() -> void:
	add_to_group("weapon_chests")
	collision_mask = 2
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(48, 42)
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_world_visual()

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_nearby_player = body

func _on_body_exited(body: Node2D) -> void:
	if body == _nearby_player:
		_nearby_player = null
		_close()

func is_menu_open() -> bool:
	return _canvas != null

func _unhandled_input(event: InputEvent) -> void:
	if _nearby_player == null and _canvas == null: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			if _canvas == null: _open()
			else: _close()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _canvas != null:
			_close()
			get_viewport().set_input_as_handled()

func _build_world_visual() -> void:
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([Vector2(-18,-12), Vector2(18,-12), Vector2(18,12), Vector2(-18,12)])
	visual.color = Color(0.32, 0.2, 0.12)
	add_child(visual)

	var trim := Polygon2D.new()
	trim.polygon = PackedVector2Array([Vector2(-18,-3), Vector2(18,-3), Vector2(18,0), Vector2(-18,0)])
	trim.color = Color(0.85, 0.75, 0.3)
	add_child(trim)

	var label := Label.new()
	label.text = "Baúl de Armamento [E]"
	label.position = Vector2(-60, -32)
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	add_child(label)

func _open() -> void:
	for menu in get_tree().get_nodes_in_group("inventory_menus"):
		if menu.has_method("is_open") and menu.is_open(): return
	for chest in get_tree().get_nodes_in_group("artifact_chests"):
		if chest.has_method("is_menu_open") and chest.is_menu_open(): return

	_canvas = CanvasLayer.new()
	_canvas.layer = 16
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)
	get_tree().paused = true
	_rebuild()

func _close() -> void:
	if _canvas:
		_canvas.queue_free()
		_canvas = null
	_selected.clear()
	_player_selected_items.clear()
	get_tree().paused = false

func _rebuild() -> void:
	if not _canvas: return
	for child in _canvas.get_children():
		child.queue_free()

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.04, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	# Marco base 16:9 fijo en 1280x720, escalado para no exceder canvas en ninguna resolución
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var scale_factor: float = minf(vp_size.x / 1280.0, vp_size.y / 720.0)

	var frame := Control.new()
	frame.custom_minimum_size = Vector2(1280, 720)
	frame.size = Vector2(1280, 720)
	frame.scale = Vector2(scale_factor, scale_factor)
	frame.position = (vp_size - Vector2(1280, 720) * scale_factor) * 0.5
	root.add_child(frame)

	# División en 2 columnas: Izquierda (60% = 768px), Derecha (40% = 512px)
	var main_columns := HBoxContainer.new()
	main_columns.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_columns.offset_left = 18
	main_columns.offset_right = -18
	main_columns.offset_top = 12
	main_columns.offset_bottom = -12
	main_columns.add_theme_constant_override("separation", 16)
	frame.add_child(main_columns)

	# --- Columna Izquierda (60%): Inventario de Jugadores ---
	var left_col := VBoxContainer.new()
	left_col.custom_minimum_size = Vector2(736, 696)
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_stretch_ratio = 0.60
	left_col.add_theme_constant_override("separation", 6)
	main_columns.add_child(left_col)

	var left_title := Label.new()
	left_title.text = "Inventario de Jugadores"
	left_title.add_theme_font_size_override("font_size", 36)
	left_title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	left_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left_col.add_child(left_title)

	var players_vbox := VBoxContainer.new()
	players_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	players_vbox.add_theme_constant_override("separation", 6)
	left_col.add_child(players_vbox)

	for p_idx in range(4):
		players_vbox.add_child(_build_player_row(p_idx))

	# --- Columna Derecha (40%): Baúl de Armamento ---
	var right_col := VBoxContainer.new()
	right_col.custom_minimum_size = Vector2(492, 696)
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_stretch_ratio = 0.40
	right_col.add_theme_constant_override("separation", 6)
	main_columns.add_child(right_col)

	var right_title_row := HBoxContainer.new()
	right_col.add_child(right_title_row)

	var right_title := Label.new()
	right_title.text = "Baúl de Armamento"
	right_title.add_theme_font_size_override("font_size", 36)
	right_title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	right_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_title_row.add_child(right_title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(_close)
	right_title_row.add_child(close_btn)

	# 3 Bloques del Baúl: Armas, Herramientas, Items
	right_col.add_child(_build_chest_section("Armas", "weapon", 3, 6, 140))
	right_col.add_child(_build_chest_section("Herramientas", "tool", 3, 6, 140))
	right_col.add_child(_build_chest_items_section(6, 6, 275))

# ---------------------------------------------------------------------------
# Constructor Fila de Jugador (Bloque Izquierdo + Bloque Derecho)
# ---------------------------------------------------------------------------
func _build_player_row(player_index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(736, 142)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)

	# --- Bloque Izquierdo: Inventario y Equipamiento ---
	var left_block := PanelContainer.new()
	left_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_block.size_flags_stretch_ratio = 1.0
	var style_left := StyleBoxFlat.new()
	style_left.bg_color = Color(0.08, 0.09, 0.13, 0.95)
	style_left.border_color = Color(0.25, 0.3, 0.4)
	style_left.set_border_width_all(1)
	style_left.set_corner_radius_all(4)
	style_left.content_margin_left = 6
	style_left.content_margin_right = 6
	style_left.content_margin_top = 4
	style_left.content_margin_bottom = 4
	left_block.add_theme_stylebox_override("panel", style_left)
	row.add_child(left_block)

	var left_content := HBoxContainer.new()
	left_content.add_theme_constant_override("separation", 8)
	left_block.add_child(left_content)

	# Etiqueta lateral vertical "Jugador X" (20px - 24px)
	var player_color: Color = Player.PLAYER_COLORS[player_index] if player_index < Player.PLAYER_COLORS.size() else Color.WHITE
	left_content.add_child(_create_vertical_label("Jugador %d" % (player_index + 1), 22, player_color, 126.0, 30.0))

	# Matriz 3x3 (9 slots inventario general: 6 activos + 3 almacenamiento)
	var matrix := GridContainer.new()
	matrix.columns = 3
	matrix.add_theme_constant_override("h_separation", 4)
	matrix.add_theme_constant_override("v_separation", 4)
	left_content.add_child(matrix)

	var loadout: Dictionary = _read_loadout(player_index)
	var active_arr: Array = loadout.get("active", [])
	var storage_arr: Array = loadout.get("storage", [])

	for idx in range(9):
		var is_active := idx < 6
		var group := "active" if is_active else "storage"
		var sub_idx := idx if is_active else (idx - 6)
		var item: Dictionary = active_arr[sub_idx] if is_active and sub_idx < active_arr.size() else (storage_arr[sub_idx] if not is_active and sub_idx < storage_arr.size() else {})
		var bg_col := Color(0.2, 0.32, 0.22) if is_active else Color(0.18, 0.2, 0.26)
		matrix.add_child(_build_slot_button(item, 36.0, bg_col, func():
			_on_player_slot_click(player_index, group, sub_idx, item)
		, _is_selected("player", player_index, group, sub_idx)))

	# Columna secundaria adjunta: 2 slots verticales (Arma arriba, Herramienta abajo)
	var special_col := VBoxContainer.new()
	special_col.add_theme_constant_override("separation", 6)
	special_col.alignment = BoxContainer.ALIGNMENT_CENTER
	left_content.add_child(special_col)

	var weapon_item: Dictionary = loadout.get("weapon", {})
	var weapon_slot := _build_slot_button(weapon_item, 40.0, Color(0.35, 0.25, 0.1), func():
		_on_player_slot_click(player_index, "weapon", 0, weapon_item)
	, _is_selected("player", player_index, "weapon", 0))
	weapon_slot.tooltip_text = "Arma"
	special_col.add_child(weapon_slot)

	var tool_item: Dictionary = loadout.get("tool", {})
	var tool_slot := _build_slot_button(tool_item, 40.0, Color(0.15, 0.28, 0.32), func():
		_on_player_slot_click(player_index, "tool", 0, tool_item)
	, _is_selected("player", player_index, "tool", 0))
	tool_slot.tooltip_text = "Herramienta"
	special_col.add_child(tool_slot)

	# --- Bloque Derecho: Panel de Información ---
	var right_block := PanelContainer.new()
	right_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_block.size_flags_stretch_ratio = 1.0
	var style_right := StyleBoxFlat.new()
	style_right.bg_color = Color(0.06, 0.07, 0.10, 0.95)
	style_right.border_color = Color(0.22, 0.26, 0.35)
	style_right.set_border_width_all(1)
	style_right.set_corner_radius_all(4)
	style_right.content_margin_left = 10
	style_right.content_margin_right = 10
	style_right.content_margin_top = 8
	style_right.content_margin_bottom = 8
	right_block.add_theme_stylebox_override("panel", style_right)
	row.add_child(right_block)

	var selected_for_player: Dictionary = _player_selected_items.get(player_index, {})
	right_block.add_child(_build_info_content(selected_for_player))

	return row

# ---------------------------------------------------------------------------
# Panel de Información de un ítem seleccionado
# ---------------------------------------------------------------------------
func _build_info_content(item: Dictionary) -> Control:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 3)

	if item.is_empty():
		var placeholder := Label.new()
		placeholder.text = "Selecciona una casilla para ver sus detalles."
		placeholder.add_theme_font_size_override("font_size", 13)
		placeholder.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
		container.add_child(placeholder)
		return container

	var name_lbl := Label.new()
	name_lbl.text = str(item.get("name", "Objeto"))
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", AccessoryPresentation.tier_color(item))
	container.add_child(name_lbl)

	var kind_str := str(item.get("kind", "item")).capitalize()
	var tier_val := int(item.get("tier", 1))
	var lvl_str := (" · Nivel %d" % int(item.get("level", 1))) if item.has("level") else ""
	var sub_lbl := Label.new()
	sub_lbl.text = "[Tier %d] · %s%s" % [tier_val, kind_str, lvl_str]
	sub_lbl.add_theme_font_size_override("font_size", 12)
	sub_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	container.add_child(sub_lbl)

	# Atributos específicos
	var stats_parts: Array[String] = []
	if item.has("damage"):
		var d_min: float = float(item.get("damage_min", item.get("damage", 0.0)))
		var d_max: float = float(item.get("damage_max", item.get("damage", 0.0)))
		stats_parts.append("Daño: %.0f-%.0f" % [d_min, d_max])
	if item.has("range"):
		stats_parts.append("Rango: %.0f" % float(item.get("range")))
	if item.has("weapon_type"):
		stats_parts.append("Tipo: %s" % str(item.get("weapon_type")).capitalize())
	var bonuses: Dictionary = item.get("bonuses", {})
	for k in bonuses:
		stats_parts.append(AccessoryPresentation.format_stat(k, bonuses[k]))

	if not stats_parts.is_empty():
		var stats_lbl := Label.new()
		stats_lbl.text = " · ".join(stats_parts)
		stats_lbl.add_theme_font_size_override("font_size", 11)
		stats_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
		stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		container.add_child(stats_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = str(item.get("description", ""))
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(desc_lbl)

	return container

# ---------------------------------------------------------------------------
# Secciones del Baúl: Armas & Herramientas
# ---------------------------------------------------------------------------
func _build_chest_section(section_name: String, section_key: String, rows: int, cols: int, height_val: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(492, height_val)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.12, 0.95)
	style.border_color = Color(0.3, 0.35, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	# Etiqueta lateral vertical (20px)
	var lbl_color := Color(1.0, 0.75, 0.3) if section_key == "weapon" else Color(0.4, 0.85, 0.95)
	hbox.add_child(_create_vertical_label(section_name, 20, lbl_color, height_val - 12.0, 26.0))

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hbox.add_child(scroll)

	var items_source: Array[Dictionary] = GameState.chest_weapons if section_key == "weapon" else GameState.chest_tools
	var total_slots: int = max(items_source.size() + 2, rows * cols)
	var total_cols: int = ceili(float(total_slots) / float(rows))
	total_cols = max(total_cols, cols)

	var grid := GridContainer.new()
	grid.columns = total_cols
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)

	for r in range(rows):
		for c in range(total_cols):
			var idx := r * total_cols + c
			var itm: Dictionary = items_source[idx] if idx < items_source.size() else {}
			var is_sel := _is_selected("chest", -1, section_key, idx)
			grid.add_child(_build_slot_button(itm, 34.0, Color(0.12, 0.14, 0.2), func():
				_on_chest_slot_click(section_key, idx, itm)
			, is_sel))

	return panel

# ---------------------------------------------------------------------------
# Sección del Baúl: Items (6 filas x 6 cols visibles con expansión dinámica)
# ---------------------------------------------------------------------------
func _build_chest_items_section(rows: int, cols: int, height_val: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(492, height_val)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.12, 0.95)
	style.border_color = Color(0.3, 0.35, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	# Etiqueta lateral vertical: "Items" (20px)
	hbox.add_child(_create_vertical_label("Items", 20, Color(0.5, 0.95, 0.55), height_val - 12.0, 26.0))

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hbox.add_child(scroll)

	var items_source: Array[Dictionary] = GameState.chest_items
	# Dinámico: si supera 6x6 (36 slots), añade columnas hacia la derecha navegables con scroll horizontal
	var total_slots: int = max(items_source.size() + 6, rows * cols)
	var total_cols: int = ceili(float(total_slots) / float(rows))
	total_cols = max(total_cols, cols)

	var grid := GridContainer.new()
	grid.columns = total_cols
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)

	for r in range(rows):
		for c in range(total_cols):
			var idx := r * total_cols + c
			var itm: Dictionary = items_source[idx] if idx < items_source.size() else {}
			var is_sel := _is_selected("chest", -1, "item", idx)
			grid.add_child(_build_slot_button(itm, 34.0, Color(0.12, 0.14, 0.2), func():
				_on_chest_slot_click("item", idx, itm)
			, is_sel))

	return panel

# ---------------------------------------------------------------------------
# Creación de Etiquetas Verticales Rotadas
# ---------------------------------------------------------------------------
func _create_vertical_label(text_val: String, font_size_val: int, color_val: Color, height_val: float, width_val: float) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(width_val, height_val)
	container.clip_contents = true

	var lbl := Label.new()
	lbl.text = text_val
	lbl.add_theme_font_size_override("font_size", font_size_val)
	lbl.add_theme_color_override("font_color", color_val)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(height_val, width_val)
	lbl.rotation = -PI / 2.0
	lbl.position = Vector2(0, height_val)
	container.add_child(lbl)
	return container

# ---------------------------------------------------------------------------
# Botón de Slot genérico con Estilo y Color de Tier
# ---------------------------------------------------------------------------
func _build_slot_button(item: Dictionary, size_val: float, empty_color: Color, action: Callable, is_selected_slot: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(size_val, size_val)
	btn.focus_mode = Control.FOCUS_NONE

	var has_item := not item.is_empty()
	var short_txt := str(item.get("short_name", "·")) if has_item else "·"
	btn.text = short_txt
	btn.tooltip_text = str(item.get("name", "Vacío"))
	btn.add_theme_font_size_override("font_size", 10)

	var style := StyleBoxFlat.new()
	if has_item:
		var tier_col: Color = AccessoryPresentation.tier_color(item)
		style.bg_color = Color(tier_col.r * 0.35, tier_col.g * 0.35, tier_col.b * 0.35, 0.95)
		style.border_color = Color(1.0, 0.95, 0.35) if is_selected_slot else tier_col
		btn.add_theme_color_override("font_color", tier_col)
	else:
		style.bg_color = empty_color
		style.border_color = Color(1.0, 0.95, 0.35) if is_selected_slot else Color(0.35, 0.4, 0.5)
		btn.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5))

	style.set_border_width_all(2 if is_selected_slot else 1)
	style.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)

	btn.pressed.connect(action)
	return btn

# ---------------------------------------------------------------------------
# Lógica de Selección y Movimiento de Ítems
# ---------------------------------------------------------------------------
func _on_player_slot_click(player_index: int, group: String, index: int, item: Dictionary) -> void:
	if not item.is_empty():
		_player_selected_items[player_index] = item.duplicate(true)

	var slot_info := {
		"place": "player",
		"player": player_index,
		"group": group,
		"index": index,
		"item": item
	}
	_handle_slot_interaction(slot_info)

func _on_chest_slot_click(section_key: String, index: int, item: Dictionary) -> void:
	var slot_info := {
		"place": "chest",
		"section": section_key,
		"index": index,
		"item": item
	}
	_handle_slot_interaction(slot_info)

func _handle_slot_interaction(target_slot: Dictionary) -> void:
	if _selected.is_empty():
		if not target_slot["item"].is_empty():
			_selected = target_slot
			_rebuild()
		return

	# Si se pulsa la misma casilla: deseleccionar
	if _is_same_slot(_selected, target_slot):
		_selected.clear()
		_rebuild()
		return

	# Intentar mover / intercambiar
	_try_swap_slots(_selected, target_slot)
	_selected.clear()
	_rebuild()

func _is_same_slot(a: Dictionary, b: Dictionary) -> bool:
	if a["place"] != b["place"]: return false
	if a["place"] == "player":
		return a["player"] == b["player"] and a["group"] == b["group"] and a["index"] == b["index"]
	else:
		return a["section"] == b["section"] and a["index"] == b["index"]

func _is_selected(place: String, player_idx: int, group_or_sec: String, idx: int) -> bool:
	if _selected.is_empty(): return false
	if _selected["place"] != place: return false
	if place == "player":
		return _selected.get("player", -1) == player_idx and _selected.get("group", "") == group_or_sec and _selected.get("index", -1) == idx
	else:
		return _selected.get("section", "") == group_or_sec and _selected.get("index", -1) == idx

func _can_place_in(item: Dictionary, destination: Dictionary) -> bool:
	if item.is_empty(): return true
	var kind := str(item.get("kind", "item"))

	if destination["place"] == "chest":
		var sec: String = destination["section"]
		if sec == "weapon": return kind == "weapon" or kind == "arma"
		if sec == "tool": return kind == "tool" or kind == "herramienta"
		if sec == "item": return kind == "item"
		return false
	else:
		var grp: String = destination["group"]
		if grp == "tool": return kind == "tool" or kind == "herramienta"
		if grp == "weapon": return kind != "tool" and kind != "herramienta"
		# Casillas de inventario general activo y storage
		return true

func _try_swap_slots(source: Dictionary, target: Dictionary) -> void:
	var src_item: Dictionary = source["item"]
	var tgt_item: Dictionary = target["item"]

	if not _can_place_in(src_item, target): return
	if not _can_place_in(tgt_item, source): return

	_write_slot(source, tgt_item)
	_write_slot(target, src_item)

func _write_slot(slot_data: Dictionary, item: Dictionary) -> void:
	if slot_data["place"] == "chest":
		var sec: String = slot_data["section"]
		var idx: int = int(slot_data["index"])
		var chest_arr: Array[Dictionary]
		if sec == "weapon": chest_arr = GameState.chest_weapons
		elif sec == "tool": chest_arr = GameState.chest_tools
		else: chest_arr = GameState.chest_items

		while chest_arr.size() <= idx:
			chest_arr.append({})
		chest_arr[idx] = item.duplicate(true)

		# Limpieza de slots vacíos al final
		while not chest_arr.is_empty() and chest_arr.back().is_empty():
			chest_arr.pop_back()

		if sec == "weapon":
			GameState.chest_weapons = chest_arr
			GameState.chest_weapons_changed.emit()
		elif sec == "tool":
			GameState.chest_tools = chest_arr
			GameState.chest_tools_changed.emit()
		else:
			GameState.chest_items = chest_arr
			GameState.chest_items_changed.emit()
	else:
		var p_idx: int = int(slot_data["player"])
		var grp: String = slot_data["group"]
		var idx: int = int(slot_data["index"])
		var loadout: Dictionary = _read_loadout(p_idx)

		if grp == "weapon" or grp == "tool":
			loadout[grp] = item.duplicate(true)
		else:
			var arr: Array = loadout[grp]
			if idx < arr.size():
				arr[idx] = item.duplicate(true)
			loadout[grp] = arr

		GameState.set_player_loadout(p_idx, loadout)
		for player in get_tree().get_nodes_in_group("players"):
			if player.player_index == p_idx:
				player.active_inventory = loadout["active"].duplicate(true)
				player.storage_inventory = loadout["storage"].duplicate(true)
				player.equipped_weapon = loadout["weapon"].duplicate(true)
				player.equipped_tool = loadout["tool"].duplicate(true)
				player._apply_weapon_type()
				player._refresh_active_item_bonuses()

func _read_loadout(player_index: int) -> Dictionary:
	for player in get_tree().get_nodes_in_group("players"):
		if player.player_index == player_index:
			return {
				"active": player.active_inventory.duplicate(true),
				"storage": player.storage_inventory.duplicate(true),
				"weapon": player.equipped_weapon.duplicate(true),
				"tool": player.equipped_tool.duplicate(true)
			}
	return GameState.get_player_loadout(player_index)
