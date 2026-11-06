extends Control

@export var level_path: String = "res://data/levels/L01.json"

const BOARD_RECT: Rect2 = Rect2(70, 170, 580, 520)
const DESK_RECT: Rect2 = Rect2(60, 760, 600, 310)
const OBJECT_VISUAL_SCALE: float = 360.0
const DESIGN_WIDTH: float = 720.0

var level_data: Dictionary = {}
var object_states: Array = []
var target_shapes: Array = []
var active_light_index: int = 0
var selected_object_index: int = -1
var dragging_object_index: int = -1
var drag_source: String = "desk"
var drag_offset: Vector2 = Vector2.ZERO
var drag_moved: bool = false
var snapped_count: int = 0
var steps: int = 0
var has_won: bool = false

var header_label: Label
var description_label: Label
var status_label: Label
var result_label: Label
var hint_label: Label
var rotate_ccw_button: Button
var rotate_cw_button: Button
var light_button: Button
var reset_button: Button
var check_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_level()
	_build_ui()
	_reset_level()
	queue_redraw()


func _load_level() -> void:
	var file: FileAccess = FileAccess.open(level_path, FileAccess.READ)
	if file == null:
		push_error("无法打开关卡文件：%s" % level_path)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("关卡 JSON 格式无效：%s" % level_path)
		return

	level_data = parsed

	for raw_shape in level_data.get("target_shapes", []):
		target_shapes.append(_to_pixel_polygon(raw_shape))

	for raw_object in level_data.get("objects", []):
		var position_values: Array = raw_object.get("position", [0.5, 0.5])
		var initial_position: Vector2 = Vector2(float(position_values[0]), float(position_values[1]))
		object_states.append({
			"data": raw_object,
			"position": initial_position,
			"rotation_deg": float(raw_object.get("rotation_deg", 0.0)),
			"initial_position": initial_position,
			"initial_rotation_deg": float(raw_object.get("rotation_deg", 0.0))
		})

	active_light_index = _default_light_index()


func _build_ui() -> void:
	var input_layer: Control = Control.new()
	input_layer.name = "InputLayer"
	input_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	input_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	input_layer.gui_input.connect(_on_input_layer_gui_input)
	add_child(input_layer)

	header_label = _create_label(Vector2(24, 22), Vector2(size.x - 48, 46), 32, Color("4A3224"))
	description_label = _create_label(Vector2(24, 72), Vector2(size.x - 48, 44), 20, Color("7A6047"))
	status_label = _create_label(Vector2(24, 120), Vector2(size.x - 48, 36), 22, Color("5A4632"))
	result_label = _create_label(Vector2(24, 706), Vector2(size.x - 48, 44), 24, Color("2F6B4F"))
	hint_label = _create_label(Vector2(24, 1080), Vector2(size.x - 48, 72), 20, Color("8A6C50"))

	rotate_ccw_button = _create_button("逆转", Vector2(24, 1164), Vector2(80, 64), _on_rotate_pressed.bind(-30.0))
	rotate_ccw_button.visible = false

	rotate_cw_button = _create_button("顺转", Vector2(112, 1164), Vector2(80, 64), _on_rotate_pressed.bind(30.0))
	rotate_cw_button.visible = false

	light_button = _create_button("切换灯位", Vector2(200, 1164), Vector2(110, 64), _on_light_pressed)
	light_button.visible = false

	reset_button = _create_button("重置", Vector2(318, 1164), Vector2(110, 64), _on_reset_pressed)
	check_button = _create_button("检查影子", Vector2(436, 1164), Vector2(260, 64), _on_check_pressed)

	rotate_ccw_button.add_theme_font_size_override("font_size", 22)
	rotate_cw_button.add_theme_font_size_override("font_size", 22)
	light_button.add_theme_font_size_override("font_size", 22)
	reset_button.add_theme_font_size_override("font_size", 22)
	check_button.add_theme_font_size_override("font_size", 24)

	_update_labels()
	_update_action_buttons()


func _create_label(label_position: Vector2, label_size: Vector2, font_size: int, font_color: Color) -> Label:
	var label: Label = Label.new()
	label.position = label_position
	label.size = label_size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	return label


func _create_button(button_text: String, button_position: Vector2, button_size: Vector2, handler: Callable) -> Button:
	var button: Button = Button.new()
	button.text = button_text
	button.position = button_position
	button.size = button_size
	button.pressed.connect(handler)
	add_child(button)
	return button


