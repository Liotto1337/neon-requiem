extends Node
## Rebindable input actions. Defaults live in config.json "input" (also pre-registered in
## project.godot); player overrides are stored in user://input_map.json and applied on boot.
## Codes: "key:W" (physical key, layout independent) and "mouse:1" (button index).

const Db = preload("res://core/Db.gd")
const OVERRIDES_PATH: String = "user://input_map.json"
const KEY_PREFIX: String = "key:"
const MOUSE_PREFIX: String = "mouse:"
const MOUSE_LABELS: Dictionary = {1: "ЛКМ", 2: "ПКМ", 3: "СКМ"}

var _overrides: Dictionary = {}


func _ready() -> void:
	_ensure_defaults()
	_load_overrides()


func ability_action(slot: int) -> String:
	var actions: Array = Db.cfg_a("slots.ability_actions")
	return str(actions[slot]) if slot >= 0 and slot < actions.size() else ""


func item_action(slot: int) -> String:
	var actions: Array = Db.cfg_a("slots.item_actions")
	return str(actions[slot]) if slot >= 0 and slot < actions.size() else ""


## Replaces the bindings of `action` with `code` and remembers the override.
func rebind(action: String, code: String) -> void:
	var event: InputEvent = parse(code)
	if event == null or not InputMap.has_action(action):
		push_error("InputMapHelper: cannot bind '%s' to '%s'" % [action, code])
		return
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	_overrides[action] = code
	_save_overrides()


func reset_to_defaults() -> void:
	_overrides = {}
	_save_overrides()
	for action: Variant in Db.cfg_d("input").keys():
		_apply_codes(str(action), Db.cfg_d("input")[action])


## Short label for the first binding of an action: "Z", "ЛКМ", "1".
func label(action: String) -> String:
	if not InputMap.has_action(action):
		return ""
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key: InputEventKey = event
			var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			return OS.get_keycode_string(code)
		if event is InputEventMouseButton:
			return str(MOUSE_LABELS.get(int((event as InputEventMouseButton).button_index), "M"))
	return ""


func parse(code: String) -> InputEvent:
	if code.begins_with(KEY_PREFIX):
		var keycode: Key = OS.find_keycode_from_string(code.substr(KEY_PREFIX.length()))
		if keycode == KEY_NONE:
			return null
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = keycode
		return key
	if code.begins_with(MOUSE_PREFIX):
		var mouse: InputEventMouseButton = InputEventMouseButton.new()
		mouse.button_index = int(code.substr(MOUSE_PREFIX.length())) as MouseButton
		return mouse
	return null


func _ensure_defaults() -> void:
	var defaults: Dictionary = Db.cfg_d("input")
	for action: Variant in defaults.keys():
		var action_name: String = str(action)
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			_apply_codes(action_name, defaults[action])


func _apply_codes(action: String, codes: Variant) -> void:
	if not InputMap.has_action(action) or not codes is Array:
		return
	InputMap.action_erase_events(action)
	for code: Variant in codes:
		var event: InputEvent = parse(str(code))
		if event != null:
			InputMap.action_add_event(action, event)


func _load_overrides() -> void:
	if not FileAccess.file_exists(OVERRIDES_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(OVERRIDES_PATH))
	if not parsed is Dictionary:
		push_error("InputMapHelper: corrupt %s" % OVERRIDES_PATH)
		return
	_overrides = parsed
	for action: Variant in _overrides.keys():
		_apply_codes(str(action), [_overrides[action]])


func _save_overrides() -> void:
	var file: FileAccess = FileAccess.open(OVERRIDES_PATH, FileAccess.WRITE)
	if file == null:
		push_error("InputMapHelper: cannot write %s" % OVERRIDES_PATH)
		return
	file.store_string(JSON.stringify(_overrides, "\t"))
	file.close()
