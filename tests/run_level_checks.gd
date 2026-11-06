extends SceneTree

## 关卡黄金解回归校验。
## 用法：godot --path . --script res://tests/run_level_checks.gd
## 校验每关 JSON 中的 golden_solution 能满足 win_threshold。

var pending: Array[String] = []
var results: Array[Dictionary] = []


func _initialize() -> void:
	var dir: DirAccess = DirAccess.open("res://data/levels")
	if dir == null:
		push_error("找不到关卡目录 res://data/levels")
		quit(1)
		return

	for file_name in dir.get_files():
		if file_name.ends_with(".json"):
			pending.append("res://data/levels/" + file_name)

	pending.sort()
	print("发现 %d 个关卡文件" % pending.size())


func _process(_delta: float) -> bool:
	if pending.is_empty():
		_report()
		return true

	var path: String = pending.pop_front()
	var level: Node = (load("res://scenes/Level.tscn") as PackedScene).instantiate()
	level.level_path = path
	root.add_child(level)

	results.append(_check_level(level, path))
	level.queue_free()
	return false


func _check_level(level: Node, path: String) -> Dictionary:
	var level_id: String = String(level.level_data.get("level_id", path))
	var golden: Dictionary = level.level_data.get("golden_solution", {})

	if golden.is_empty():
		return {"id": level_id, "status": "缺少 golden_solution"}

	var golden_light: String = String(golden.get("light_preset", ""))
	if golden_light != "":
		for index in level.level_data.get("light_presets", []).size():
			if String(level.level_data["light_presets"][index].get("id", "")) == golden_light:
				level.active_light_index = index
				break

	for entry in golden.get("objects", []):
		var target_id: String = String(entry.get("id", ""))
		for state in level.object_states:
			if String(state["data"].get("id", "")) != target_id:
				continue
			var pos_values: Array = entry.get("position", [0.5, 0.5])
			state["position"] = Vector2(float(pos_values[0]), float(pos_values[1]))
			state["rotation_deg"] = float(entry.get("rotation_deg", 0.0))
			break

	var metrics: Dictionary = level._calculate_match()
	var precision: float = float(metrics["precision"])
	var recall: float = float(metrics["recall"])
	var passed: bool = level._passes_threshold(precision, recall)

	return {
		"id": level_id,
		"precision": precision,
		"recall": recall,
		"f1": float(metrics["f1"]),
		"passed": passed,
		"status": "通过" if passed else "未达阈值"
	}


func _report() -> void:
	print("")
	print("关卡        精确率   覆盖率   F1      结果")
	print("------------------------------------------------")
	var failed: int = 0
	for row in results:
		if not row.has("precision"):
			print("%-10s  --       --       --      %s" % [row["id"], row["status"]])
			failed += 1
			continue
		print("%-10s  %.3f    %.3f    %.3f   %s" % [
			row["id"], row["precision"], row["recall"], row["f1"], row["status"]
		])
		if not bool(row["passed"]):
			failed += 1

	print("------------------------------------------------")
	print("失败关卡数：%d / %d" % [failed, results.size()])
	quit(0 if failed == 0 else 1)
