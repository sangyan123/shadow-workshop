extends Control

## 灰盒阶段的临时关卡入口。
## 数字键 1/2 切换关卡，左右方向键上一关/下一关。
## 正式关卡选择页在 M2 之后再做。

const LEVEL_PATHS: Array[String] = [
	"res://data/levels/L01.json",
	"res://data/levels/L02.json",
	"res://data/levels/L03.json",
	"res://data/levels/L04.json",
	"res://data/levels/L05.json",
	"res://data/levels/L06.json",
	"res://data/levels/L07.json",
	"res://data/levels/L08.json",
	"res://data/levels/L09.json",
	"res://data/levels/L10.json",
	"res://data/levels/L11.json",
	"res://data/levels/L12.json",
]

var current_level_index: int = 0
var level_node: Control = null


func _ready() -> void:
	_open_level(0)


func _open_level(index: int) -> void:
	current_level_index = clampi(index, 0, LEVEL_PATHS.size() - 1)

	if is_instance_valid(level_node):
		remove_child(level_node)
		level_node.queue_free()
		level_node = null

	var level_scene: PackedScene = load("res://scenes/Level.tscn") as PackedScene
	if level_scene == null:
		push_error("无法加载 Level.tscn")
		return

	level_node = level_scene.instantiate() as Control
	level_node.set("level_path", LEVEL_PATHS[current_level_index])
	level_node.set("has_next_level", current_level_index < LEVEL_PATHS.size() - 1)
	level_node.connect("next_level_requested", _on_next_level_requested)
	add_child(level_node)


func _on_next_level_requested() -> void:
	# 延迟一帧再切换，避免在信号回调里销毁信号的发送者
	call_deferred("_open_level", current_level_index + 1)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	var handled: bool = true

	if key_event.keycode >= KEY_1 and key_event.keycode <= KEY_9:
		_open_level(key_event.keycode - KEY_1)
		get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_0:
		_open_level(9)
		get_viewport().set_input_as_handled()
		return

	match key_event.keycode:
		KEY_RIGHT:
			_open_level(current_level_index + 1)
		KEY_LEFT:
			_open_level(current_level_index - 1)
		_:
			handled = false

	if handled:
		get_viewport().set_input_as_handled()