func _draw() -> void:
	_draw_background()
	_draw_board()
	_draw_target()
	_draw_shadow()
	_draw_target_outline()
	_draw_desk()
	_draw_objects()


func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("F2E3C6"))
	draw_rect(Rect2(0, 0, size.x, 140), Color("E7D2AC"))
	draw_rect(Rect2(0, size.y - 90, size.x, 90), Color("E7D2AC"))


func _draw_board() -> void:
	draw_rect(BOARD_RECT, Color("FFF7E8"))
	draw_rect(BOARD_RECT, Color("B98A5F"), false, 3)
	draw_rect(Rect2(BOARD_RECT.position + Vector2(8, 8), BOARD_RECT.size - Vector2(16, 16)), Color("D9C2A0"), false, 1)


func _draw_target() -> void:
	for polygon in target_shapes:
		if polygon.size() >= 3:
			draw_colored_polygon(polygon, Color(1.0, 1.0, 1.0, 0.45))


func _draw_shadow() -> void:
	for state in object_states:
		var polygon: PackedVector2Array = _project_shadow_polygon(state)
		if polygon.size() >= 3:
			draw_colored_polygon(polygon, Color("4A382C"))
			var closed: PackedVector2Array = polygon.duplicate()
			closed.append(polygon[0])
			draw_polyline(closed, Color("2E2118"), 2.0, true)


func _draw_target_outline() -> void:
	for polygon in target_shapes:
		if polygon.size() >= 3:
			var closed: PackedVector2Array = polygon.duplicate()
			closed.append(polygon[0])
			draw_polyline(closed, Color("D29A5C"), 3.0, true)


func _draw_desk() -> void:
	draw_rect(DESK_RECT, Color("C98A57"))
	draw_rect(DESK_RECT, Color("8A5A34"), false, 3)
	draw_rect(Rect2(DESK_RECT.position + Vector2(8, 8), DESK_RECT.size - Vector2(16, 16)), Color("DCA471"), false, 1)


func _draw_objects() -> void:
	var index: int = 0
	for state in object_states:
		var polygon: PackedVector2Array = _object_display_polygon(state)
		var center: Vector2 = _object_display_center(state)
		var is_movable: bool = bool(state["data"].get("movable", false))

		if polygon.size() >= 3:
			var is_selected: bool = index == selected_object_index
			var is_dragging: bool = index == dragging_object_index

			var fill_color: Color = Color("F7E4BE")
			if not is_movable:
				fill_color = Color("D6C6A6")
			elif is_selected:
				fill_color = Color("FFE9C2")
			draw_colored_polygon(polygon, fill_color)

			var closed: PackedVector2Array = polygon.duplicate()
			closed.append(polygon[0])
			var line_color: Color = Color("6D4B31")
			if not is_movable:
				line_color = Color("8A6C50")
			elif is_selected:
				line_color = Color("D9601F")
			var line_width: float = 5.0 if is_selected else 3.0
			draw_polyline(closed, line_color, line_width, true)

			if not is_movable:
				var half: float = 7.0
				draw_rect(Rect2(center - Vector2(half, half), Vector2(half * 2.0, half * 2.0)), Color("8A6C50"), false, 2.0)
			elif not is_selected:
				var radius: float = 0.0
				for point in polygon:
					radius = maxf(radius, point.distance_to(center))
				draw_arc(center, radius + 14.0, 0.0, TAU, 48, Color(0.85, 0.47, 0.18, 0.38), 2.0, true)

			if is_selected and is_movable:
				draw_circle(center, 9.0 if is_dragging else 7.0, Color("D9601F"))

		index += 1


func _on_input_layer_gui_input(event: InputEvent) -> void:
	_handle_pointer_event(event)


