class_name FloatingCombatText
extends Label

func show_value(value_text: String, text_color: Color, world_offset: Vector2 = Vector2(0, -42)) -> void:
	text = value_text
	position = world_offset
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	size = Vector2(80, 18)
	add_theme_font_size_override("font_size", 12)
	add_theme_color_override("font_color", text_color)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 18.0, 0.65)
	tween.tween_property(self, "modulate:a", 0.0, 0.65)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
