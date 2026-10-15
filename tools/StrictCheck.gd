extends Node
## Loads every game script with GDScript warnings raised to errors (tools/check.sh writes an
## override.cfg for that). Quits with code 1 when any script fails to compile.

const SKIP_DIRS: Array[String] = [".godot", "tmp"]

var _failed: int = 0


func _ready() -> void:
	var files: Array[String] = []
	_walk("res://", files)
	for path: String in files:
		if path == get_script().resource_path:
			continue
		var script: Script = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if script == null or not script.can_instantiate():
			_failed += 1
			push_error("StrictCheck: %s failed to compile" % path)
	get_tree().quit(1 if _failed > 0 else 0)


func _walk(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		if not SKIP_DIRS.has(sub) and not sub.begins_with("."):
			_walk(dir_path.path_join(sub), out)
	for file: String in dir.get_files():
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))
