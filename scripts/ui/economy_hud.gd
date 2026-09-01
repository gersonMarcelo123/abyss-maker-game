class_name EconomyHUD
extends CanvasLayer

@export var show_materials := false
var _gold_label: Label
var _materials_label: Label
var _panel: PanelContainer

func _ready() -> void:
	layer = 12
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_top = 1.0
	_panel.anchor_right = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 10
	_panel.offset_bottom = -10
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.grow_horizontal = Control.GROW_DIRECTION_END
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.11, 0.82)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_panel)

	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(container)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 12)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.2))
	container.add_child(_gold_label)

	_materials_label = Label.new()
	_materials_label.add_theme_font_size_override("font_size", 9)
	_materials_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	container.add_child(_materials_label)

	GameState.gold_changed.connect(_refresh)
	GameState.materials_changed.connect(_refresh)
	_refresh()

func _refresh(_ignored: Variant = null) -> void:
	_gold_label.text = "Oro: %d" % GameState.gold
	_materials_label.visible = show_materials
	if show_materials:
		var parts: Array[String] = []
		for material_name in GameState.materials:
			var count: int = int(GameState.materials[material_name])
			if count > 0:
				parts.append("%s ×%d" % [material_name, count])
		_materials_label.text = "Materiales: " + (", ".join(parts) if not parts.is_empty() else "Ninguno")
