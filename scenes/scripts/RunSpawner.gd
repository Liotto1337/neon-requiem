extends Node
## World spawner for the Run scene: turns SpawnDirector events and entity requests from the
## Signals bus into nodes — enemies, elites, bosses, projectiles, pickups, drones and FX.
## Every add is deferred, so requests made inside physics callbacks stay safe.

const Db = preload("res://core/Db.gd")
const Neon = preload("res://core/Neon.gd")
const LIGHTNING_SCRIPT: Script = preload("res://scenes/fx/Lightning.gd")
const ENEMY_SCENE: PackedScene = preload("res://scenes/entities/Enemy.tscn")
const ELITE_SCENE: PackedScene = preload("res://scenes/entities/EliteEnemy.tscn")
const BOSS_SCENE: PackedScene = preload("res://scenes/entities/Boss.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/entities/Projectile.tscn")
const PICKUP_SCENE: PackedScene = preload("res://scenes/entities/Pickup.tscn")
const DRONE_SCENE: PackedScene = preload("res://scenes/entities/Drone.tscn")
const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/fx/DamageNumber.tscn")
const TYPE_ENEMY: String = "enemy"
const FORMATION_RING: String = "ring"
const RETRY_ANGLE_STEP: float = 0.7
const FX_Z: int = 40

var _enemies: Node2D = null
var _projectiles: Node2D = null
var _pickups: Node2D = null
var _drones: Node2D = null
var _fx: Node2D = null
var _player: Node2D = null
var _location: Node2D = null
var _drone_list: Array = []
var _alive_bosses: Dictionary = {}
var _enemy_shots: int = 0
var _numbers: int = 0


func setup(layers: Dictionary, player: Node2D) -> void:
	_enemies = layers["enemies"]
	_projectiles = layers["projectiles"]
	_pickups = layers["pickups"]
	_drones = layers["drones"]
	_fx = layers["fx"]
	_player = player
	Signals.projectile_requested.connect(spawn_projectile)
	Signals.pickup_requested.connect(spawn_pickup)
	Signals.drone_requested.connect(spawn_drone)
	Signals.adds_requested.connect(spawn_adds)
	Signals.beam_fx_requested.connect(spawn_beam)
	Signals.lightning_fx_requested.connect(spawn_lightning)
	Signals.ring_fx_requested.connect(spawn_ring)
	Signals.damage_number_requested.connect(spawn_damage_number)


func set_location(location: Node2D) -> void:
	_location = location


func enemy_count() -> int:
	return _enemies.get_child_count()


func boss_alive(kind: String) -> bool:
	var node: Variant = _alive_bosses.get(kind)
	return is_instance_valid(node) and node is Node and not bool((node as Node).call("is_dead"))


func _scaling() -> Dictionary:
	return WaveDirector.scaling(GameState.difficulty_tier, GameState.difficulty_multiplier, Db.table("difficulty"))


# ---------------------------------------------------------------- spawn events

func handle_events(events: Array) -> void:
	for event: Variant in events:
		match Db.s(event, "type"):
			TYPE_ENEMY:
				_spawn_enemy_event(event)
			"miniboss", "boss":
				spawn_boss(Db.s(event, "boss_id"))


func _spawn_enemy_event(event: Dictionary) -> void:
	var config: Dictionary = Db.entry("enemies", "enemies", Db.s(event, "enemy_id"))
	if config.is_empty():
		return
	var count: int = Db.i(event, "count", 1)
	var cap: int = WaveDirector.max_alive(GameState.difficulty_tier, Db.table("difficulty"))
	var base_angle: float = GameState.rng.randf() * TAU
	var ring: bool = Db.s(event, "formation") == FORMATION_RING
	for index: int in count:
		if enemy_count() >= cap:
			return
		var angle: float = base_angle + (TAU * float(index) / float(count) if ring else 0.0)
		var radius: float = Db.cfg_f("run.spawn_ring_px") + GameState.rng.randf() * Db.cfg_f("run.spawn_ring_jitter_px")
		var mods: Array = WaveDirector.roll_elite_mods(GameState.seed_value, Db.i(event, "salt") * count + index, GameState.difficulty_tier, Db.table("elites"), Db.table("difficulty"))
		spawn_enemy(config, _ring_position(angle, radius), mods)


func spawn_enemy(config: Dictionary, position: Vector2, mods: Array) -> Node2D:
	var scene: PackedScene = ELITE_SCENE if not mods.is_empty() else ENEMY_SCENE
	var enemy: Node2D = scene.instantiate()
	enemy.call("setup", config, _player, _scaling(), mods)
	enemy.position = position
	_enemies.add_child.call_deferred(enemy)
	return enemy


func spawn_boss(boss_id: String) -> Node2D:
	var boss_cfg: Dictionary = Db.entry("bosses", "bosses", boss_id)
	if boss_cfg.is_empty():
		push_error("RunSpawner: unknown boss '%s'" % boss_id)
		return null
	var kind: String = Db.s(boss_cfg, "kind", "boss")
	if boss_alive(kind):
		return null
	var boss: Node2D = BOSS_SCENE.instantiate()
	var scaling: Dictionary = WaveDirector.boss_scaling(GameState.difficulty_tier, GameState.difficulty_multiplier, Db.table("difficulty"))
	boss.call("setup_boss", boss_cfg, _player, scaling)
	boss.position = _ring_position(GameState.rng.randf() * TAU, Db.cfg_f("run.boss_spawn_offset_px"))
	_alive_bosses[kind] = boss
	_enemies.add_child.call_deferred(boss)
	return boss


