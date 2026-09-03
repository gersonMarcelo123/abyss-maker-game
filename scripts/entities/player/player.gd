## Player.gd
## Controlador principal del jugador. Pensado desde el inicio para 1-4
## jugadores locales: instancia esta escena una vez por jugador y asigna
## player_index / device_id (en el hijo PlayerInput) para cada una.
## Ver README.md para la estructura de escena esperada.
class_name Player
extends CharacterBody2D

@export var player_index: int = 0

@export_group("Movimiento")
@export var move_speed: float = 160.0
@export var sprint_multiplier: float = 1.6

@export_group("Combate")
@export var attack_type_is_ranged: bool = false
@export var melee_attack_range: float = 60.0
@export var ranged_attack_range: float = 220.0
@export var projectile_scene: PackedScene ## asigna Projectile.tscn aquí

@export_group("Muerte y revivir")
@export var knockback_distance: float = 90.0
@export var knockback_duration: float = 0.4
@export var revive_health_ratio: float = 0.5 ## % de vida máxima con la que revive

enum FacingState { IDLE, MOVING, APPROACHING, ATTACKING }

@onready var player_input: PlayerInput = $PlayerInput
@onready var target_selector: TargetSelector = $TargetSelector
@onready var attack_component: AttackComponent = $AttackComponent
@onready var stats: CharacterStats = $CharacterStats

## Estos dos son OPCIONALES: si todavía no agregaste esos nodos a la escena,
## el juego sigue corriendo sin visuales (solo no se ve nada), en vez de
## tirar un error. Ver README para cómo agregarlos.
@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var body_placeholder: Polygon2D = get_node_or_null("BodyPlaceholder")
@onready var status_bar: PlayerStatusBar = get_node_or_null("StatusBar")

const PLAYER_COLORS := [
	Color(0.30, 0.55, 1.0),  # P0 azul
	Color(1.0, 0.30, 0.30),  # P1 rojo
	Color(0.35, 1.0, 0.45),  # P2 verde
	Color(1.0, 0.85, 0.20),  # P3 amarillo
]

var _last_aim_dir: Vector2 = Vector2.DOWN
var _state: FacingState = FacingState.IDLE
var _is_dead: bool = false
var _last_hit_source_position: Vector2 = Vector2.INF
var _auto_attack_engaged: bool = false
var _last_attack_press_time: float = -10.0
var _death_knockback_velocity: Vector2 = Vector2.ZERO
const ACTIVE_INVENTORY_SLOTS := 6
const STORAGE_INVENTORY_SLOTS := 3
const ACCESSORY_SLOTS := ["Runa", "Libreta", "Pulsera", "Lente", "Anillo"]
var active_inventory: Array = []
var storage_inventory: Array = []
var accessory_inventory: Dictionary = {}
var equipped_weapon: Dictionary = {}   # arma equipada (melee, ranged, o item común)
var equipped_tool: Dictionary = {}     # herramienta equipada (vacío por ahora)

func _ready() -> void:
	add_to_group("players") # para que las plataformas de efectos lo detecten
	_load_persistent_loadout()
	for acc_name in ACCESSORY_SLOTS:
		accessory_inventory[acc_name] = {}
	accessory_inventory = GameState.get_accessories(player_index)
	_refresh_active_item_bonuses()
	refresh_accessory_bonuses()
	stats.set_base_move_speed(move_speed)

	_apply_weapon_type()
	attack_component.attack_windup_started.connect(_on_attack_windup_started)
	attack_component.attack_fired.connect(_on_attack_fired)
	target_selector.target_changed.connect(_on_target_changed)

	stats.stats_changed.connect(_on_stats_changed)
	stats.died.connect(_on_died)
	stats.damage_received.connect(_on_damage_received)
	_on_stats_changed() # aplica la velocidad de ataque inicial ya calculada

	if attack_type_is_ranged and projectile_scene == null:
		push_error("[P%d] 'Attack Type Is Ranged' está activado pero no asignaste 'Projectile Scene' en el Inspector — el ataque a distancia no va a disparar nada." % player_index)

	if body_placeholder:
		_build_placeholder_visual()

	if status_bar:
		status_bar.bind(stats)

