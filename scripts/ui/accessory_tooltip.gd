class_name AccessoryTooltip
extends PanelContainer

func show_accessory(accessory: Dictionary, _screen_position: Vector2) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.08, 0.96)
	style.set_border_width_all(1)
	style.border_color = Color(0.45, 0.75, 1.0)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6; style.content_margin_right = 6
	style.content_margin_top = 5; style.content_margin_bottom = 5
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	add_child(box)
	var title := Label.new()
	title.text = "%s %s · T%d" % [AccessoryPresentation.icon_for(accessory), accessory.get("name", "Accesorio"), AccessoryPresentation.tier_of(accessory)]
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", AccessoryPresentation.tier_color(accessory))
	box.add_child(title)
	var bonuses: Dictionary = accessory.get("bonuses", {})
	# Godot entrega las claves de un Dictionary como Variant; declararlo evita
	# inferencias ambiguas y mantiene el panel compatible con el depurador.
	var keys: Array = bonuses.keys()
	if not keys.is_empty():
		var main := Label.new()
		main.text = "Principal: " + AccessoryPresentation.format_stat(str(keys[0]), bonuses[keys[0]])
		main.add_theme_font_size_override("font_size", 9)
		main.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
		box.add_child(main)
		# La ficha muestra todos los modificadores existentes, sin ocultar
		# atributos principales ni secundarios.
		for index in range(1, keys.size()):
			var secondary := Label.new()
			secondary.text = "Sec.: " + AccessoryPresentation.format_stat(str(keys[index]), bonuses[keys[index]])
			secondary.add_theme_font_size_override("font_size", 9)
			secondary.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
			box.add_child(secondary)
	# El panel permanece fijo a la derecha: nunca tapa la casilla que lo activó.
	var viewport_size := get_viewport_rect().size
	position = Vector2(maxf(12.0, viewport_size.x - 190.0), 18.0)
	custom_minimum_size = Vector2(175, 0)
