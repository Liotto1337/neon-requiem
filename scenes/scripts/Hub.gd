extends Node2D
## Hub location: the selected hero walks around a neon room (data/hub.json, built by
## tools/build_world.gd) and uses terminals with E — the portal (start / continue a run),
## the skill tree graph, the workshop (signature item tiers), the hero pod and the records
## board. One terminal window at a time; ESC closes it or returns to the main menu.
## Reads meta state from Signals.meta_changed and sends intents back through Signals.

const Db = preload("res://core/Db.gd")
const Sprites = preload("res://core/Sprites.gd")
const Neon = preload("res://core/Neon.gd")
const TERMINAL_SCENE: PackedScene = preload("res://scenes/hub/Terminal.tscn")

var _meta: Dictionary = {}
var _room: Node2D = null
var _terminals: Array[Node2D] = []
var _hero_id: String = ""

@onready var _environment: WorldEnvironment = $WorldEnvironment
@onready var _world: Node2D = $World
@onready var _avatar: CharacterBody2D = $World/Avatar
@onready var _camera: Camera2D = $Camera
@onready var _overlays: Dictionary = {
	"tree": $UI/SkillTreeOverlay, "workshop": $UI/WorkshopOverlay, "heroes": $UI/HeroSelectOverlay,
	"stats": $UI/StatsOverlay, "run": $UI/PortalOverlay,
}
@onready var _credits: Label = $UI/HubHud/Top/Credits
@onready var _hero_label: Label = $UI/HubHud/Top/Hero
@onready var _prompt: Label = $UI/HubHud/Prompt
@onready var _toast: Label = $UI/HubHud/Toast


func _ready() -> void:
	Neon.configure_glow(_environment.environment)
	_load_room()
	Signals.meta_changed.connect(_on_meta)
	Signals.run_started.connect(_on_run_started)
	Signals.toast_requested.connect(_on_toast)
	_toast.text = ""
	MetaState.emit_all()


func _load_room() -> void:
	_room = (load(Db.s(Db.table("hub"), "scene")) as PackedScene).instantiate()
	_world.add_child(_room)
	_world.move_child(_room, 0)
	for layer_name: String in ["Floor", "Walls", "Decor"]:
		(_room.get_node(layer_name) as TileMapLayer).material = Sprites.FX_MATERIAL
	for terminal: Variant in Db.a(Db.table("hub"), "terminals"):
		var node: Node2D = TERMINAL_SCENE.instantiate()
		_world.add_child(node)
		node.global_position = (_room.get_node("Markers/" + Db.s(terminal, "id")) as Node2D).global_position + Vector2(0.0, 30.0)
		node.call("setup", terminal)
		_terminals.append(node)
	_avatar.global_position = (_room.get_node("Markers/Spawn") as Node2D).global_position
	var floor_layer: TileMapLayer = _room.get_node("Floor")
	var used: Rect2i = floor_layer.get_used_rect()
	var tile: Vector2 = Vector2(floor_layer.tile_set.tile_size) * floor_layer.scale
	var margin: float = Db.cfg_f("camera.edge_margin_px")
	_camera.limit_left = int(used.position.x * tile.x - margin)
	_camera.limit_top = int(used.position.y * tile.y - margin)
	_camera.limit_right = int(used.end.x * tile.x + margin)
	_camera.limit_bottom = int(used.end.y * tile.y + margin)
	_camera.global_position = _avatar.global_position


func _on_meta(meta: Dictionary) -> void:
	_meta = meta
	_credits.text = str(Db.i(meta, "currency"))
	var hero_id: String = Db.s(meta, "selected_hero")
	var hero: Dictionary = Db.entry("heroes", "heroes", hero_id)
	_hero_label.text = "%s · %s" % [Db.s(hero, "name"), Db.s(hero, "class_name")]
	if hero_id != _hero_id:
		_hero_id = hero_id
		_avatar.call("setup", hero_id)


func _on_run_started(_summary: Dictionary) -> void:
	get_tree().change_scene_to_file(Db.cfg_s("scenes.run"))


func _on_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tween: Tween = _toast.create_tween()
	tween.tween_interval(Db.cfg_f("ui.toast_sec"))
	tween.tween_property(_toast, "modulate:a", 0.0, Db.cfg_f("ui.toast_sec") * 0.3)


func _process(delta: float) -> void:
	_camera.global_position = _camera.global_position.lerp(_avatar.global_position, 1.0 - exp(-Db.cfg_f("ui.hub_camera_rate") * delta))
	var open: bool = open_overlay() != ""
	_avatar.set("input_enabled", not open)
	var near: Node2D = nearest_terminal()
	for terminal: Node2D in _terminals:
		terminal.call("set_active", terminal == near and not open)
	_prompt.visible = near != null and not open
	if near != null:
		_prompt.text = "%s — %s" % [InputMapHelper.label("interact"), Db.s(near.get("data"), "prompt")]


## Closest terminal the hero can reach, or null.
func nearest_terminal() -> Node2D:
	var best: Node2D = null
	for terminal: Node2D in _terminals:
		if terminal.call("in_reach", _avatar.global_position) and (best == null or terminal.global_position.distance_to(_avatar.global_position) < best.global_position.distance_to(_avatar.global_position)):
			best = terminal
	return best


func open_overlay() -> String:
	for key: Variant in _overlays.keys():
		if (_overlays[key] as Control).visible:
			return str(key)
	return ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_esc"):
		get_viewport().set_input_as_handled()
		if open_overlay() != "":
			_close_overlays()
		else:
			get_tree().change_scene_to_file(Db.cfg_s("scenes.menu"))
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if open_overlay() != "":
			_close_overlays()
		elif nearest_terminal() != null:
			use_terminal(Db.s(nearest_terminal().get("data"), "action"))


## Runs a terminal action: "run" starts (or offers to continue) a run, others open windows.
func use_terminal(action: String) -> void:
	_avatar.call("play", "cast")
	if action == "run" and not bool(_meta.get("has_run_save", false)):
		Signals.run_start_requested.emit(Db.s(_meta, "selected_hero"))
		return
	if _overlays.has(action):
		(_overlays[action] as Control).call("open")


func _close_overlays() -> void:
	for overlay: Variant in _overlays.values():
		(overlay as Control).call("close")