func _physics_process(delta: float) -> void:
	if _is_dead:
		if _death_knockback_velocity.length() > 2.0:
			velocity = _death_knockback_velocity
			_death_knockback_velocity = _death_knockback_velocity.move_toward(Vector2.ZERO, delta * 320.0)
			move_and_slide()
		else:
			velocity = Vector2.ZERO
		if player_input.is_just_pressed("revive"):
			_revive()
		return

	_handle_menu_input()

	var move_dir := player_input.get_move_vector()
	var is_moving_manually := move_dir != Vector2.ZERO
	var current_time: float = Time.get_ticks_msec() / 1000.0

	# Recogida de objetos con Tecla F / Boton X
	if player_input.is_just_pressed("interact_pickup"):
		_try_pickup_nearby_item()

	# Activación de herramienta con Tecla R / Boton R1
	if player_input.is_just_pressed("use_tool"):
		_activate_equipped_tool()

	# Actualizar nombre flotante del ítem más cercano
	_update_ground_item_floating_names()

	# Al pulsar clic derecho / R2 activa la acción de atacar.
	# Doble pulsación rápida cancela la acción.
	if player_input.is_just_pressed("attack"):
		if _auto_attack_engaged and (current_time - _last_attack_press_time) < 0.38:
			# Doble pulsación: cancelar acción de atacar
			_auto_attack_engaged = false
			attack_component.cancel()
		else:
			# Una sola pulsación: activa caminar y atacar al objetivo
			_auto_attack_engaged = true
		_last_attack_press_time = current_time

	if player_input.is_just_pressed("cancel_attack"):
		_auto_attack_engaged = false
		attack_component.cancel()

	var aim_dir := player_input.get_aim_vector(self)
	if aim_dir != Vector2.ZERO:
		_last_aim_dir = aim_dir

	var target: Node2D = null
	if _auto_attack_engaged and is_instance_valid(target_selector.current_target):
		target = target_selector.current_target
	else:
		target = target_selector.update(global_position, aim_dir)

	if not is_instance_valid(target):
		target = null
		if _auto_attack_engaged and not is_instance_valid(target_selector.current_target):
			_auto_attack_engaged = false

	# Te puedes mover manualmente con WASD/palanca izquierda pero no puedes atacar y moverte a la vez.
	# Al moverte, dejas de atacar. Al dejar de moverte, continúa la acción de atacar.
	if is_moving_manually and attack_component.is_attacking:
		attack_component.cancel()

	var want_attack := _auto_attack_engaged and not is_moving_manually and target != null

	var must_approach := attack_component.process_attack(self, target, want_attack)

	_move(must_approach, target, move_dir, is_moving_manually)
	move_and_slide()
	_update_animation()

	_handle_ability_input()

func _move(must_approach: bool, target: Node2D, move_dir: Vector2, is_moving_manually: bool) -> void:
	var is_sprinting := player_input.is_pressed("sprint") and not attack_component.is_attacking

	if is_moving_manually:
		# Movimiento manual libre prioritario sobre el ataque
		var speed := move_speed * (sprint_multiplier if is_sprinting else 1.0)
		velocity = move_dir * speed
		_state = FacingState.MOVING
	elif attack_component.is_attacking:
		# Plantado golpeando: no se mueve, pero se orienta hacia el objetivo.
		velocity = Vector2.ZERO
		if is_instance_valid(target):
			_last_aim_dir = (target.global_position - global_position).normalized()
		_state = FacingState.ATTACKING
	elif must_approach and is_instance_valid(target):
		var to_target: Vector2 = target.global_position - global_position
		velocity = to_target.normalized() * move_speed
		_last_aim_dir = to_target.normalized()
		_state = FacingState.APPROACHING
	else:
		velocity = Vector2.ZERO
		_state = FacingState.IDLE

func _on_target_changed(old_target, new_target) -> void:
	if is_instance_valid(old_target) and old_target.has_method("set_targeted"):
		old_target.set_targeted(false)
	if is_instance_valid(new_target) and new_target.has_method("set_targeted"):
		new_target.set_targeted(true)


# ---------------------------------------------------------------------------
# API pública de estadísticas — usada por las plataformas de efectos, y a
# futuro por trampas, curanderos de la tienda, pociones, gadgets, etc.
# ---------------------------------------------------------------------------

