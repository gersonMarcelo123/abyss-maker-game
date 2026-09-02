## Baúl de accesorios: pantalla completa para equipar cinco tipos de artefacto.
class_name ArtifactChest
extends Area2D

const CATEGORIES: Array[String] = ["Runa", "Libreta", "Pulsera", "Lente", "Anillo"]
const UI_DESIGN_SIZE := Vector2(1280, 720)
const UI_MAX_SCALE := 0.78

var _player_nearby: Player = null
var _menu_root: CanvasLayer = null
var _focused_accessory: Dictionary = {}
var _focused_player_index := 0
var _l2_held := false
var _tooltip: AccessoryTooltip = null
var _category_by_player: Dictionary = {}

func _ready() -> void:
	add_to_group("artifact_chests")
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_visual()

func is_menu_open() -> bool:
	return _menu_root != null

func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby == null: return
	var pressed_e: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E
	var pressed_joy: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_LEFT_SHOULDER
	if pressed_e or pressed_joy:
		if _menu_root == null: _open_chest_menu()
		else: _close_chest_menu()
		get_viewport().set_input_as_handled()
	if _menu_root != null and event is InputEventJoypadMotion and event.axis == JOY_AXIS_TRIGGER_LEFT:
		if event.axis_value < 0.2: _l2_held = false
		elif event.axis_value > 0.5 and not _l2_held and not _focused_accessory.is_empty():
			_l2_held = true
			_toggle_accessory(_focused_player_index, _focused_accessory)

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
	for menu in get_tree().get_nodes_in_group("inventory_menus"):
		if menu.has_method("is_open") and menu.is_open(): return
	for chest in get_tree().get_nodes_in_group("weapon_chests"):
		if chest.has_method("is_menu_open") and chest.is_menu_open(): return
	_menu_root = CanvasLayer.new()
	_menu_root.layer = 15
	_menu_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_menu_root)
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.015, 0.02, 0.04, 0.91)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_root.add_child(dim)
	_rebuild_chest_menu()

func _rebuild_chest_menu() -> void:
	for child in _menu_root.get_children():
		if child.name != "Dim": child.queue_free()
	var viewport_size := get_viewport().get_visible_rect().size
	var fit_scale: float = minf(minf(viewport_size.x / UI_DESIGN_SIZE.x, viewport_size.y / UI_DESIGN_SIZE.y), UI_MAX_SCALE)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.size = UI_DESIGN_SIZE
	root.scale = Vector2.ONE * fit_scale
	root.position = (viewport_size - UI_DESIGN_SIZE * fit_scale) * 0.5
	_menu_root.add_child(root)
	var title := _text("BAÚL DE ARTEFACTOS", 54, Color.WHITE)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 18; title.offset_bottom = 82
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var subtitle := _text("clic o L2 para equipar, reemplazar o desequipar", 22, Color(0.72, 0.8, 0.9))
	subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	subtitle.offset_top = 84; subtitle.offset_bottom = 112
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(subtitle)
	var centered := CenterContainer.new()
	centered.set_anchors_preset(Control.PRESET_FULL_RECT)
	centered.offset_top = 120; centered.offset_bottom = -26
	root.add_child(centered)
	var players_row := HBoxContainer.new()
	players_row.add_theme_constant_override("separation", 14)
	centered.add_child(players_row)
	for player_index in range(4): players_row.add_child(_build_player_panel(player_index))
	var close := Button.new()
	close.text = "Cerrar [E]"
	close.add_theme_font_size_override("font_size", 16)
	close.position = Vector2(16, 16)
	close.pressed.connect(_close_chest_menu)
	root.add_child(close)

func _build_player_panel(player_index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(276, 548)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.1, 0.16, 0.98)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(0.35, 0.72, 1.0) if player_index == _player_nearby.player_index else Color(0.24, 0.32, 0.45)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 12; panel_style.content_margin_right = 12
	panel_style.content_margin_top = 10; panel_style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", panel_style)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	panel.add_child(content)
	var header := _text("Jugador %d" % (player_index + 1), 26, Color.WHITE)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(header)
	content.add_child(_build_attribute_panel(player_index))
	var equipped_label := _text("artefactos equipados", 19, Color(0.78, 0.88, 1.0))
	equipped_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(equipped_label)
	content.add_child(_build_equipped_grid(player_index))
	var inventory_label := _text("inventario de artefactos", 19, Color(0.95, 0.84, 0.5))
	inventory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(inventory_label)
	content.add_child(_build_category_tabs(player_index))
	content.add_child(_build_accessory_scroll(player_index))
	return panel

