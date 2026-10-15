extends Node
## Reads / writes user://meta_save.json and user://run_save.json. Versioned payloads with a
## migration hook per file. MetaState and GameState build the payloads; this node only does I/O.

const Db = preload("res://core/Db.gd")
const META_PATH: String = "user://meta_save.json"
const RUN_PATH: String = "user://run_save.json"
const KIND_META: String = "meta"
const KIND_RUN: String = "run"


func has_meta_save() -> bool:
	return FileAccess.file_exists(META_PATH)


func has_run_save() -> bool:
	return FileAccess.file_exists(RUN_PATH)


func load_meta() -> Dictionary:
	return _read(META_PATH, KIND_META)


func load_run() -> Dictionary:
	return _read(RUN_PATH, KIND_RUN)


func write_meta(data: Dictionary) -> bool:
	return _write(META_PATH, data, KIND_META)


func write_run(data: Dictionary) -> bool:
	return _write(RUN_PATH, data, KIND_RUN)


func delete_run() -> void:
	_delete(RUN_PATH)


func delete_all() -> void:
	_delete(RUN_PATH)
	_delete(META_PATH)


func _read(path: String, kind: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("SaveManager: corrupt %s save at %s, ignoring it" % [kind, path])
		return {}
	return _migrate(parsed, kind)


func _write(path: String, data: Dictionary, kind: String) -> bool:
	data["version"] = Db.cfg_i("save_version")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot write %s (error %d)" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	Signals.game_saved.emit(kind)
	return true


func _delete(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _migrate(data: Dictionary, kind: String) -> Dictionary:
	var version: int = int(Db.num(data.get("version", 0)))
	var target: int = Db.cfg_i("save_version")
	if version > target:
		push_error("SaveManager: %s save version %d is newer than game version %d" % [kind, version, target])
	while version < target:
		data = _migrate_meta_step(data, version) if kind == KIND_META else _migrate_run_step(data, version)
		version += 1
	data["version"] = target
	return data


## Upgrades a meta payload from `from_version` to from_version + 1. Add a case per change.
func _migrate_meta_step(data: Dictionary, from_version: int) -> Dictionary:
	match from_version:
		0:
			if not data.has("stats"):
				data["stats"] = {}
	return data


## Upgrades a run payload from `from_version` to from_version + 1. Add a case per change.
func _migrate_run_step(data: Dictionary, from_version: int) -> Dictionary:
	match from_version:
		0:
			if not data.has("flags"):
				data["flags"] = {}
	return data