func take_damage(amount: float, source_position: Vector2 = Vector2.INF, damage_type: int = CharacterStats.DamageType.PHYSICAL) -> void:
	if _is_dead:
		return
	_last_hit_source_position = source_position
	stats.take_damage(amount, damage_type)

func heal(amount: float) -> void:
	stats.heal(amount)

func is_alive() -> bool:
	return not _is_dead

func _on_damage_received(_raw: float, final_damage: float, _damage_type: int) -> void:
	var indicator := FloatingCombatText.new()
	add_child(indicator)
	indicator.show_value("-%.1f" % final_damage, Color(1.0, 0.2, 0.2))

## Úsalo desde habilidades, pasivas o aliados: el bono de curación pertenece
## al sanador, no al objetivo que recibe la cura.
func heal_target(target: Player, base_amount: float) -> void:
	if is_instance_valid(target):
		target.heal(stats.calculate_healing(base_amount))

func add_attribute_points(strength_delta: int, intelligence_delta: int, agility_delta: int, resistance_delta: int = 0) -> void:
	stats.add_attribute_points(strength_delta, intelligence_delta, agility_delta, resistance_delta)

func add_physical_damage(amount: float) -> void:
	stats.add_physical_damage(amount)

func add_magic_damage(amount: float) -> void:
	stats.add_magic_damage(amount)

func add_movement_speed_percent(amount: float) -> void:
	stats.add_movement_speed_percent(amount)

func add_cooldown_reduction_percent(amount: float) -> void:
	stats.add_cooldown_reduction_percent(amount)

func add_healing_bonus_percent(amount: float) -> void:
	stats.add_healing_bonus_percent(amount)

func add_ranged_attack_range(amount: float) -> void:
	stats.add_ranged_attack_range(amount)

func add_cast_range(amount: float) -> void:
	stats.add_cast_range(amount)

func add_armor(amount: float) -> void:
	stats.add_armor(amount)

func reset_received_stats() -> void:
	stats.reset_received_stats()

func add_inventory_item(item: Dictionary) -> bool:
	for slot_index in range(active_inventory.size()):
		if active_inventory[slot_index].is_empty():
			active_inventory[slot_index] = item.duplicate(true)
			_refresh_active_item_bonuses()
			_save_persistent_loadout()
			return true
	for slot_index in range(storage_inventory.size()):
		if storage_inventory[slot_index].is_empty():
			storage_inventory[slot_index] = item.duplicate(true)
			_refresh_active_item_bonuses()
			_save_persistent_loadout()
			return true
	return false

func get_inventory_item(slot_group: String, slot_index: int) -> Dictionary:
	if slot_group == "weapon": return equipped_weapon.duplicate(true)
	if slot_group == "tool": return equipped_tool.duplicate(true)
	var inventory := _get_inventory_group(slot_group)
	if slot_index < 0 or slot_index >= inventory.size():
		return {}
	return inventory[slot_index]

func swap_inventory_slots(from_group: String, from_index: int, to_group: String, to_index: int) -> void:
	var from_item := get_inventory_item(from_group, from_index)
	var to_item := get_inventory_item(to_group, to_index)
	if not _can_place_item(from_item, to_group): return
	if not _can_place_item(to_item, from_group): return
	_set_inventory_item(from_group, from_index, to_item)
	_set_inventory_item(to_group, to_index, from_item)
	_refresh_active_item_bonuses()
	_save_persistent_loadout()

func _get_inventory_group(slot_group: String) -> Array:
	return active_inventory if slot_group == "active" else storage_inventory

func _can_place_item(item: Dictionary, slot_group: String) -> bool:
	if item.is_empty(): return true
	var kind: String = str(item.get("kind", "item"))
	if slot_group == "tool":
		return kind == "tool" or kind == "herramienta"
	if slot_group == "weapon":
		return kind != "tool" and kind != "herramienta"
	return true

func _set_inventory_item(slot_group: String, slot_index: int, item: Dictionary) -> void:
	if slot_group == "weapon":
		equipped_weapon = item.duplicate(true)
		_apply_weapon_type()
		_refresh_active_item_bonuses()
		return
	if slot_group == "tool":
		equipped_tool = item.duplicate(true)
		return
	var inventory := _get_inventory_group(slot_group)
	if slot_index >= 0 and slot_index < inventory.size():
		inventory[slot_index] = item.duplicate(true)

