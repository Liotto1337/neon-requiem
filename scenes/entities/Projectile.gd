extends Area2D
## One projectile, blast or damage zone, configured by a spec Dictionary (see ShotFactory):
##   faction "player"|"enemy", position, direction, speed, damage, crit, radius, lifetime,
##   pierce, shape ("bolt"|"orb"|"arc"|"zone"), color, ghost (ignores walls), attached
##   (lives in the owner's local space), delay (arming time), blast (one area hit when armed),
##   hit_interval (persistent zone), pull_force, homing / turn_rate, orbit_radius /
##   angular_speed / phase, split / split_damage_mult, blast_on_expire {damage, radius},
##   on_hit [effects], lifesteal_pct, elite_mult, boss_mult, stun_sec, slow_mult / slow_sec,
##   knockback, antiheal_sec, attacker (Node).
## Hits are queued in body_entered and resolved in _physics_process, outside the physics
## flush, so on-hit chains can query the space and spawn safely.

const Db = preload("res://core/Db.gd")
const Neon = preload("res://core/Neon.gd")
const Sprites = preload("res://core/Sprites.gd")
const ShotFactory = preload("res://scenes/entities/components/ShotFactory.gd")
const MSEC: float = 1000.0
const FACTION_PLAYER: String = "player"
const ZONE_FILL_ALPHA: float = 0.12
const DEFAULT_SPRITES: Dictionary = {"bolt": "bolt", "arc": "slash", "orb": "orb"}
## Collision radius each projectile sheet is drawn for; the sprite scales from it.
const NOMINAL_RADIUS: Dictionary = {"bolt": 5.0, "lance": 8.0, "orb": 8.0, "pellet": 4.0, "needle": 4.0, "rocket": 6.0, "blade": 12.0, "slash": 45.0}
const SCALE_STEP: float = 0.25

var spec: Dictionary = {}
var _velocity: Vector2 = Vector2.ZERO
var _armed_msec: int = 0
var _expires_msec: int = 0
var _armed: bool = false
var _done: bool = false
var _pierce_left: int = 0
var _hit_ready: Dictionary = {}
var _pending: Array = []
var _next_zone_msec: int = 0
var _homing_target: Node2D = null
var _next_retarget_msec: int = 0
var _orbit_angle: float = 0.0

@onready var _collision: CollisionShape2D = $Collision
@onready var _visual: Node2D = $Visual


func setup(new_spec: Dictionary) -> void:
	spec = new_spec


func is_enemy_shot() -> bool:
	return Db.s(spec, "faction") != FACTION_PLAYER


func _ready() -> void:
	var now: int = TimeService.run_msec()
	_armed_msec = now + int(Db.f(spec, "delay") * MSEC)
	_expires_msec = _armed_msec + int(Db.f(spec, "lifetime") * MSEC)
	_pierce_left = Db.i(spec, "pierce")
	var direction: Vector2 = spec.get("direction", Vector2.RIGHT)
	_velocity = direction.normalized() * Db.f(spec, "speed")
	_orbit_angle = Db.f(spec, "phase")
	if spec.has("position") and not bool(spec.get("attached", false)):
		global_position = spec["position"]
	rotation = direction.angle()
	_configure_collision()
	_build_visual()
	body_entered.connect(_on_body_entered)
	_visual.modulate.a = Db.cfg_f("fx.telegraph_alpha") if Db.f(spec, "delay") > 0.0 else 1.0


func _configure_collision() -> void:
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = maxf(1.0, Db.f(spec, "radius"))
	_collision.shape = shape
	var player_side: bool = not is_enemy_shot()
	collision_layer = Db.layer_bit("player_projectile" if player_side else "enemy_projectile")
	collision_mask = _target_mask()
	if not bool(spec.get("ghost", false)):
		collision_mask |= Db.layer_bit("wall")
	monitorable = false
	monitoring = not bool(spec.get("blast", false)) and Db.f(spec, "delay") <= 0.0


func _target_mask() -> int:
	return Db.layer_bit("player") if is_enemy_shot() else Db.layer_bit("enemy")