func _handle_pointer_event(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_begin_drag_at(mouse_event.position)
			else:
				_end_drag()
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			_begin_drag_at(touch_event.position)
		else:
			_end_drag()
	elif event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		if dragging_object_index >= 0:
			_move_object_to(motion_event.position)
	elif event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event as InputEventScreenDrag
		if dragging_object_index >= 0:
			_move_object_to(drag_event.position)


func _begin_drag_at(screen_position: Vector2) -> void:
	selected_object_index = _hit_object(screen_position)
	drag_source = "desk"

	if selected_object_index < 0:
		var shadow_index: int = _hit_shadow(screen_position)
		if shadow_index >= 0:
			selected_object_index = shadow_index
			drag_source = "shadow"
		else:
			_update_action_buttons()
			result_label.add_theme_color_override("font_color", Color("8A6C50"))
			result_label.text = "点住桌面上的物件（或它在投影板上的影子）拖动。"
			queue_redraw()
			return

	_update_action_buttons()

	var state: Dictionary = object_states[selected_object_index]
	var raw_object: Dictionary = state["data"]
	if not bool(raw_object.get("movable", false)):
		_update_labels()
		queue_redraw()
		return

	dragging_object_index = selected_object_index
	drag_moved = false

	if drag_source == "shadow":
		var shadow_normal: Vector2 = _board_normal_from_screen(screen_position)
		var pointer_object_position: Vector2 = _object_position_from_shadow(shadow_normal, raw_object)
		drag_offset = state["position"] - pointer_object_position
	else:
		var pointer_normal: Vector2 = _desk_normal_from_screen(screen_position)
		drag_offset = state["position"] - pointer_normal

	queue_redraw()


func _end_drag() -> void:
	var did_drag: bool = dragging_object_index >= 0 and drag_moved

	if did_drag:
		steps += 1

	dragging_object_index = -1
	drag_source = "desk"
	drag_offset = Vector2.ZERO
	drag_moved = false

	if did_drag:
		snapped_count = _try_snap_to_solution()
		has_won = false
		_update_labels()
		queue_redraw()
		_show_alignment_progress()


func _try_snap_to_solution() -> int:
	var golden: Dictionary = level_data.get("golden_solution", {})
	if golden.is_empty():
		return 0

	var snap_distance: float = float(level_data.get("win_threshold", {}).get("snap_distance", 0.0))
	if snap_distance <= 0.0:
		return 0

	var golden_light: String = String(golden.get("light_preset", ""))
	if golden_light != "" and golden_light != String(_active_light().get("id", "")):
		return 0

	var snapped: int = 0
	for entry in golden.get("objects", []):
		var state: Dictionary = _find_object_state(String(entry.get("id", "")))
		if state.is_empty():
			continue

		var target_values: Array = entry.get("position", [])
		if target_values.size() < 2:
			continue

		var target_position: Vector2 = Vector2(float(target_values[0]), float(target_values[1]))
		if _desk_distance(state["position"], target_position) > snap_distance:
			continue

		var rotation_gap: float = absf(angle_difference(
			deg_to_rad(float(state["rotation_deg"])),
			deg_to_rad(float(entry.get("rotation_deg", 0.0)))
		))
		if rotation_gap > deg_to_rad(1.0):
			continue

		if state["position"] == target_position:
			continue

		state["position"] = target_position
		snapped += 1

	return snapped


func _find_object_state(object_id: String) -> Dictionary:
	for state in object_states:
		if String(state["data"].get("id", "")) == object_id:
			return state
	return {}


func _desk_distance(a: Vector2, b: Vector2) -> float:
	var delta: Vector2 = a - b
	return Vector2(delta.x * DESK_RECT.size.x, delta.y * DESK_RECT.size.y).length()


func _show_alignment_progress() -> void:
	var metrics: Dictionary = _calculate_match()
	var precision: float = float(metrics["precision"])
	var recall: float = float(metrics["recall"])

	if _passes_threshold(precision, recall):
		result_label.add_theme_color_override("font_color", Color("2F6B4F"))
		if snapped_count > 0:
			result_label.text = "影子吸附到位了，点「检查影子」确认。"
		else:
			result_label.text = "看起来很准了，点「检查影子」确认。"
		return

	var score: float = (precision + recall) * 0.5
	var color: Color = Color("B07D2A") if score >= 0.85 else Color("A64B33")
	result_label.add_theme_color_override("font_color", color)
	result_label.text = "对齐度 %.0f%%    精确率 %.2f / 覆盖率 %.2f" % [score * 100.0, precision, recall]


func _move_object_to(screen_position: Vector2) -> void:
	if dragging_object_index < 0:
		return

	var state: Dictionary = object_states[dragging_object_index]
	var raw_object: Dictionary = state["data"]
	var new_position: Vector2

	if drag_source == "shadow":
		var shadow_normal: Vector2 = _board_normal_from_screen(screen_position)
		new_position = _object_position_from_shadow(shadow_normal, raw_object) + drag_offset
	else:
		new_position = _desk_normal_from_screen(screen_position) + drag_offset

	new_position.x = clampf(new_position.x, 0.08, 0.92)
	new_position.y = clampf(new_position.y, 0.10, 0.90)

	if state["position"] != new_position:
		state["position"] = new_position
		drag_moved = true
		has_won = false
		_update_labels()
		queue_redraw()


func _hit_object(screen_position: Vector2) -> int:
	for index in range(object_states.size() - 1, -1, -1):
		var polygon: PackedVector2Array = _object_display_polygon(object_states[index])
		if polygon.size() >= 3 and Geometry2D.is_point_in_polygon(screen_position, polygon):
			return index

	var closest_index: int = -1
	var closest_distance: float = 1000000.0

	for index in object_states.size():
		var distance: float = screen_position.distance_to(_object_display_center(object_states[index]))
		if distance < closest_distance:
			closest_distance = distance
			closest_index = index

	if closest_index >= 0 and closest_distance <= 60.0:
		return closest_index

	return -1


func _hit_shadow(screen_position: Vector2) -> int:
	for index in range(object_states.size() - 1, -1, -1):
		var polygon: PackedVector2Array = _project_shadow_polygon(object_states[index])
		if polygon.size() >= 3 and Geometry2D.is_point_in_polygon(screen_position, polygon):
			return index

	return -1


func _on_rotate_pressed(delta_deg: float) -> void:
	if selected_object_index < 0:
		return

	var state: Dictionary = object_states[selected_object_index]
	var raw_object: Dictionary = state["data"]
	if not bool(raw_object.get("rotatable", false)):
		return

	state["rotation_deg"] = fposmod(float(state["rotation_deg"]) + delta_deg, 360.0)
	steps += 1
	has_won = false
	snapped_count = 0
	_update_labels()
	queue_redraw()
	_show_alignment_progress()


func _on_light_pressed() -> void:
	var presets: Array = level_data.get("light_presets", [])
	if presets.size() < 2:
		return

	active_light_index = (active_light_index + 1) % presets.size()

	if bool(level_data.get("light_moves_count", true)):
		steps += 1

	has_won = false
	snapped_count = 0
	_update_labels()
	queue_redraw()
	_show_alignment_progress()


func _on_reset_pressed() -> void:
	_reset_level()


func _on_check_pressed() -> void:
	var metrics: Dictionary = _calculate_match()
	var precision: float = float(metrics["precision"])
	var recall: float = float(metrics["recall"])
	var f1: float = float(metrics["f1"])
	var stars: int = _calculate_stars(precision, recall)

	if stars > 0:
		has_won = true
		var par_moves: int = int(level_data.get("par_moves", 0))
		result_label.add_theme_color_override("font_color", Color("2F6B4F"))
		result_label.text = "通过！%s  步数 %d / 建议 %d   精确率 %.2f / 覆盖率 %.2f" % [
			_stars_text(stars), steps, par_moves, precision, recall
		]
	else:
		result_label.add_theme_color_override("font_color", Color("A64B33"))
		result_label.text = "还不匹配。  精确率 %.2f / 覆盖率 %.2f / F1 %.2f" % [precision, recall, f1]

	_update_labels()
	queue_redraw()


func _calculate_stars(precision: float, recall: float) -> int:
	if not _passes_threshold(precision, recall):
		return 0

	var par_moves: int = int(level_data.get("par_moves", 0))

	if precision >= 0.97 and recall >= 0.97 and steps <= par_moves:
		return 3
	if precision >= 0.94 and recall >= 0.95 and steps <= par_moves + 2:
		return 2
	return 1


func _stars_text(star_count: int) -> String:
	var text: String = ""
	for index in 3:
		text += "★" if index < star_count else "☆"
	return text


func _reset_level() -> void:
	for state in object_states:
		state["position"] = state["initial_position"]
		state["rotation_deg"] = state["initial_rotation_deg"]

	active_light_index = _default_light_index()
	selected_object_index = -1
	dragging_object_index = -1
	drag_source = "desk"
	drag_offset = Vector2.ZERO
	drag_moved = false
	snapped_count = 0
	steps = 0
	has_won = false

	result_label.add_theme_color_override("font_color", Color("5A4632"))
	result_label.text = "调整物件后，点击「检查影子」。"

	_update_labels()
	_update_action_buttons()
	queue_redraw()


func _calculate_match() -> Dictionary:
	var shadow_polygons: Array = []
	for state in object_states:
		var polygon: PackedVector2Array = _project_shadow_polygon(state)
		if polygon.size() >= 3:
			shadow_polygons.append(polygon)

	var resolution: int = int(level_data.get("board", {}).get("sample_resolution", 128))
	resolution = maxi(32, mini(resolution, 256))

	var threshold: Dictionary = level_data.get("win_threshold", {})
	var edge_tolerance: float = maxf(0.0, float(threshold.get("edge_tolerance", 0.0)))

	var target_expanded: Array = target_shapes
	var shadow_expanded: Array = shadow_polygons
	if edge_tolerance > 0.0:
		target_expanded = _expand_polygons(target_shapes, edge_tolerance)
		shadow_expanded = _expand_polygons(shadow_polygons, edge_tolerance)

	var target_count: int = 0
	var shadow_count: int = 0
	var precision_hits: int = 0
	var recall_hits: int = 0

	for y_index in range(resolution):
		for x_index in range(resolution):
			var sample_point: Vector2 = Vector2(
				BOARD_RECT.position.x + (float(x_index) + 0.5) * BOARD_RECT.size.x / float(resolution),
				BOARD_RECT.position.y + (float(y_index) + 0.5) * BOARD_RECT.size.y / float(resolution)
			)

			var in_target: bool = _point_in_polygons(sample_point, target_shapes)
			var in_shadow: bool = _point_in_polygons(sample_point, shadow_polygons)

			if in_target:
				target_count += 1
			if in_shadow:
				shadow_count += 1

			if in_shadow and _point_in_polygons(sample_point, target_expanded):
				precision_hits += 1
			if in_target and _point_in_polygons(sample_point, shadow_expanded):
				recall_hits += 1

	var precision: float = 0.0
	if shadow_count > 0:
		precision = float(precision_hits) / float(shadow_count)

	var recall: float = 0.0
	if target_count > 0:
		recall = float(recall_hits) / float(target_count)

	var f1: float = 0.0
	if precision + recall > 0.0:
		f1 = 2.0 * precision * recall / (precision + recall)

	return {
		"target_count": target_count,
		"shadow_count": shadow_count,
		"precision_hits": precision_hits,
		"recall_hits": recall_hits,
		"precision": precision,
		"recall": recall,
		"f1": f1
	}


func _passes_threshold(precision: float, recall: float) -> bool:
	var threshold: Dictionary = level_data.get("win_threshold", {})
	var required_precision: float = float(threshold.get("precision", 0.90))
	var required_recall: float = float(threshold.get("recall", 0.92))
	return precision >= required_precision and recall >= required_recall


func _point_in_polygons(point: Vector2, polygons: Array) -> bool:
	for polygon in polygons:
		if polygon.size() >= 3 and Geometry2D.is_point_in_polygon(point, polygon):
			return true
	return false


func _expand_polygons(polygons: Array, delta: float) -> Array:
	var result: Array = []
	for polygon in polygons:
		if polygon.size() < 3:
			continue
		for expanded in Geometry2D.offset_polygon(polygon, delta):
			if expanded.size() >= 3:
				result.append(expanded)
	return result


func _project_shadow_polygon(state: Dictionary) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var raw_object: Dictionary = state["data"]
	var raw_shape: Array = raw_object.get("shape", [])
	var light: Dictionary = _active_light()

	if light.is_empty() or raw_shape.size() < 3:
		return result

	var light_values: Array = light.get("position", [0.5, 0.2])
	var light_height: float = float(light.get("height", 3.0))
	var object_height: float = float(raw_object.get("height", 0.5))
	var denominator: float = light_height - object_height

	if denominator <= 0.02:
		return result

	var projection_scale: float = light_height / denominator
	var light_normal: Vector2 = Vector2(float(light_values[0]), float(light_values[1]))
	var rotation_radians: float = deg_to_rad(float(state["rotation_deg"]))

	for raw_point in raw_shape:
		var local_point: Vector2 = Vector2(float(raw_point[0]), float(raw_point[1]))
		var scene_normal: Vector2 = state["position"] + local_point.rotated(rotation_radians)
		var projected_normal: Vector2 = light_normal + projection_scale * (scene_normal - light_normal)
		result.append(_board_to_pixel(projected_normal))

	return result


func _object_display_polygon(state: Dictionary) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var raw_shape: Array = state["data"].get("shape", [])
	var rotation_radians: float = deg_to_rad(float(state["rotation_deg"]))
	var center: Vector2 = _object_display_center(state)

	for raw_point in raw_shape:
		var local_point: Vector2 = Vector2(float(raw_point[0]), float(raw_point[1]))
		result.append(center + local_point.rotated(rotation_radians) * OBJECT_VISUAL_SCALE)

	return result


func _object_display_center(state: Dictionary) -> Vector2:
	var normal: Vector2 = state["position"]
	return DESK_RECT.position + Vector2(normal.x * DESK_RECT.size.x, normal.y * DESK_RECT.size.y)


func _board_to_pixel(normal_position: Vector2) -> Vector2:
	return BOARD_RECT.position + Vector2(normal_position.x * BOARD_RECT.size.x, normal_position.y * BOARD_RECT.size.y)


func _to_pixel_polygon(raw_polygon: Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for raw_point in raw_polygon:
		if raw_point.size() >= 2:
			result.append(_board_to_pixel(Vector2(float(raw_point[0]), float(raw_point[1]))))
	return result


func _desk_normal_from_screen(screen_position: Vector2) -> Vector2:
	return Vector2(
		(screen_position.x - DESK_RECT.position.x) / DESK_RECT.size.x,
		(screen_position.y - DESK_RECT.position.y) / DESK_RECT.size.y
	)


func _board_normal_from_screen(screen_position: Vector2) -> Vector2:
	return Vector2(
		(screen_position.x - BOARD_RECT.position.x) / BOARD_RECT.size.x,
		(screen_position.y - BOARD_RECT.position.y) / BOARD_RECT.size.y
	)


func _object_position_from_shadow(shadow_normal: Vector2, raw_object: Dictionary) -> Vector2:
	var light: Dictionary = _active_light()
	if light.is_empty():
		return shadow_normal

	var light_values: Array = light.get("position", [0.5, 0.2])
	var light_height: float = float(light.get("height", 3.0))
	var object_height: float = float(raw_object.get("height", 0.5))
	var denominator: float = light_height - object_height

	if denominator <= 0.02:
		return shadow_normal

	var projection_scale: float = light_height / denominator
	var light_normal: Vector2 = Vector2(float(light_values[0]), float(light_values[1]))
	return light_normal + (shadow_normal - light_normal) / projection_scale


func _active_light() -> Dictionary:
	var presets: Array = level_data.get("light_presets", [])
	if presets.is_empty():
		return {}

	if active_light_index < 0 or active_light_index >= presets.size():
		active_light_index = 0

	return presets[active_light_index]


func _default_light_index() -> int:
	var presets: Array = level_data.get("light_presets", [])
	var active_id: String = String(level_data.get("active_light_preset", ""))

	for index in presets.size():
		if String(presets[index].get("id", "")) == active_id:
			return index

	return 0


func _update_labels() -> void:
	var title: String = String(level_data.get("level_id", "L01"))
	var level_title: String = String(level_data.get("title", "影子关卡"))
	var description: String = String(level_data.get("description", ""))
	var hints: Array = level_data.get("hints", [])
	var par_moves: int = int(level_data.get("par_moves", 0))

	header_label.text = "%s · %s" % [title, level_title]
	description_label.text = description

	var drag_state: String = ""
	if dragging_object_index >= 0:
		drag_state = "    （正在拖动影子）" if drag_source == "shadow" else "    （正在拖动物件）"
	elif selected_object_index >= 0 and selected_object_index < object_states.size():
		var selected_object: Dictionary = object_states[selected_object_index]["data"]
		if not bool(selected_object.get("movable", false)):
			drag_state = "    （这块是固定的，动不了）"
	status_label.text = "步数：%d    建议步数：%d%s" % [steps, par_moves, drag_state]

	if hints.is_empty():
		hint_label.text = "提示：观察目标轮廓的方向和位置。"
	else:
		hint_label.text = "提示：" + String(hints[0])


func _update_action_buttons() -> void:
	var can_rotate: bool = false
	if selected_object_index >= 0 and selected_object_index < object_states.size():
		var raw_object: Dictionary = object_states[selected_object_index]["data"]
		can_rotate = bool(raw_object.get("rotatable", false))

	rotate_ccw_button.visible = can_rotate
	rotate_cw_button.visible = can_rotate
	light_button.visible = level_data.get("light_presets", []).size() > 1
	_layout_action_buttons()


func _layout_action_buttons() -> void:
	var cursor: float = 24.0

	if rotate_ccw_button.visible:
		rotate_ccw_button.position.x = cursor
		cursor += rotate_ccw_button.size.x + 8.0
	if rotate_cw_button.visible:
		rotate_cw_button.position.x = cursor
		cursor += rotate_cw_button.size.x + 8.0
	if light_button.visible:
		light_button.position.x = cursor
		cursor += light_button.size.x + 8.0

	reset_button.position.x = cursor
	cursor += reset_button.size.x + 8.0

	check_button.position.x = cursor
	check_button.size.x = maxf(140.0, DESIGN_WIDTH - 24.0 - cursor)
