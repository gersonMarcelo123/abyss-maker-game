class_name EconomyHUD
extends CanvasLayer

@export var show_materials := false
var _gold_label: Label
var _materials_label: Label

func _ready() -> void:
	layer = 8
	_gold_label = Label.new()
	_gold_label.position = Vector2(12, get_viewport().get_visible_rect().size.y - 46)
	_gold_label.add_theme_font_size_override("font_size", 18)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.2))
	add_child(_gold_label)
	_materials_label = Label.new()
	_materials_label.position = Vector2(12, get_viewport().get_visible_rect().size.y - 24)
	_materials_label.add_theme_font_size_override("font_size", 12)
	add_child(_materials_label)
	GameState.gold_changed.connect(_refresh)
	GameState.materials_changed.connect(_refresh)
	_refresh()

func _refresh(_ignored: Variant = null) -> void:
	_gold_label.text = "Oro: %d" % GameState.gold
	_materials_label.visible = show_materials
	if show_materials:
		var parts: Array[String] = []
		for material_name in GameState.materials: parts.append("%s ×%d" % [material_name, GameState.materials[material_name]])
		_materials_label.text = "Materiales: " + ", ".join(parts)