func _build_visual() -> void:
	var color_name: String = Db.s(spec, "color", "white")
	var radius: float = maxf(1.0, Db.f(spec, "radius"))
	var orbiting: bool = Db.f(spec, "orbit_radius") > 0.0
	if bool(spec.get("blast", false)) or (Db.f(spec, "hit_interval") > 0.0 and not orbiting):
		_build_zone(radius, color_name)
		return
	var sprite_name: String = Db.s(spec, "sprite")
	if sprite_name == "":
		sprite_name = str(DEFAULT_SPRITES.get(Db.s(spec, "shape", "orb"), "orb"))
	var sprite: AnimatedSprite2D = Sprites.attach(_visual, "fx/" + sprite_name)
	sprite.material = null
	sprite.modulate = Db.glow(color_name)
	var size: float = radius / float(NOMINAL_RADIUS.get(sprite_name, 8.0))
	_visual.scale = Vector2.ONE * maxf(SCALE_STEP * 2.0, snappedf(size, SCALE_STEP))


func _build_zone(radius: float, color_name: String) -> void:
	var fill: Polygon2D = Polygon2D.new()
	fill.polygon = Neon.regular(Db.cfg_i("art.circle_segments") * 2, radius, 0.0)
	var tint: Color = Db.color(color_name)
	tint.a = ZONE_FILL_ALPHA
	fill.color = tint
	_visual.add_child(fill)
	_visual.add_child(Neon.ring(radius, Db.glow(color_name), Db.cfg_f("fx.ring_width")))


func _physics_process(delta: float) -> void:
	if _done:
		return
	var now: int = TimeService.run_msec()
	if not _armed:
		if now < _armed_msec:
			return
		_arm(now)
		if _done:
			return
	if now >= _expires_msec:
		_expire()
		return
	_move(delta, now)
	_resolve_pending(now)
	if Db.f(spec, "hit_interval") > 0.0 and now >= _next_zone_msec:
		_tick_zone(now)
	if Db.f(spec, "pull_force") > 0.0:
		_pull_overlapping()


func _arm(now: int) -> void:
	_armed = true
	_visual.modulate.a = 1.0
	if bool(spec.get("blast", false)):
		_detonate(now)
	else:
		monitoring = true


func _detonate(now: int) -> void:
	var radius: float = Db.f(spec, "radius")
	for body: Variant in ShotFactory.query_bodies(get_world_2d(), global_position, radius, _target_mask()):
		_hit(body, now)
	Signals.ring_fx_requested.emit(global_position, radius, Db.glow(Db.s(spec, "color", "white")), Db.cfg_f("fx.ring_sec"))
	_done = true
	queue_free()


func _move(delta: float, now: int) -> void:
	if spec.has("orbit_radius"):
		_orbit_angle += Db.f(spec, "angular_speed") * delta
		position = Vector2.RIGHT.rotated(_orbit_angle) * Db.f(spec, "orbit_radius")
		rotation = _orbit_angle
		return
	if bool(spec.get("homing", false)):
		_steer(delta, now)
	if _velocity != Vector2.ZERO:
		global_position += _velocity * delta
		rotation = _velocity.angle()


func _steer(delta: float, now: int) -> void:
	if now >= _next_retarget_msec or _homing_target == null or not is_instance_valid(_homing_target):
		_next_retarget_msec = now + int(Db.cfg_f("combat.homing_retarget_sec") * MSEC)
		_homing_target = ShotFactory.nearest_enemy(get_world_2d(), global_position, Db.cfg_f("combat.homing_search_px"), [])
	if _homing_target == null or not is_instance_valid(_homing_target):
		return
	var speed: float = _velocity.length()
	var desired: Vector2 = (_homing_target.global_position - global_position).normalized() * speed
	_velocity = _velocity.lerp(desired, clampf(Db.f(spec, "turn_rate") * delta, 0.0, 1.0)).normalized() * speed


func _on_body_entered(body: Node2D) -> void:
	_pending.append(body)


func _resolve_pending(now: int) -> void:
	if _pending.is_empty():
		return
	var bodies: Array = _pending
	_pending = []
	for body: Variant in bodies:
		if _done or not is_instance_valid(body):
			continue
		if body is TileMapLayer or body is StaticBody2D:
			if not bool(spec.get("ghost", false)):
				_expire()
			continue
		if Db.f(spec, "hit_interval") <= 0.0 and (body as Node).has_method("receive_hit"):
			_hit(body, now)


