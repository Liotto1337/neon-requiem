extends Node2D
## Root of a run: loads the current location into the world, places the player, drives the
## SpawnDirector schedule, pauses for modals, fades between locations (boss -> next
## location, victory -> loop) and returns to the hub when the run ends or is suspended.

const Db = preload("res://core/Db.gd")
const MODAL_PAUSE: String = "pause"
const MODAL_INVENTORY: String = "inventory"
const KIND_MINIBOSS: String = "miniboss"
const KIND_BOSS: String = "boss"
const SUMMONER_ABILITY: String = "deploy_drone"

var _location: Node2D = null
var _location_cfg: Dictionary = {}
var _open_modals: Dictionary = {}
var _last_spawn_t: float = 0.0
var _transitioning: bool = false
var _leaving: bool = false

@onready var _environment: WorldEnvironment = $WorldEnvironment
@onready var _slot: Node2D = $World/LocationSlot
@onready var _player: CharacterBody2D = $World/Player
@onready var _camera: Camera2D = $Camera
@onready var _spawner: Node = $Spawner
@onready var _fade: ColorRect = $FadeLayer/Fade


func _ready() -> void:
	_configure_glow()
	if not GameState.run_active:
		_go_to_hub.call_deferred()
		return
	_connect_signals()
	_spawner.call("setup", {
		"enemies": $World/Enemies, "projectiles": $World/Projectiles, "pickups": $World/Pickups,
		"drones": $World/Drones, "fx": $World/Fx,
	}, _player)
	_player.call("setup", GameState.hero_id)
	_camera.set("target", _player)
	_load_location(GameState.current_location_id())
	GameState.begin_session()
	_spawn_start_drones()
	_fade.color.a = 1.0
	create_tween().tween_property(_fade, "color:a", 0.0, Db.cfg_f("run.transition_fade_sec"))


func _connect_signals() -> void:
	Signals.modal_visibility_changed.connect(_on_modal_visibility)
	Signals.boss_defeated.connect(_on_boss_defeated)
	Signals.loop_started.connect(_on_loop_started)
	Signals.run_ended.connect(_on_run_ended)
	Signals.player_died.connect(_on_player_died)


func _configure_glow() -> void:
	var env: Environment = _environment.environment
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_hdr_threshold = Db.cfg_f("glow.threshold")
	env.glow_intensity = Db.cfg_f("glow.intensity")
	env.glow_strength = Db.cfg_f("glow.strength")
	env.glow_bloom = Db.cfg_f("glow.bloom")
	env.glow_blend_mode = Db.cfg_i("glow.blend_mode") as Environment.GlowBlendMode


func _load_location(location_id: String) -> void:
	if _location != null:
		_slot.remove_child(_location)
		_location.queue_free()
	_location_cfg = Db.entry("locations", "locations", location_id)
	var scene: PackedScene = load(Db.s(_location_cfg, "scene"))
	_location = scene.instantiate()
	_slot.add_child(_location)
	_spawner.call("set_location", _location)
	var bounds: Rect2 = _location.call("bounds")
	var margin: float = Db.cfg_f("run.bounds_margin_px")
	_player.call("set_bounds", bounds.grow(-margin))
	_player.global_position = _location.call("player_spawn")
	_location.call("setup", _player)
	_camera.call("set_bounds", bounds)
	_camera.call("snap_to_target")
	_last_spawn_t = GameState.location_elapsed_sec


func _spawn_start_drones() -> void:
	var count: int = Db.i(GameState.hero(), "start_drones")
	if count <= 0:
		return
	var level: int = 1
	for entry: Variant in GameState.abilities:
		if Db.s(entry, "id") == SUMMONER_ABILITY:
			level = Db.i(entry, "level", 1)
	var stats: Dictionary = AbilitySystem.level_stats(SUMMONER_ABILITY, level)
	for _index: int in count:
		Signals.drone_requested.emit(stats)


func _spawn_seed() -> int:
	return GameState.seed_value + GameState.location_index * Db.cfg_i("run.seed_salt_location") + GameState.loop_count * Db.cfg_i("run.seed_salt_loop")


