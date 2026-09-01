class_name ArtifactForgePlatform
extends Area2D

@export var artifact_type := "Runa"
@export var clear_chest := false
var _armed := true

func _ready() -> void:
	collision_mask = 2
	var shape := CircleShape2D.new()
	shape.radius = 24.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([Vector2(-22,0), Vector2(0,-14), Vector2(22,0), Vector2(0,14)])
	visual.color = Color(0.75, 0.18, 0.18) if clear_chest else Color(0.22, 0.58, 0.9)
	add_child(visual)
	var label := Label.new()
	label.text = "Vaciar baúl" if clear_chest else "Crear %s" % artifact_type
	label.position = Vector2(-42, 18)
	label.size = Vector2(84, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	add_child(label)
	body_entered.connect(_on_body_entered)
	body_exited.connect(func(_body: Node2D): _armed = true)

func _on_body_entered(body: Node2D) -> void:
	if not _armed or not body.is_in_group("players"): return
	_armed = false
	if clear_chest: GameState.clear_artifact_chest()
	else: GameState.add_artifact(ArtifactFactory.create(artifact_type))