func spawn_adds(enemy_id: String, count: int, position: Vector2, spread_px: float) -> void:
	var config: Dictionary = Db.entry("enemies", "enemies", enemy_id)
	if config.is_empty():
		return
	for _index: int in count:
		var offset: Vector2 = Vector2.RIGHT.rotated(GameState.rng.randf() * TAU) * GameState.rng.randf() * spread_px
		var spot: Vector2 = _clamp_to_bounds(position + offset)
		if _location == null or bool(_location.call("is_walkable", spot)):
			spawn_enemy(config, spot, [])


## Point on a ring around the player, clamped inside the location and off the walls.
func _ring_position(angle: float, radius: float) -> Vector2:
	var center: Vector2 = _player.global_position
	var spot: Vector2 = center
	for attempt: int in Db.cfg_i("run.spawn_attempts"):
		spot = _clamp_to_bounds(center + Vector2.RIGHT.rotated(angle + RETRY_ANGLE_STEP * float(attempt)) * radius)
		if _location == null or bool(_location.call("is_walkable", spot)):
			return spot
	return spot


func _clamp_to_bounds(point: Vector2) -> Vector2:
	if _location == null:
		return point
	var bounds: Rect2 = _location.call("bounds")
	var margin: Vector2 = Vector2.ONE * Db.cfg_f("run.bounds_margin_px")
	return point.clamp(bounds.position + margin, bounds.end - margin)


# ---------------------------------------------------------------- requests

func spawn_projectile(spec: Dictionary) -> void:
	var enemy_side: bool = Db.s(spec, "faction") != "player"
	if enemy_side and _enemy_shots >= Db.cfg_i("run.max_enemy_projectiles"):
		return
	var node: Node2D = PROJECTILE_SCENE.instantiate()
	node.call("setup", spec)
	if enemy_side:
		_enemy_shots += 1
		node.tree_exited.connect(_on_enemy_shot_gone)
	_projectiles.add_child.call_deferred(node)


func _on_enemy_shot_gone() -> void:
	_enemy_shots = maxi(0, _enemy_shots - 1)


func spawn_pickup(kind: String, position: Vector2, value: float, extra: Dictionary) -> void:
	if _pickups.get_child_count() >= Db.cfg_i("run.max_pickups") and kind != "powerup":
		GameState.collect_pickup(kind, value, extra)
		return
	var node: Node2D = PICKUP_SCENE.instantiate()
	node.call("setup", kind, value, extra, _player)
	node.position = position
	_pickups.add_child.call_deferred(node)


func spawn_drone(spec: Dictionary) -> void:
	_drone_list = _drone_list.filter(func(node: Node) -> bool: return is_instance_valid(node))
	var cap: int = maxi(1, Db.i(spec, "max_drones", 1) + int(GameState.stat("drone_cap_bonus")))
	while _drone_list.size() >= cap:
		(_drone_list.pop_front() as Node).queue_free()
	var drone: Node2D = DRONE_SCENE.instantiate()
	drone.call("setup", _player, spec)
	_drone_list.append(drone)
	_drones.add_child.call_deferred(drone)
	for index: int in _drone_list.size():
		(_drone_list[index] as Node).call("set_slot", index, _drone_list.size())


func drone_count() -> int:
	return _drone_list.filter(func(node: Node) -> bool: return is_instance_valid(node)).size()


func spawn_beam(points: PackedVector2Array, color: Color, width: float, duration_sec: float) -> void:
	var line: Line2D = Line2D.new()
	line.points = points
	line.width = width
	line.default_color = color
	line.antialiased = false
	line.z_index = FX_Z
	_fx.add_child.call_deferred(line)
	_fade_out.call_deferred(line, duration_sec)


func spawn_lightning(points: PackedVector2Array, color: Color, duration_sec: float) -> void:
	var bolt: Node2D = Node2D.new()
	bolt.set_script(LIGHTNING_SCRIPT)
	bolt.call("setup", points, color, duration_sec)
	bolt.z_index = FX_Z
	_fx.add_child.call_deferred(bolt)


func spawn_ring(position: Vector2, radius: float, color: Color, duration_sec: float) -> void:
	var ring: Line2D = Neon.ring(radius, color, Db.cfg_f("fx.ring_width"))
	ring.position = position
	ring.z_index = FX_Z
	_fx.add_child.call_deferred(ring)
	_fade_out.call_deferred(ring, duration_sec)


func _fade_out(node: CanvasItem, duration_sec: float) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "modulate:a", 0.0, maxf(0.01, duration_sec))
	tween.tween_callback(node.queue_free)


func spawn_damage_number(position: Vector2, amount: float, crit: bool, color: Color) -> void:
	if _numbers >= Db.cfg_i("fx.damage_numbers_max"):
		return
	var number: Node2D = DAMAGE_NUMBER_SCENE.instantiate()
	number.position = position
	number.call("setup", amount, crit, color)
	_numbers += 1
	number.tree_exited.connect(_on_number_gone)
	_fx.add_child.call_deferred(number)


func _on_number_gone() -> void:
	_numbers = maxi(0, _numbers - 1)


## Removes everything location-bound; drones stay with the player.
func clear_world() -> void:
	for layer: Node in [_enemies, _projectiles, _pickups, _fx]:
		for child: Node in layer.get_children():
			child.queue_free()
	_alive_bosses = {}
	for drone: Variant in _drone_list:
		if is_instance_valid(drone):
			(drone as Node2D).global_position = _player.global_position
