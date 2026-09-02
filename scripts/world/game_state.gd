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

# ----- Weapon chest (persistent across scenes) -----
var weapon_chest: Array[Dictionary] = []
signal weapon_chest_changed

# Inventarios y equipo conservados al cambiar de escena. Así las armas no
# desaparecen aunque el Player se vuelva a instanciar en el siguiente nivel.
var player_loadouts: Dictionary = {}
signal player_loadout_changed(player_index: int)

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
	return weapon_chest.duplicate(true)

func add_item_to_weapon_chest(item: Dictionary) -> void:
	weapon_chest.append(item.duplicate(true))
	weapon_chest_changed.emit()

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
