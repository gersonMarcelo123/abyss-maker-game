extends Control
func _on_test_pressed() -> void: get_tree().change_scene_to_file("res://scenes/levels/TestLevel.tscn")
func _on_generated_pressed() -> void: get_tree().change_scene_to_file("res://scenes/levels/GeneratedLevel1.tscn")
