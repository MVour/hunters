extends Node
## Dev tool: loads every script, scene and resource under res:// and reports
## anything that fails to load or compile, then checks the translations
## (i18n/strings.csv). Exit code 1 on failure.
## Run headless:  Godot_console.exe --headless --path . res://tools/check_project.tscn

const STRINGS := "res://i18n/strings.csv"

var failures := 0
var count := 0
var _scripts: Array[String] = []   # paths of every .gd (for the key scan)
var _scenes: Array[String] = []


func _ready() -> void:
	_walk("res://")
	print("CHECKED %d files, %d failures" % [count, failures])
	var i18n_failures := _check_strings()
	failures += i18n_failures
	get_tree().quit(1 if failures > 0 else 0)


func _walk(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if not sub.begins_with("."):
			_walk(dir_path.path_join(sub))
	for f in dir.get_files():
		var path := dir_path.path_join(f)
		if f.get_extension() == "gd":
			_scripts.append(path)
		elif f.get_extension() == "tscn":
			_scenes.append(path)
		if f.get_extension() in ["gd", "tscn", "tres"] and not f.begins_with("check_project"):
			_check(path)


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


# --- Translations ---------------------------------------------------------------

## Every key used in code exists with both languages; both languages use the
## same {blanks} and %s placeholders; no key is unused.
func _check_strings() -> int:
	var problems := 0
	var file := FileAccess.open(STRINGS, FileAccess.READ)
	if file == null:
		print("FAIL i18n: can't open ", STRINGS)
		return 1
	var rows := {}
	var header := file.get_csv_line()
	if header != PackedStringArray(["keys", "en", "el"]):
		print("FAIL i18n: header should be keys,en,el")
		problems += 1
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() < 3 or line[0] == "":
			continue
		if rows.has(line[0]):
			print("FAIL i18n: duplicate key ", line[0])
			problems += 1
		rows[line[0]] = [line[1], line[2]]

	for key in rows:
		var en: String = rows[key][0]
		var el: String = rows[key][1]
		if en.strip_edges() == "" or el.strip_edges() == "":
			print("FAIL i18n: %s is missing a language" % key)
			problems += 1
		elif _placeholders(en) != _placeholders(el):
			print("FAIL i18n: %s placeholders differ: en %s / el %s" % [key, _placeholders(en), _placeholders(el)])
			problems += 1

	# Keys used in scripts: Global.text("...") and Msg.make("...").
	var used := {}
	var code_key := RegEx.create_from_string("(?:Global\\.text|Msg\\.make)\\(\\s*\"([^\"]+)\"")
	for path in _scripts:
		if path.contains("/tools/") or path.contains("/legacy/"):
			continue
		var source := FileAccess.get_file_as_string(path)
		for m in code_key.search_all(source):
			used[m.get_string(1)] = path
	# Keys built from data: "species." + id.
	for key in Global.SPECIES:
		used["species." + Global.SPECIES[key].species] = "Global.SPECIES"
	# Scene-file texts are keys too (Godot translates them by itself).
	var scene_text := RegEx.create_from_string("(?m)^(?:text|placeholder_text) = \"([^\"]*)\"")
	for path in _scenes:
		if path.contains("/legacy/") or path.contains("/tools/"):
			continue
		var source := FileAccess.get_file_as_string(path)
		for m in scene_text.search_all(source):
			if rows.has(m.get_string(1)):
				used[m.get_string(1)] = path
		for key in rows:  # also e.g. animation tracks that set a text
			if source.contains("\"%s\"" % key):
				used[key] = path

	for key in used:
		if not rows.has(key):
			print("FAIL i18n: %s used in %s but not in strings.csv" % [key, used[key]])
			problems += 1
	for key in rows:
		if not used.has(key):
			print("FAIL i18n: %s is in strings.csv but never used" % key)
			problems += 1
	print("CHECKED %d translation keys, %d problems" % [rows.size(), problems])
	return problems


## The placeholders in a text, sorted: {name} blanks and %s/%d.
func _placeholders(s: String) -> Array:
	var found := []
	var re := RegEx.create_from_string("\\{[a-z0-9_]+\\}|%[sd]")
	for m in re.search_all(s):
		found.append(m.get_string())
	found.sort()
	return found