func _load_persistent_loadout() -> void:
	var loadout: Dictionary = GameState.get_player_loadout(player_index)
	active_inventory = loadout.get("active", []).duplicate(true)
	storage_inventory = loadout.get("storage", []).duplicate(true)
	while active_inventory.size() < ACTIVE_INVENTORY_SLOTS: active_inventory.append({})
	while storage_inventory.size() < STORAGE_INVENTORY_SLOTS: storage_inventory.append({})
	equipped_weapon = loadout.get("weapon", {}).duplicate(true)
	equipped_tool = loadout.get("tool", {}).duplicate(true)

func _save_persistent_loadout() -> void:
	GameState.set_player_loadout(player_index, {"active": active_inventory, "storage": storage_inventory, "weapon": equipped_weapon, "tool": equipped_tool})

# ---- Weapon & Tool slots ----
func equip_weapon(item: Dictionary) -> void:
	equipped_weapon = item.duplicate(true)
	_apply_weapon_type()
	_refresh_active_item_bonuses()
	_save_persistent_loadout()

func unequip_weapon() -> Dictionary:
	var old: Dictionary = equipped_weapon.duplicate(true)
	equipped_weapon = {}
	_apply_weapon_type()
	_refresh_active_item_bonuses()
	_save_persistent_loadout()
	return old

func equip_tool(item: Dictionary) -> void:
	equipped_tool = item.duplicate(true)
	_save_persistent_loadout()

func unequip_tool() -> Dictionary:
	var old: Dictionary = equipped_tool.duplicate(true)
	equipped_tool = {}
	_save_persistent_loadout()
	return old

func _activate_equipped_tool() -> void:
	if equipped_tool.is_empty():
		return
	var effect: String = str(equipped_tool.get("tool_effect", ""))
	var tool_id: String = str(equipped_tool.get("id", ""))
	if effect == "teleport" or tool_id == "reloj_del_espacio":
		_teleport_tool(float(equipped_tool.get("max_distance", 600.0)))

func _teleport_tool(max_dist: float) -> void:
	var aim_target: Vector2 = Vector2.ZERO
	if player_input.device_id == -1:
		aim_target = get_global_mouse_position()
	else:
		var aim_vec := player_input.get_aim_vector(self)
		if aim_vec == Vector2.ZERO:
			aim_vec = _last_aim_dir
		aim_target = global_position + aim_vec * max_dist
	
	var dir := aim_target - global_position
	var dist := minf(dir.length(), max_dist)
	if dist < 1.0:
		return
	var target_pos := global_position + dir.normalized() * dist
	
	# Raycast contra obstáculos (paredes mask=1)
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, target_pos, 1)
	query.exclude = [self]
	var result := space_state.intersect_ray(query)
	if not result.is_empty():
		var hit_pos: Vector2 = result.position
		var to_hit := hit_pos - global_position
		target_pos = global_position + to_hit.normalized() * maxf(to_hit.length() - 16.0, 0.0)
	
	global_position = target_pos
	var indicator := FloatingCombatText.new()
	add_child(indicator)
	indicator.show_value("¡Teletransporte!", Color(0.3, 0.85, 1.0))

func get_weapon_damage() -> float:
	return float(equipped_weapon.get("damage", 0.0))

func _apply_weapon_type() -> void:
	var wtype: String = equipped_weapon.get("weapon_type", "")
	var is_ranged: bool = (wtype == "ranged")
	attack_type_is_ranged = is_ranged
	attack_component.attack_type = (
		AttackComponent.AttackType.RANGED if is_ranged
		else AttackComponent.AttackType.MELEE
	)
	var custom_range: float = float(equipped_weapon.get("range", 0.0))
	if is_ranged:
		attack_component.attack_range = custom_range if custom_range > 0.0 else ranged_attack_range
	else:
		attack_component.attack_range = melee_attack_range
	_on_stats_changed()

