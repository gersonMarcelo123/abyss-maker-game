## Persistent game state across scenes. Accessories are stored per player and type.
extends Node

# ----- Accessory slots -----
const ACCESSORY_SLOTS := ["Runa", "Libreta", "Pulsera", "Lente", "Anillo"]
var equipped_accessories: Dictionary = {}

# ----- Chest for crafted artifacts -----
var artifact_chest: Array[Dictionary] = []

# ----- Currencies -----
var gold: int = 0
var crystals: int = 0  # New currency, behaves like gold

# ----- Collectible scrap (chatarra) -----
var scrap: Dictionary = {}

var level: int = 1

# ----- Baúl de Armamento (persistente entre escenas) -----
var chest_weapons: Array[Dictionary] = []
var chest_tools: Array[Dictionary] = []
var chest_items: Array[Dictionary] = []

signal chest_weapons_changed
signal chest_tools_changed
signal chest_items_changed
signal item_picked_up(item: Dictionary)

# Compatibilidad con código previo
var weapon_chest: Array[Dictionary]:
	get: return chest_weapons
	set(v):
		chest_weapons = v
		chest_weapons_changed.emit()
signal weapon_chest_changed

# Inventarios y equipo conservados al cambiar de escena.
var player_loadouts: Dictionary = {}
signal player_loadout_changed(player_index: int)

# ----- Signals -----
signal gold_changed(total: int)
signal crystals_changed(total: int)
signal scrap_changed

func _ready() -> void:
	_init_default_chests()
	_setup_pickup_feed_ui()

var _feed_panel: PanelContainer = null
var _feed_title: Label = null
var _feed_name: Label = null
var _feed_info: Label = null
var _feed_timer: float = 0.0
var _feed_tween: Tween = null

