## Estado persistente de la partida entre escenas. Los accesorios no forman
## parte del inventario: se guardan por jugador y por tipo de accesorio.
extends Node

const ACCESSORY_SLOTS := ["Runa", "Manual", "Pulsera", "Lente", "Anillo"]
var equipped_accessories: Dictionary = {}

func get_accessories(player_index: int) -> Dictionary:
	if not equipped_accessories.has(player_index):
		var slots: Dictionary = {}
		for slot_name in ACCESSORY_SLOTS:
			slots[slot_name] = {}
		equipped_accessories[player_index] = slots
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