func _refresh_active_item_bonuses() -> void:
	var total_bonuses: Dictionary = {}
	for item: Dictionary in active_inventory:
		if item.is_empty():
			continue
		var kind: String = str(item.get("kind", "item"))
		# Armas y herramientas en casillas generales de inventario NO aplican atributos
		if kind == "weapon" or kind == "arma" or kind == "tool" or kind == "herramienta":
			continue
		var bonuses: Dictionary = item.get("bonuses", {})
		for stat_name in bonuses:
			total_bonuses[stat_name] = total_bonuses.get(stat_name, 0.0) + bonuses[stat_name]

	# Aplicar estadísticas del arma equipada únicamente
	if not equipped_weapon.is_empty():
		var wb: Dictionary = equipped_weapon.get("bonuses", {})
		for stat_name in wb:
			total_bonuses[stat_name] = total_bonuses.get(stat_name, 0.0) + wb[stat_name]
		var dmg_bonus: float = float(equipped_weapon.get("damage", 0.0))
		if dmg_bonus != 0.0:
			total_bonuses["physical_damage"] = total_bonuses.get("physical_damage", 0.0) + dmg_bonus
	stats.set_item_bonuses(total_bonuses)

func drop_inventory_item(slot_group: String, slot_index: int) -> bool:
	if slot_group == "accessory":
		return false
	var item: Dictionary = {}
	if slot_group == "weapon":
		item = unequip_weapon()
	elif slot_group == "tool":
		item = unequip_tool()
	else:
		var inventory := _get_inventory_group(slot_group)
		if slot_index < 0 or slot_index >= inventory.size() or inventory[slot_index].is_empty():
			return false
		item = inventory[slot_index]
		inventory[slot_index] = {}
		_refresh_active_item_bonuses()
		_save_persistent_loadout()
	if item.is_empty():
		return false
	var dropped := preload("res://scenes/items/GroundItem.tscn").instantiate() as GroundItem
	dropped.global_position = global_position + _last_aim_dir * 20.0
	dropped.item_id = str(item.get("id", "dropped_item"))
	dropped.display_name = str(item.get("name", "Objeto"))
	dropped.short_name = str(item.get("short_name", "Obj"))
	dropped.loot_kind = str(item.get("kind", "item"))
	dropped.tier = int(item.get("tier", 1))
	dropped.color = AccessoryPresentation.tier_color(item)
	dropped.full_item_data = item.duplicate(true)
	get_tree().current_scene.add_child(dropped)
	return true

func use_item_from_inventory(group: String, index: int, target_player: Player) -> bool:
	var inv := _get_inventory_group(group)
	if index < 0 or index >= inv.size() or inv[index].is_empty():
		return false
	var item: Dictionary = inv[index]
	if item.get("is_consumable", false):
		var heal: float = float(item.get("heal_amount", 0.0))
		if heal > 0.0 and is_instance_valid(target_player):
			target_player.heal(heal)
			var indicator := FloatingCombatText.new()
			target_player.add_child(indicator)
			indicator.show_value("+%.0f HP" % heal, Color(0.2, 1.0, 0.4))
		var uses: int = int(item.get("current_uses", 1)) - 1
		item["current_uses"] = uses
		if uses <= 0:
			inv[index] = {}
		else:
			inv[index] = item
		_refresh_active_item_bonuses()
		_save_persistent_loadout()
		return true
	return false