func _setup_pickup_feed_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 25
	add_child(canvas)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)

	_feed_panel = PanelContainer.new()
	_feed_panel.anchor_left = 1.0
	_feed_panel.anchor_right = 1.0
	_feed_panel.anchor_top = 0.42
	_feed_panel.anchor_bottom = 0.42
	_feed_panel.offset_left = -175
	_feed_panel.offset_right = -10
	_feed_panel.offset_top = -25
	_feed_panel.offset_bottom = 25
	_feed_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.92)
	style.border_color = Color(0.35, 0.6, 0.85, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_feed_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_feed_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed_panel.add_child(vbox)

	_feed_title = Label.new()
	_feed_title.text = "¡OBJETO OBTENIDO!"
	_feed_title.add_theme_font_size_override("font_size", 7)
	_feed_title.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
	vbox.add_child(_feed_title)

	_feed_name = Label.new()
	_feed_name.add_theme_font_size_override("font_size", 10)
	_feed_name.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(_feed_name)

	_feed_info = Label.new()
	_feed_info.add_theme_font_size_override("font_size", 7)
	_feed_info.add_theme_color_override("font_color", Color(0.85, 0.85, 0.6))
	vbox.add_child(_feed_info)

	item_picked_up.connect(_on_item_picked_up)

func _process(delta: float) -> void:
	if _feed_timer > 0.0:
		_feed_timer -= delta
		if _feed_timer <= 0.0:
			if _feed_tween: _feed_tween.kill()
			_feed_tween = create_tween()
			_feed_tween.tween_property(_feed_panel, "modulate:a", 0.0, 0.4)
			_feed_tween.tween_callback(func(): _feed_panel.visible = false)

func _on_item_picked_up(item: Dictionary) -> void:
	if not _feed_panel: return
	if _feed_tween: _feed_tween.kill()
	_feed_panel.modulate.a = 1.0
	_feed_panel.visible = true
	_feed_timer = 2.8

	var tier_val: int = int(item.get("tier", 1))
	var color_val: Color = AccessoryPresentation.tier_color(item)
	var name_str: String = str(item.get("name", "Objeto"))
	var kind_str: String = str(item.get("kind", "item")).capitalize()

	_feed_name.text = name_str
	_feed_name.add_theme_color_override("font_color", color_val)
	_feed_info.text = "[Tier %d] · %s" % [tier_val, kind_str]

func _init_default_chests() -> void:
	if chest_weapons.is_empty():
		chest_weapons = [
			{
				"id": "daga", "name": "Daga", "short_name": "Daga", "kind": "weapon",
				"weapon_type": "melee", "level": 1, "tier": 1, "damage": 6.5,
				"damage_min": 6.0, "damage_max": 7.0, "bonuses": {"agility": 10},
				"description": "Daño: 6-7 | Agilidad +10 | Tipo: Melee"
			},
			{
				"id": "baston_magico", "name": "Bastón Mágico", "short_name": "Bastón", "kind": "weapon",
				"weapon_type": "ranged", "level": 1, "tier": 1, "damage": 10.5,
				"damage_min": 10.0, "damage_max": 11.0, "range": 500.0,
				"bonuses": {"intelligence": 10},
				"description": "Daño: 10-11 | Inteligencia +10 | Rango: 500"
			},
			{
				"id": "espada_larga", "name": "Espada Larga", "short_name": "Espada", "kind": "weapon",
				"weapon_type": "melee", "level": 1, "tier": 1, "damage": 8.5,
				"damage_min": 8.0, "damage_max": 9.0, "bonuses": {"strength": 10},
				"description": "Daño: 8-9 | Fuerza +10 | Tipo: Melee"
			},
			{
				"id": "arco", "name": "Arco", "short_name": "Arco", "kind": "weapon",
				"weapon_type": "ranged", "level": 1, "tier": 1, "damage": 4.5,
				"damage_min": 4.0, "damage_max": 5.0, "range": 800.0,
				"bonuses": {"attack_speed": 0.5},
				"description": "Daño: 4-5 | Vel. Ataque +5 | Rango: 800"
			}
		]
	if chest_tools.is_empty():
		chest_tools = [
			{
				"id": "reloj_del_espacio", "name": "Reloj del Espacio", "short_name": "Reloj",
				"kind": "tool", "tier": 1, "bonuses": {}, "tool_effect": "teleport",
				"max_distance": 600.0,
				"description": "Teletransporta hacia el cursor/apuntado hasta 600px. Se detiene ante obstáculos."
			}
		]
	if chest_items.is_empty():
		chest_items = [
			{
				"id": "alfiler_envenenado", "name": "Alfiler Envenenado", "short_name": "Alfiler",
				"kind": "item", "tier": 1, "is_passive": true,
				"bonuses": {"physical_damage": 5.0, "agility": 5},
				"description": "+5 Daño, +5 Agilidad (Pasivo)"
			},
			{
				"id": "resorte_ballesta", "name": "Resorte de Ballesta", "short_name": "Resorte",
				"kind": "item", "tier": 1, "is_passive": true,
				"bonuses": {"ranged_attack_range": 20.0},
				"description": "+20 Rango de ataque a distancia (Pasivo)"
			},
			{
				"id": "botas_movimiento", "name": "Botas de Movimiento", "short_name": "Botas",
				"kind": "item", "tier": 1, "is_passive": true,
				"bonuses": {"move_speed_percent": 20.0},
				"description": "+20 Velocidad de movimiento (Pasivo)"
			},
			{
				"id": "brazalete_suerte", "name": "Brazalete de la Suerte", "short_name": "Brazalete",
				"kind": "item", "tier": 2, "is_passive": true,
				"bonuses": {"agility": 1, "resistance": 1, "intelligence": 1, "strength": 1},
				"description": "+1 Agilidad, +1 Resistencia, +1 Inteligencia, +1 Fuerza (Pasivo)"
			},
			{
				"id": "telescopio", "name": "Telescopio", "short_name": "Telescop",
				"kind": "item", "tier": 1, "is_passive": true,
				"bonuses": {"cast_range": 20.0},
				"description": "+20 Rango de magia (Pasivo)"
			},
			{
				"id": "perla_felina", "name": "Perla Felina", "short_name": "Perla",
				"kind": "item", "tier": 3, "is_passive": true,
				"bonuses": {"agility": 10},
				"description": "+10 Agilidad (Pasivo)"
			},
			{
				"id": "corazon_hierro", "name": "Corazón de Hierro", "short_name": "Corazón",
				"kind": "item", "tier": 2, "is_passive": true,
				"bonuses": {"resistance": 5, "strength": 5},
				"description": "+5 Resistencia, +5 Fuerza (Pasivo)"
			},
			{
				"id": "placas_pesadas", "name": "Placas Pesadas", "short_name": "Placas",
				"kind": "item", "tier": 2, "is_passive": true,
				"bonuses": {"armor": 10.0},
				"description": "+10 Armadura (Pasivo)"
			},
			{
				"id": "pocion_curacion_1", "name": "Poción de Curación I", "short_name": "Poción",
				"kind": "item", "tier": 1, "is_consumable": true,
				"max_uses": 1, "current_uses": 1, "heal_amount": 50.0, "bonuses": {},
				"description": "Cura 50 HP al usar | Usable en Jugador | Usos: 1"
			}
		]

# ----- Artifact chest management -----
func add_artifact(artifact: Dictionary) -> void:
	artifact_chest.append(artifact.duplicate(true))

func get_chest_artifacts() -> Array[Dictionary]:
	return artifact_chest.duplicate(true)

func clear_artifact_chest() -> void:
	artifact_chest.clear()

# ----- Gold handling -----
func add_gold(amount: int) -> void:
	gold = max(gold + amount, 0)
	gold_changed.emit(gold)

# ----- Crystals handling (currency) -----
func add_crystals(amount: int) -> void:
	crystals = max(crystals + amount, 0)
	crystals_changed.emit(crystals)

# ----- Scrap handling (collectible) -----
func add_scrap(item_name: String, amount: int = 1) -> void:
	scrap[item_name] = int(scrap.get(item_name, 0)) + max(amount, 0)
	scrap_changed.emit()

# ----- Weapon chest handling -----
func add_weapon_to_chest(weapon: Dictionary) -> void:
	weapon_chest.append(weapon.duplicate(true))
	weapon_chest_changed.emit()

func remove_weapon_from_chest(index: int) -> Dictionary:
	if index < 0 or index >= weapon_chest.size():
		return {}
	var removed: Dictionary = weapon_chest[index]
	weapon_chest.remove_at(index)
	weapon_chest_changed.emit()
	return removed

func get_weapon_chest() -> Array[Dictionary]:
	return chest_weapons.duplicate(true)

func add_item_to_weapon_chest(item: Dictionary) -> void:
	chest_weapons.append(item.duplicate(true))
	chest_weapons_changed.emit()

func get_tools_chest() -> Array[Dictionary]:
	return chest_tools.duplicate(true)

func get_items_chest() -> Array[Dictionary]:
	return chest_items.duplicate(true)

func get_player_loadout(player_index: int) -> Dictionary:
	if not player_loadouts.has(player_index):
		player_loadouts[player_index] = {"active": [{}, {}, {}, {}, {}, {}], "storage": [{}, {}, {}], "weapon": {}, "tool": {}}
	return player_loadouts[player_index].duplicate(true)

func set_player_loadout(player_index: int, loadout: Dictionary) -> void:
	player_loadouts[player_index] = loadout.duplicate(true)
	player_loadout_changed.emit(player_index)

# ----- Accessory management -----
func get_accessories(player_index: int) -> Dictionary:
	if not equipped_accessories.has(player_index):
		var slots: Dictionary = {}
		equipped_accessories[player_index] = slots
	for slot_name in ACCESSORY_SLOTS:
		if not equipped_accessories[player_index].has(slot_name):
			equipped_accessories[player_index][slot_name] = {}
	return equipped_accessories[player_index].duplicate(true)

func set_accessory(player_index: int, slot_name: String, accessory: Dictionary) -> void:
	var slots: Dictionary = get_accessories(player_index)
	slots[slot_name] = accessory.duplicate(true)
	equipped_accessories[player_index] = slots

func is_equipped_by_other_player(accessory_id: String, owner_index: int) -> bool:
	for player_key in equipped_accessories:
		if int(player_key) == owner_index:
			continue
		for slot_name in ACCESSORY_SLOTS:
			var accessory: Dictionary = equipped_accessories[player_key].get(slot_name, {})
			if accessory.get("id", "") == accessory_id:
				return true
	return false