func _physics_process(_delta: float) -> void:
	if get_tree().paused or _transitioning or _leaving or not GameState.run_active:
		return
	var t: float = TimeService.location_elapsed_sec()
	if t > _last_spawn_t:
		var events: Array = SpawnDirector.events_between(_location_cfg, Db.table("enemies"), Db.table("difficulty"), GameState.difficulty_tier, _last_spawn_t, t, _spawn_seed())
		_last_spawn_t = t
		_spawner.call("handle_events", events)
	_spawn_overdue_bosses(t)


## Re-spawns a miniboss / boss whose time has passed but who is neither alive nor beaten
## (resumed saves, or an event dropped while the world was busy).
func _spawn_overdue_bosses(t: float) -> void:
	var pairs: Array = [[KIND_MINIBOSS, "miniboss_at_sec", "miniboss_done", "miniboss"], [KIND_BOSS, "boss_at_sec", "boss_done", "boss"]]
	for pair: Array in pairs:
		var due: bool = t >= Db.f(_location_cfg, str(pair[1]))
		if due and not bool(GameState.flags.get(str(pair[2]), false)) and not bool(_spawner.call("boss_alive", str(pair[0]))):
			_spawner.call("spawn_boss", Db.s(_location_cfg, str(pair[3])))


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or _transitioning:
		return
	if event.is_action_pressed("pause_esc"):
		_on_escape()
	elif event.is_action_pressed("inventory_tab"):
		_toggle_inventory()
	elif OS.is_debug_build():
		_debug_input(event)


func _is_open(modal_id: String) -> bool:
	return bool(_open_modals.get(modal_id, false))


func _other_modal_open(except: Array) -> bool:
	for modal_id: Variant in _open_modals.keys():
		if bool(_open_modals[modal_id]) and not except.has(modal_id):
			return true
	return false


func _on_escape() -> void:
	if _is_open(MODAL_INVENTORY):
		Signals.inventory_toggle_requested.emit(false)
	elif _is_open(MODAL_PAUSE):
		Signals.pause_menu_requested.emit(false)
	elif not _other_modal_open([]):
		Signals.pause_menu_requested.emit(true)


func _toggle_inventory() -> void:
	if _other_modal_open([MODAL_INVENTORY]):
		return
	Signals.inventory_toggle_requested.emit(not _is_open(MODAL_INVENTORY))


func _debug_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_skip"):
		TimeService.skip(Db.cfg_f("debug.skip_sec"))
	elif event.is_action_pressed("debug_xp"):
		GameState.add_currency(Db.cfg_f("debug.currency_amount"))
		GameState.add_xp(Db.cfg_f("debug.xp_amount"))


func _on_modal_visibility(modal_id: String, open: bool) -> void:
	_open_modals[modal_id] = open
	var paused: bool = _other_modal_open([])
	get_tree().paused = paused
	TimeService.set_paused(paused)


func _on_player_died(_summary: Dictionary) -> void:
	_player.call("set_input_enabled", false)


func _on_boss_defeated(_boss_id: String, kind: String, is_final: bool) -> void:
	if kind == KIND_BOSS and not is_final:
		Signals.magnet_requested.emit()
		_transition(Db.cfg_f("run.transition_delay_sec"), true)


func _on_loop_started(_loop_count: int, _multiplier: float) -> void:
	_transition(0.0, false)


## Fade out (after `delay`), swap the location (advancing the chain if asked), fade in.
func _transition(delay: float, advance: bool) -> void:
	if _transitioning:
		return
	_transitioning = true
	var fade: float = Db.cfg_f("run.transition_fade_sec")
	var tween: Tween = create_tween()
	tween.tween_interval(maxf(0.0, delay))
	tween.tween_property(_fade, "color:a", 1.0, fade)
	tween.tween_callback(_swap_location.bind(advance))
	tween.tween_property(_fade, "color:a", 0.0, fade)
	tween.tween_callback(_end_transition)


func _swap_location(advance: bool) -> void:
	if advance:
		GameState.advance_location()
	_spawner.call("clear_world")
	_load_location(GameState.current_location_id())


func _end_transition() -> void:
	_transitioning = false


func is_transitioning() -> bool:
	return _transitioning


func _on_run_ended(_summary: Dictionary) -> void:
	_go_to_hub.call_deferred()


func _go_to_hub() -> void:
	if _leaving:
		return
	_leaving = true
	GameState.end_session()
	get_tree().paused = false
	TimeService.set_paused(false)
	get_tree().change_scene_to_file(Db.cfg_s("scenes.hub"))
