extends Node
## Dev tool: loads every script, scene and resource under res:// and reports
## anything that fails to load or compile. Exit code 1 on failure.
## Run headless:  Godot_console.exe --headless --path . res://tools/check_project.tscn

var failures := 0
var count := 0


func _ready() -> void:
	_walk("res://")
	print("CHECKED %d files, %d failures" % [count, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _walk(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if not sub.begins_with(".") and sub != "tools":
			_walk(dir_path.path_join(sub))
	for f in dir.get_files():
		if f.get_extension() in ["gd", "tscn", "tres"]:
			_check(dir_path.path_join(f))


func _check(path: String) -> void:
	count += 1
	var res = ResourceLoader.load(path)
	if res == null:
		failures += 1
		print("FAIL load: ", path)
	elif res is GDScript and not res.can_instantiate():
		failures += 1
		print("FAIL compile: ", path)
	elif res is PackedScene and not res.can_instantiate():
		failures += 1
		print("FAIL scene: ", path)
