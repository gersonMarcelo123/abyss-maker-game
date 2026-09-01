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

# ----- Signals -----
signal gold_changed(total: int)
signal crystals_changed(total: int)
signal scrap_changed

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
