## Estado persistente de la partida entre escenas. Los accesorios no forman
## parte del inventario: se guardan por jugador y por tipo de accesorio.
extends Node

const ACCESSORY_SLOTS := ["Runa", "Libreta", "Pulsera", "Lente", "Anillo"]
var equipped_accessories: Dictionary = {}
var artifact_chest: Array[Dictionary] = []
var gold: int = 0
var materials: Dictionary = {}
var level: int = 1

signal gold_changed(total: int)
signal materials_changed

func add_artifact(artifact: Dictionary) -> void:
	artifact_chest.append(artifact.duplicate(true))

func get_chest_artifacts() -> Array[Dictionary]:
	return artifact_chest.duplicate(true)

func clear_artifact_chest() -> void:
	artifact_chest.clear()

func add_gold(amount: int) -> void:
	gold = max(gold + amount, 0)
	gold_changed.emit(gold)

func add_material(material_name: String, amount: int = 1) -> void:
	materials[material_name] = int(materials.get(material_name, 0)) + max(amount, 0)
	materials_changed.emit()

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