func _update_ground_item_floating_names() -> void:
	if player_index != 0: return
	var nearest_item: GroundItem = null
	var nearest_dist: float = 75.0
	var items := get_tree().get_nodes_in_group("ground_items")
	for node in items:
		if node is GroundItem and is_instance_valid(node):
			var d := global_position.distance_to(node.global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest_item = node
	for node in items:
		if node is GroundItem and is_instance_valid(node):
			node.set_floating_name_visible(node == nearest_item)


func refresh_accessory_bonuses() -> void:
	var total_bonuses: Dictionary = {}
	for slot_name in ACCESSORY_SLOTS:
		var accessory: Dictionary = accessory_inventory.get(slot_name, {})
		if accessory.is_empty():
			continue
		var bonuses: Dictionary = accessory.get("bonuses", {})
		for stat_name in bonuses:
			total_bonuses[stat_name] = total_bonuses.get(stat_name, 0.0) + bonuses[stat_name]
	stats.set_accessory_bonuses(total_bonuses)

func _try_pickup_nearby_item() -> bool:
	var nearest_item: GroundItem = null
	var nearest_distance: float = INF
	for node in get_tree().get_nodes_in_group("ground_items"):
		if not (node is GroundItem) or not is_instance_valid(node):
			continue
		var item: GroundItem = node
		var distance: float = global_position.distance_to(item.global_position)
		if distance <= item.pickup_range and distance < nearest_distance:
			nearest_item = item
			nearest_distance = distance
	if nearest_item:
		return nearest_item.try_pickup(self)
	return false

func get_cast_range(base_range: float) -> float:
	return max(base_range + stats.get_total_cast_range_bonus(), 0.0)

func get_ability_cooldown(base_seconds: float) -> float:
	return stats.get_cooldown_duration(base_seconds, CharacterStats.CooldownTag.REDUCIBLE_ABILITY)

func get_item_cooldown(base_seconds: float) -> float:
	return stats.get_cooldown_duration(base_seconds, CharacterStats.CooldownTag.FIXED_ITEM)

func _on_stats_changed() -> void:
	# La velocidad de ataque depende de la agilidad; cada vez que cambian
	# los atributos, se refleja de inmediato en el componente de ataque.
	attack_component.attacks_per_second = stats.attack_speed
	move_speed = stats.movement_speed
	var base_r: float = float(equipped_weapon.get("range", ranged_attack_range)) if attack_type_is_ranged else melee_attack_range
	attack_component.attack_range = (
		base_r + stats.get_total_ranged_attack_range_bonus() + _weapon_range_bonus() if attack_type_is_ranged
		else melee_attack_range
	)

func _weapon_range_bonus() -> float:
	return float(equipped_weapon.get("passive_value", 0.0)) if equipped_weapon.get("passive", "") == "range_bonus" else 0.0

func _on_died() -> void:
	if _is_dead:
		return
	_is_dead = true
	attack_component.cancel()
	target_selector.clear_target()
	_auto_attack_engaged = false

	# Dirección OPUESTA a quien causó la muerte.
	var direction := Vector2.DOWN
	if _last_hit_source_position != Vector2.INF:
		var away := global_position - _last_hit_source_position
		if away.length() > 1.0:
			direction = away.normalized()

	_death_knockback_velocity = direction * (knockback_distance / maxf(knockback_duration, 0.1))

	if body_placeholder:
		body_placeholder.modulate = Color(0.35, 0.35, 0.35) # gris = caído

## Revive al personaje EN EL MISMO LUGAR donde quedó su cadáver.
func _revive() -> void:
	_is_dead = false
	_death_knockback_velocity = Vector2.ZERO
	stats.current_health = stats.max_health * revive_health_ratio
	stats.health_changed.emit(stats.current_health, stats.max_health)
	if body_placeholder:
		body_placeholder.modulate = Color.WHITE
	print("[P%d] ha revivido con %.0f/%.0f de vida" % [player_index, stats.current_health, stats.max_health])

func _on_attack_windup_started(_target: Node2D) -> void:
	# TODO: acá va el disparo de la animación de "cargando ataque" cuando
	# tengas los SpriteFrames reales — por ejemplo sprite.play("windup_" +
	# _direction_to_8way(_last_aim_dir)). Por ahora no hace falta nada más:
	# _update_animation() ya deja al personaje quieto mirando al objetivo
	# mientras is_attacking es true (windup incluido).
	pass

func _on_attack_fired(target: Node2D) -> void:
	if attack_component.attack_type == AttackComponent.AttackType.RANGED:
		_spawn_projectile(target)
	else:
		_apply_melee_damage(target)

func _spawn_projectile(target: Node2D) -> void:
	if projectile_scene == null:
		push_warning("Player: asigna 'projectile_scene' en el Inspector (Projectile.tscn) para el ataque a distancia")
		return
	var projectile := projectile_scene.instantiate()
	projectile.target = target
	projectile.damage = stats.physical_damage
	projectile.damage_type = CharacterStats.DamageType.PHYSICAL
	# Se pone la posición ANTES de agregarlo al árbol, porque el proyectil
	# calcula su dirección inicial en su propio _ready().
	projectile.position = global_position
	get_tree().current_scene.add_child(projectile)

func _apply_melee_damage(target: Node2D) -> void:
	if target.has_method("take_damage"):
		target.take_damage(stats.physical_damage, global_position, CharacterStats.DamageType.PHYSICAL)
		if equipped_weapon.get("passive", "") == "lifesteal":
			heal(stats.physical_damage * float(equipped_weapon.get("passive_value", 0.0)))
	print("[P%d] golpea cuerpo a cuerpo a %s" % [player_index, target.name])

func _handle_ability_input() -> void:
	if player_input.is_just_pressed("ability_1"):
		_cast_ability(0)
	if player_input.is_just_pressed("ability_2"):
		_cast_ability(1)
	if player_input.is_just_pressed("ability_3"):
		_cast_ability(2)
	if player_input.is_just_pressed("ultimate"):
		_cast_ultimate()
	if player_input.is_just_pressed("gadget"):
		_use_gadget()

func _cast_ability(slot: int) -> void:
	print("[P%d] usa la habilidad del slot %d" % [player_index, slot])
	# TODO: sistema de habilidades (cooldown, costo de maná, escalado por atributos)

func _cast_ultimate() -> void:
	print("[P%d] usa su ULTIMATE de clase" % player_index)
	# TODO: ulti única por clase (Guerrero, Mago, Pícaro, Paladín...)

func _use_gadget() -> void:
	print("[P%d] activa su gadget activable" % player_index)
	# TODO: sistema de gadgets activables (cooldown propio, no gasta inventario)

func _handle_menu_input() -> void:
	if player_input.is_just_pressed("pause"):
		print("[P%d] pide pausa" % player_index)
		# TODO: abrir menú de pausa
	# El abrir/cerrar el inventario (tecla I) lo maneja directamente
	# InventoryMenu.gd de forma global, para que siga funcionando incluso
	# con el árbol pausado (ver la nota en ese script). Este bloque queda
	# libre para lo que SÍ sea específico de cada jugador más adelante.

# ---------------------------------------------------------------------------
# Animación de 8 direcciones
# ---------------------------------------------------------------------------

func _update_animation() -> void:
	# Mientras ataca o se acerca, mira hacia el objetivo (_last_aim_dir).
	# El resto del tiempo, mira hacia donde se mueve.
	var dir := _last_aim_dir
	if _state == FacingState.MOVING:
		dir = velocity

	var anim_suffix := _direction_to_8way(dir)
	var base_anim := "idle"
	match _state:
		FacingState.ATTACKING:
			base_anim = "attack"
		FacingState.MOVING, FacingState.APPROACHING:
			base_anim = "run"

	var anim_name := "%s_%s" % [base_anim, anim_suffix]
	# Si todavía no importaste los SpriteFrames con esas animaciones, esto
	# simplemente no reproduce nada (no revienta el juego).
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)

	# Mientras no tengas sprites con 8 direcciones, el placeholder (flecha)
	# rota para mostrar hacia dónde apunta/camina el personaje.
	if body_placeholder:
		body_placeholder.rotation = dir.angle()

## Placeholder visible sin necesidad de ninguna imagen: un triángulo que
## apunta hacia donde miras, coloreado según player_index. Reemplázalo
## cuando tengas tus sprites reales (basta con borrar el nodo BodyPlaceholder
## o dejarlo oculto).
func _build_placeholder_visual() -> void:
	var size := 22.0
	body_placeholder.polygon = PackedVector2Array([
		Vector2(size, 0),
		Vector2(-size * 0.6, size * 0.6),
		Vector2(-size * 0.3, 0),
		Vector2(-size * 0.6, -size * 0.6),
	])
	body_placeholder.color = PLAYER_COLORS[player_index % PLAYER_COLORS.size()]
	body_placeholder.modulate.a = 0.2

func _direction_to_8way(dir: Vector2) -> String:
	if dir == Vector2.ZERO:
		dir = _last_aim_dir
	var angle := rad_to_deg(dir.angle()) # 0° = derecha, 90° = abajo (Y+ hacia abajo)
	var octant := int(round(angle / 45.0)) % 8
	if octant < 0:
		octant += 8
	const NAMES := ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"]
	return NAMES[octant]
