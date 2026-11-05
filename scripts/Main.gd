extends Control


func _ready() -> void:
	var level_scene: PackedScene = load("res://scenes/Level.tscn") as PackedScene
	if level_scene == null:
		push_error("无法加载 Level.tscn")
		return

	var level: Control = level_scene.instantiate() as Control
	add_child(level)
