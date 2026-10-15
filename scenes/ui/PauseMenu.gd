extends "res://scenes/ui/components/ModalBase.gd"
## ESC pause menu: resume, sound toggle (AudioBus stub), save and leave to the hub.

const MODAL_ID: String = "pause"
const AUDIO_BUS: String = "Master"

@onready var _resume: Button = $Center/Panel/Rows/Resume
@onready var _sound: Button = $Center/Panel/Rows/Sound
@onready var _to_hub: Button = $Center/Panel/Rows/ToHub


func _ready() -> void:
	modal_id = MODAL_ID
	visible = false
	Signals.pause_menu_requested.connect(_on_requested)
	Signals.audio_mute_changed.connect(_on_mute_changed)
	_resume.pressed.connect(close_modal)
	_sound.pressed.connect(func() -> void: Signals.mute_toggle_requested.emit(AUDIO_BUS))
	_to_hub.pressed.connect(_on_to_hub)
	AudioBus.emit_all()


func _on_requested(open: bool) -> void:
	if open:
		open_modal()
	else:
		close_modal()


func _on_mute_changed(bus_name: String, muted: bool) -> void:
	if bus_name == AUDIO_BUS:
		_sound.text = "Звук: выкл" if muted else "Звук: вкл"


func _on_to_hub() -> void:
	close_modal()
	Signals.return_to_hub_requested.emit()
