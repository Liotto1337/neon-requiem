extends Node
## Audio stub: mute toggles per bus only, remembered in user://settings.cfg.
## Buses listed in config.json "audio.buses". No sounds ship with the MVP.

const Db = preload("res://core/Db.gd")
const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "audio"

var _muted: Dictionary = {}


func _ready() -> void:
	Signals.mute_toggle_requested.connect(toggle)
	var settings: ConfigFile = ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		for bus: Variant in Db.cfg_a("audio.buses"):
			_muted[str(bus)] = bool(settings.get_value(SECTION, str(bus), false))
	for bus: Variant in _muted.keys():
		_apply(str(bus))


## Re-broadcasts every bus state (UI calls this once after connecting).
func emit_all() -> void:
	for bus: Variant in Db.cfg_a("audio.buses"):
		Signals.audio_mute_changed.emit(str(bus), is_muted(str(bus)))


func is_muted(bus_name: String) -> bool:
	return bool(_muted.get(bus_name, false))


func toggle(bus_name: String) -> void:
	set_muted(bus_name, not is_muted(bus_name))


func set_muted(bus_name: String, muted: bool) -> void:
	_muted[bus_name] = muted
	_apply(bus_name)
	_save()
	Signals.audio_mute_changed.emit(bus_name, muted)


func _apply(bus_name: String) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_mute(index, is_muted(bus_name))


func _save() -> void:
	var settings: ConfigFile = ConfigFile.new()
	for bus: Variant in _muted.keys():
		settings.set_value(SECTION, str(bus), _muted[bus])
	if settings.save(SETTINGS_PATH) != OK:
		push_error("AudioBus: cannot write %s" % SETTINGS_PATH)
