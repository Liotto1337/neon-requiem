extends Node2D
## Summoner drone: orbits its owner, auto-fires at the nearest enemy (or at the focus point
## the owner marked with LMB). R recalls drones to the owner with a short fire-rate haste;
## RMB overclock multiplies the fire rate. Stats come from the deploy_drone ability level.

const Db = preload("res://core/Db.gd")
const Neon = preload("res://core/Neon.gd")
const ShotFactory = preload("res://scenes/entities/components/ShotFactory.gd")
const MSEC: float = 1000.0
const BODY_SIZE: float = 16.0
const RECALL_RING_SCALE: float = 2.0

var owner_node: Node2D = null
var stats: Dictionary = {}
var slot_index: int = 0
var slot_count: int = 1
var _next_fire_msec: int = 0
var _haste_until_msec: int = 0
var _haste_mult: float = 1.0
var _overclock_until_msec: int = 0
var _overclock_mult: float = 1.0
var _focus_point: Vector2 = Vector2.ZERO
var _focus_until_msec: int = 0
var _orbit_angle: float = 0.0

@onready var _visual: Node2D = $Visual


func setup(owner_player: Node2D, drone_stats: Dictionary) -> void:
	owner_node = owner_player
	stats = drone_stats


func set_slot(index: int, count: int) -> void:
	slot_index = index
	slot_count = maxi(1, count)


func _ready() -> void:
	Neon.build_body(_visual, "triangle", BODY_SIZE, "lime")
	Signals.drones_recall_requested.connect(_on_recall)
	Signals.drones_command.connect(_on_command)
	if owner_node != null and is_instance_valid(owner_node):
		global_position = owner_node.global_position


func _physics_process(delta: float) -> void:
	if owner_node == null or not is_instance_valid(owner_node):
		return
	_orbit_angle += Db.f(stats, "orbit_speed") * delta
	var phase: float = TAU * float(slot_index) / float(slot_count) + _orbit_angle
	var spot: Vector2 = owner_node.global_position + Vector2.RIGHT.rotated(phase) * Db.f(stats, "follow_radius")
	global_position = global_position.lerp(spot, clampf(Db.f(stats, "follow_lerp") * delta, 0.0, 1.0))
	var now: int = TimeService.run_msec()
	if now >= _next_fire_msec:
		_fire(now)


func _fire_interval(now: int) -> float:
	var mult: float = GameState.stat("attack_speed_mult", 1.0)
	if now < _haste_until_msec:
		mult *= _haste_mult
	if now < _overclock_until_msec:
		mult *= _overclock_mult
	return Db.f(stats, "fire_cd") / maxf(0.01, mult)


func _fire(now: int) -> void:
	var center: Vector2 = _focus_point if now < _focus_until_msec else global_position
	var enemy: Node2D = ShotFactory.nearest_enemy(get_world_2d(), center, Db.f(stats, "range"), [])
	if enemy == null:
		_next_fire_msec = now + int(_fire_interval(now) * MSEC * 0.5)
		return
	_next_fire_msec = now + int(_fire_interval(now) * MSEC)
	var laser: bool = bool(stats.get("laser", false))
	var params: Dictionary = {
		"speed": Db.f(stats, "speed"), "radius": Db.f(stats, "radius"), "lifetime": Db.f(stats, "lifetime"),
		"pierce": Db.i(stats, "pierce"), "color": "lime", "shape": "bolt" if laser else "orb", "source": "drone",
	}
	var damage: float = Db.f(stats, "damage") * GameState.stat("drone_damage_mult", 1.0)
	Signals.projectile_requested.emit(ShotFactory.player_shot(global_position, enemy.global_position - global_position, damage, params))


func _on_recall(haste_sec: float, haste_mult: float) -> void:
	if owner_node == null or not is_instance_valid(owner_node):
		return
	global_position = owner_node.global_position
	_haste_until_msec = TimeService.deadline(haste_sec)
	_haste_mult = haste_mult
	Signals.ring_fx_requested.emit(global_position, BODY_SIZE * RECALL_RING_SCALE, Db.glow("lime"), Db.cfg_f("fx.ring_sec"))


func _on_command(command: String, data: Dictionary) -> void:
	match command:
		"focus":
			_focus_point = data.get("position", global_position)
			_focus_until_msec = TimeService.deadline(Db.f(data, "duration"))
		"overclock":
			_overclock_until_msec = TimeService.deadline(Db.f(data, "duration"))
			_overclock_mult = Db.f(data, "mult", 1.0)
