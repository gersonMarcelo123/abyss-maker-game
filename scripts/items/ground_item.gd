## Objeto temporal visible en el suelo.
## loot_kind: "item" (va al inventario), "material" (chatarra), "weapon" (va al slot de arma o inventario).
class_name GroundItem
extends Node2D

@export var item_id: String = "artifact_placeholder"
@export var display_name: String = "Artefacto"
@export var short_name: String = "Art"
@export var color: Color = Color(0.95, 0.8, 0.25)
@export var pickup_range: float = 26.0
@export var bonuses: Dictionary = {}
@export var loot_kind := "item"
@export var material_name := ""
# Weapon-specific fields
@export var weapon_type: String = ""   # "melee" o "ranged"
@export var weapon_damage: float = 0.0
@export var weapon_agility_bonus: int = 0
@export var weapon_passive: String = ""        # "lifesteal" o "range_bonus"
@export var weapon_passive_value: float = 0.0

func _ready() -> void:
	add_to_group("ground_items")
	var visual: Polygon2D = $Visual
	visual.polygon = PackedVector2Array([
		Vector2(0, -10), Vector2(9, 0), Vector2(0, 10), Vector2(-9, 0),
	])
	visual.color = color
	var label: Label = $Label
	label.text = display_name

func get_item_data() -> Dictionary:
	return {"id": item_id, "name": display_name, "short_name": short_name, "bonuses": bonuses.duplicate(true)}

func get_weapon_data() -> Dictionary:
	return {
		"id": item_id,
		"name": display_name,
		"short_name": short_name,
		"kind": "weapon",
		"weapon_type": weapon_type,
		"damage": weapon_damage,
		"agility_bonus": weapon_agility_bonus,
		"passive": weapon_passive,
		"passive_value": weapon_passive_value,
		"bonuses": bonuses.duplicate(true),
	}

func try_pickup(player: Node) -> bool:
	if loot_kind == "material":
		GameState.add_scrap(material_name, 1)
		queue_free()
		return true
	if loot_kind == "weapon":
		if not player.has_method("equip_weapon"):
			return false
		var weapon_data: Dictionary = get_weapon_data()
		# Si el slot de arma está vacío → equipar directo
		if player.equipped_weapon.is_empty():
			player.equip_weapon(weapon_data)
		else:
			# Si no → guardar en inventario activo sin equipar
			if not player.add_inventory_item(weapon_data):
				return false
		queue_free()
		return true
	if not player.has_method("add_inventory_item"):
		return false
	if player.add_inventory_item(get_item_data()):
		print("%s recogió %s" % [player.name, display_name])
		queue_free()
		return true
	return false