func _build_attribute_panel(player_index: int) -> PanelContainer:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(250, 102)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.18, 0.26, 1.0)
	style.set_corner_radius_all(5)
	style.set_border_width_all(1)
	style.border_color = Color(0.32, 0.5, 0.68)
	box.add_theme_stylebox_override("panel", style)
	var stats_text := "Sin jugador activo"
	for player in get_tree().get_nodes_in_group("players"):
		if player.player_index == player_index:
			var stats: CharacterStats = player.stats
			stats_text = "Vida: %d · Maná: %d\nDaño físico: %.0f · Daño mágico: %.0f\nArmadura: %.0f · Velocidad de movimiento: %.0f" % [stats.current_health, stats.current_mana, stats.physical_damage, stats.magic_damage, stats.armor, stats.movement_speed]
	var rows := VBoxContainer.new()
	box.add_child(rows)
	var title := _text("Panel de atributos", 21, Color(0.9, 0.95, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title)
	var label := _text(stats_text, 13, Color(0.86, 0.92, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(label)
	return box

func _build_equipped_grid(player_index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	var equipped: Dictionary = GameState.get_accessories(player_index)
	for slot_name in Player.ACCESSORY_SLOTS:
		var accessory: Dictionary = equipped.get(slot_name, {})
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(42, 42)
		slot.text = AccessoryPresentation.icon_for(accessory) if not accessory.is_empty() else "▫"
		slot.add_theme_font_size_override("font_size", 22)
		slot.add_theme_color_override("font_color", AccessoryPresentation.tier_color(accessory) if not accessory.is_empty() else Color(0.55,0.55,0.62))
		slot.add_theme_stylebox_override("normal", AccessoryPresentation.tier_slot_style(accessory))
		slot.add_theme_stylebox_override("hover", AccessoryPresentation.tier_slot_style(accessory, true))
		if not accessory.is_empty():
			slot.mouse_entered.connect(func(): _show_tooltip(accessory, slot.global_position))
			slot.mouse_exited.connect(_clear_tooltip)
		row.add_child(slot)
	return row

func _build_category_tabs(player_index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	var selected: String = str(_category_by_player.get(player_index, CATEGORIES[0]))
	for category in CATEGORIES:
		var tab := Button.new()
		tab.text = category
		tab.custom_minimum_size = Vector2(46, 29)
		tab.add_theme_font_size_override("font_size", 11)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.22, 0.47, 0.72) if category == selected else Color(0.12, 0.16, 0.23)
		style.set_corner_radius_all(8)
		tab.add_theme_stylebox_override("normal", style)
		tab.pressed.connect(func(): _category_by_player[player_index] = category; _rebuild_chest_menu())
		row.add_child(tab)
	return row

func _build_accessory_scroll(player_index: int) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(250, 178)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 4)
	var selected: String = str(_category_by_player.get(player_index, CATEGORIES[0]))
	var stored_artifacts: Array[Dictionary] = GameState.get_chest_artifacts()
	for accessory: Dictionary in stored_artifacts:
		if str(accessory.get("type", "")) != selected: continue
		grid.add_child(_build_accessory_slot(player_index, accessory))
	scroll.add_child(grid)
	return scroll

func _build_accessory_slot(player_index: int, accessory: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(45, 30)
	var in_use: bool = GameState.is_equipped_by_other_player(str(accessory.get("id", "")), player_index)
	button.disabled = in_use
	button.text = AccessoryPresentation.icon_for(accessory)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", AccessoryPresentation.tier_color(accessory))
	button.add_theme_color_override("font_disabled_color", AccessoryPresentation.tier_color(accessory).darkened(0.55))
	button.add_theme_stylebox_override("normal", AccessoryPresentation.tier_slot_style(accessory))
	button.add_theme_stylebox_override("hover", AccessoryPresentation.tier_slot_style(accessory, true))
	button.add_theme_stylebox_override("pressed", AccessoryPresentation.tier_slot_style(accessory, true))
	button.add_theme_stylebox_override("disabled", AccessoryPresentation.tier_slot_style(accessory, false, true))
	button.pressed.connect(func(): _toggle_accessory(player_index, accessory))
	button.focus_entered.connect(func(): _focused_player_index = player_index; _focused_accessory = accessory)
	button.mouse_entered.connect(func(): _show_tooltip(accessory, button.global_position))
	button.mouse_exited.connect(_clear_tooltip)
	return button

func _toggle_accessory(player_index: int, accessory: Dictionary) -> void:
	var slot_name: String = str(accessory.get("type", ""))
	var equipped: Dictionary = GameState.get_accessories(player_index)
	var current: Dictionary = equipped.get(slot_name, {})
	GameState.set_accessory(player_index, slot_name, {} if current.get("id", "") == accessory.get("id", "") else accessory)
	if _player_nearby != null and _player_nearby.player_index == player_index:
		_player_nearby.accessory_inventory = GameState.get_accessories(player_index)
		_player_nearby.refresh_accessory_bonuses()
	_rebuild_chest_menu()

func _prepared_accessory(source: Dictionary, index: int) -> Dictionary:
	var accessory: Dictionary = source.duplicate(true)
	var tier: int = index % 5 + 1
	accessory["tier"] = tier
	var bonuses: Dictionary = accessory.get("bonuses", {}).duplicate(true)
	var keys: Array = bonuses.keys()
	if not keys.is_empty(): bonuses[str(keys[0])] = 3.0 + (tier - 1) * 2.0
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
