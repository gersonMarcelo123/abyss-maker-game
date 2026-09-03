## Objeto visible en el suelo (Arma, Herramienta, Item o Chatarra).
class_name GroundItem
extends Node2D

@export var item_id: String = "artifact_placeholder"
@export var display_name: String = "Artefacto"
@export var short_name: String = "Art"
@export var color: Color = Color(0.95, 0.8, 0.25)
@export var pickup_range: float = 38.0
@export var bonuses: Dictionary = {}
@export var loot_kind := "item"
@export var material_name := ""
@export var tier: int = 1
@export var description: String = ""

# Weapon-specific fields
@export var weapon_type: String = ""   # "melee" o "ranged"
@export var weapon_damage: float = 0.0
@export var weapon_level: int = 1
@export var weapon_range: float = 0.0

# Tool-specific fields
@export var tool_effect: String = ""
@export var max_distance: float = 600.0

# Completo opcional
var full_item_data: Dictionary = {}

@onready var _label: Label = $Label

func _ready() -> void:
	add_to_group("ground_items")
	var visual: Polygon2D = $Visual
	visual.polygon = PackedVector2Array([
		Vector2(0, -10), Vector2(9, 0), Vector2(0, 10), Vector2(-9, 0),
	])
	visual.color = color
	if not full_item_data.is_empty():
		display_name = str(full_item_data.get("name", display_name))
		short_name = str(full_item_data.get("short_name", short_name))
		loot_kind = str(full_item_data.get("kind", loot_kind))
		tier = int(full_item_data.get("tier", tier))
	if _label:
		_label.text = display_name
		_label.visible = false

func set_floating_name_visible(val: bool) -> void:
	if _label:
		_label.visible = val

func get_complete_data() -> Dictionary:
	if not full_item_data.is_empty():
		return full_item_data.duplicate(true)
	var data: Dictionary = {
		"id": item_id,
		"name": display_name,
		"short_name": short_name,
		"kind": loot_kind,
		"tier": tier,
		"bonuses": bonuses.duplicate(true),
		"description": description
	}
	if loot_kind == "weapon":
		data["weapon_type"] = weapon_type
		data["damage"] = weapon_damage
		data["level"] = weapon_level
		if weapon_range > 0.0:
			data["range"] = weapon_range
	elif loot_kind == "tool":
		data["tool_effect"] = tool_effect
		data["max_distance"] = max_distance
	return data

func try_pickup(player: Node) -> bool:
	if loot_kind == "material":
		GameState.add_scrap(material_name, 1)
		queue_free()
		return true

	var data: Dictionary = get_complete_data()
	var kind: String = str(data.get("kind", "item"))

	if kind == "tool" or kind == "herramienta":
		if player.has_method("equip_tool") and player.equipped_tool.is_empty():
			player.equip_tool(data)
		else:
			if not player.has_method("add_inventory_item") or not player.add_inventory_item(data):
				return false
	elif kind == "weapon" or kind == "arma":
		if player.has_method("equip_weapon") and player.equipped_weapon.is_empty():
			player.equip_weapon(data)
		else:
			if not player.has_method("add_inventory_item") or not player.add_inventory_item(data):
				return false
	else:
		if not player.has_method("add_inventory_item") or not player.add_inventory_item(data):
			return false

	GameState.item_picked_up.emit(data)
	queue_free()
	return true