func _tick_zone(now: int) -> void:
	_next_zone_msec = now + int(Db.f(spec, "hit_interval") * MSEC)
	for body: Node2D in get_overlapping_bodies():
		if body.has_method("receive_hit"):
			_hit(body, now)


func _pull_overlapping() -> void:
	for body: Node2D in get_overlapping_bodies():
		if body.has_method("apply_pull"):
			body.call("apply_pull", global_position, Db.f(spec, "pull_force"))


func _hit(body: Node2D, now: int) -> void:
	var key: int = body.get_instance_id()
	if now < int(_hit_ready.get(key, 0)):
		return
	var interval: float = Db.f(spec, "hit_interval")
	_hit_ready[key] = now + int(interval * MSEC) if interval > 0.0 else _expires_msec + 1
	var result: Variant = body.call("receive_hit", _payload(body))
	if not is_enemy_shot() and result is Dictionary and not (result as Dictionary).is_empty():
		_after_player_hit(body, result)
	if interval <= 0.0 and not bool(spec.get("blast", false)):
		_pierce_left -= 1
		if _pierce_left < 0:
			_expire()


func _payload(body: Node2D) -> Dictionary:
	var push: Vector2 = _velocity.normalized()
	if push == Vector2.ZERO:
		push = (body.global_position - global_position).normalized()
	return {
		"damage": Db.f(spec, "damage"), "crit": bool(spec.get("crit", false)),
		"faction": Db.s(spec, "faction"), "source": Db.s(spec, "source", "projectile"),
		"elite_mult": Db.f(spec, "elite_mult", 1.0), "boss_mult": Db.f(spec, "boss_mult", 1.0),
		"stun_sec": Db.f(spec, "stun_sec"), "slow_mult": Db.f(spec, "slow_mult", 1.0),
		"slow_sec": Db.f(spec, "slow_sec"), "knockback": Db.f(spec, "knockback"),
		"knockback_dir": push, "antiheal_sec": Db.f(spec, "antiheal_sec"),
		"attacker": spec.get("attacker"),
	}


func _after_player_hit(body: Node2D, result: Dictionary) -> void:
	var lifesteal: float = DamageCalc.lifesteal(Db.f(result, "hp_damage"), Db.f(spec, "lifesteal_pct"))
	if lifesteal > 0.0:
		GameState.heal_player(lifesteal, "lifesteal")
	for effect: Variant in Db.a(spec, "on_hit"):
		_apply_on_hit(effect, body)
	if Db.i(spec, "split") > 0 and not bool(spec.get("is_split", false)):
		_split()


func _apply_on_hit(effect: Dictionary, body: Node2D) -> void:
	if GameState.rng.randf() >= Db.f(effect, "chance", 1.0) or not is_instance_valid(body):
		return
	match Db.s(effect, "kind"):
		"chain":
			var next: Node2D = ShotFactory.nearest_enemy(get_world_2d(), body.global_position, Db.f(effect, "range"), [body])
			if next != null:
				ShotFactory.chain(get_world_2d(), body.global_position, next, Db.f(spec, "damage") * Db.f(effect, "damage_mult"), Db.i(effect, "jumps") - 1, Db.f(effect, "range"), {"source": "chain"}, "cyan")
		"burn":
			if body.has_method("apply_burn"):
				body.call("apply_burn", Db.f(spec, "damage") * Db.f(effect, "dps_mult"), Db.f(effect, "duration"))


func _split() -> void:
	var count: int = Db.i(spec, "split")
	for index: int in count:
		var shard: Dictionary = spec.duplicate(true)
		shard["is_split"] = true
		shard["pierce"] = 0
		shard["split"] = 0
		shard["damage"] = Db.f(spec, "damage") * Db.f(spec, "split_damage_mult", 1.0)
		shard["position"] = global_position
		shard["direction"] = Vector2.RIGHT.rotated(TAU * float(index) / float(count) + rotation)
		shard["on_hit"] = []
		Signals.projectile_requested.emit(shard)


func _expire() -> void:
	if _done:
		return
	_done = true
	var blast: Dictionary = Db.d(spec, "blast_on_expire")
	if not blast.is_empty() and not is_enemy_shot():
		Signals.projectile_requested.emit(ShotFactory.player_blast(global_position, Db.f(blast, "damage"), Db.f(blast, "radius"), Db.s(spec, "color", "white")))
	queue_free()
