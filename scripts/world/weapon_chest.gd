## Baúl persistente para almacenar armas y objetos entre los cuatro jugadores.
class_name WeaponChest
extends Area2D

const CHEST_SLOTS := 30
var _nearby_player: Player = null
var _canvas: CanvasLayer = null
var _selected: Dictionary = {}

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
	if body is Player: _nearby_player = body

func _on_body_exited(body: Node2D) -> void:
	if body == _nearby_player:
		_nearby_player = null
		_close()

func is_menu_open() -> bool:
	return _canvas != null

func _unhandled_input(event: InputEvent) -> void:
	if _nearby_player == null: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if _canvas == null: _open()
		else: _close()
		get_viewport().set_input_as_handled()

func _build_world_visual() -> void:
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([Vector2(-16,-10),Vector2(16,-10),Vector2(16,10),Vector2(-16,10)])
	visual.color = Color(0.38, 0.22, 0.1)
	add_child(visual)
	var label := Label.new()
	label.text = "Baúl armas [E]"
	label.position = Vector2(-46, -30)
	label.add_theme_font_size_override("font_size", 10)
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
	_rebuild()

func _close() -> void:
	if _canvas:
		_canvas.queue_free()
		_canvas = null
	_selected.clear()

func _rebuild() -> void:
	for child in _canvas.get_children(): child.queue_free()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.02,0.025,0.04,0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var title := Label.new()
	title.text = "BAÚL DE ARMAS"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 12; title.offset_bottom = 40
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	root.add_child(title)
	var hint := Label.new()
	hint.text = "clic: seleccionar · segundo clic: mover · E: cerrar"
	hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint.offset_top = 42; hint.offset_bottom = 60
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	root.add_child(hint)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER)
	row.position = Vector2(-290, -125)
	row.add_theme_constant_override("separation", 10)
	root.add_child(row)
	for player_index in range(4): row.add_child(_build_player_bag(player_index))
	row.add_child(_build_chest_bag())

func _build_player_bag(player_index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(112, 250)
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(_label("Jugador %d" % (player_index + 1), 13))
	box.add_child(_label("Activos", 9))
	box.add_child(_player_grid(player_index, "active", 6))
	box.add_child(_label("Guardado", 9))
	box.add_child(_player_grid(player_index, "storage", 3))
	box.add_child(_label("Arma", 9))
	box.add_child(_player_grid(player_index, "weapon", 1))
	box.add_child(_label("Herramienta", 9))
	box.add_child(_player_grid(player_index, "tool", 1))
	return panel

func _player_grid(player_index: int, group: String, count: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	var loadout: Dictionary = _read_loadout(player_index)
	for index in range(count):
		var item: Dictionary = _loadout_item(loadout, group, index)
		grid.add_child(_slot(item, func(): _on_player_slot(player_index, group, index)))
	return grid

func _build_chest_bag() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(170, 250)
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(_label("Almacenamiento", 13))
	var grid := GridContainer.new()
	grid.columns = 5
	var stored: Array[Dictionary] = GameState.get_weapon_chest()
	for index in range(CHEST_SLOTS):
		var item: Dictionary = stored[index] if index < stored.size() else {}
		grid.add_child(_slot(item, func(): _on_chest_slot(index)))
	box.add_child(grid)
	return panel

func _slot(item: Dictionary, action: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(29, 29)
	button.text = str(item.get("short_name", "·"))
	button.tooltip_text = str(item.get("name", "Vacío"))
	button.add_theme_font_size_override("font_size", 8)
	button.pressed.connect(action)
	return button

func _label(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _read_loadout(player_index: int) -> Dictionary:
	for player in get_tree().get_nodes_in_group("players"):
		if player.player_index == player_index:
			return {"active": player.active_inventory.duplicate(true), "storage": player.storage_inventory.duplicate(true), "weapon": player.equipped_weapon.duplicate(true), "tool": player.equipped_tool.duplicate(true)}
	return GameState.get_player_loadout(player_index)

func _loadout_item(loadout: Dictionary, group: String, index: int) -> Dictionary:
	if group == "weapon" or group == "tool": return loadout.get(group, {})
	var array: Array = loadout.get(group, [])
	return array[index] if index < array.size() else {}

func _on_player_slot(player_index: int, group: String, index: int) -> void:
	var loadout: Dictionary = _read_loadout(player_index)
	var item: Dictionary = _loadout_item(loadout, group, index)
	_handle_selection({"place":"player", "player":player_index, "group":group, "index":index, "item":item})

func _on_chest_slot(index: int) -> void:
	var stored: Array[Dictionary] = GameState.get_weapon_chest()
	var item: Dictionary = stored[index] if index < stored.size() else {}
	_handle_selection({"place":"chest", "index":index, "item":item})

func _handle_selection(slot_data: Dictionary) -> void:
	if _selected.is_empty():
		if not slot_data["item"].is_empty(): _selected = slot_data
		return
	if _selected["place"] == slot_data["place"] and _selected.get("player", -1) == slot_data.get("player", -1) and _selected["index"] == slot_data["index"]:
		_selected.clear()
		return
	_move_between(_selected, slot_data)
	_selected.clear()
	_rebuild()

func _move_between(source: Dictionary, target: Dictionary) -> void:
	var source_item: Dictionary = source["item"]
	var target_item: Dictionary = target["item"]
	if not _can_place(source_item, target): return
	if not _can_place(target_item, source): return
	_write_slot(source, target_item)
	_write_slot(target, source_item)

func _can_place(item: Dictionary, destination: Dictionary) -> bool:
	if item.is_empty(): return true
	if destination["place"] == "chest": return true
	if destination["group"] == "tool": return item.get("kind", "") == "herramienta"
	return true

func _write_slot(slot_data: Dictionary, item: Dictionary) -> void:
	if slot_data["place"] == "chest":
		var data: Array[Dictionary] = GameState.get_weapon_chest()
		while data.size() <= slot_data["index"]: data.append({})
		data[slot_data["index"]] = item.duplicate(true)
		while not data.is_empty() and data.back().is_empty(): data.pop_back()
		GameState.weapon_chest = data
		GameState.weapon_chest_changed.emit()
		return
	var player_index: int = int(slot_data["player"])
	var loadout: Dictionary = _read_loadout(player_index)
	if slot_data["group"] == "weapon" or slot_data["group"] == "tool": loadout[slot_data["group"]] = item.duplicate(true)
	else:
		var array: Array = loadout[slot_data["group"]]
		array[int(slot_data["index"])] = item.duplicate(true)
		loadout[slot_data["group"]] = array
	GameState.set_player_loadout(player_index, loadout)
	for player in get_tree().get_nodes_in_group("players"):
		if player.player_index == player_index:
			player.active_inventory = loadout["active"].duplicate(true)
			player.storage_inventory = loadout["storage"].duplicate(true)
			player.equipped_weapon = loadout["weapon"].duplicate(true)
			player.equipped_tool = loadout["tool"].duplicate(true)
			player._apply_weapon_type()
			player._refresh_active_item_bonuses()
