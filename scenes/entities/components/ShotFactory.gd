extends RefCounted
## Builds projectile / hit specs for Projectile.gd and runs the physics queries abilities need.
## Player shots roll damage and crits once, at spawn, from GameState.rng. Call queries only
## from _physics_process (never inside body_entered: the space is locked during the flush).

const Db = preload("res://core/Db.gd")
const FACTION_PLAYER: String = "player"
const FACTION_ENEMY: String = "enemy"


## params: speed, radius, lifetime, pierce, color, shape and any other Projectile.gd option.
static func player_shot(origin: Vector2, direction: Vector2, base_damage: float, params: Dictionary) -> Dictionary:
	var stats: Dictionary = GameState.stats()
	var hit: Dictionary = DamageCalc.outgoing(base_damage, stats, GameState.rng.randf())
	var spec: Dictionary = params.duplicate(true)
	spec["faction"] = FACTION_PLAYER
	spec["position"] = origin
	spec["direction"] = direction.normalized() if direction.length_squared() > 0.0 else Vector2.RIGHT
	spec["damage"] = Db.f(hit, "amount")
	spec["crit"] = bool(hit.get("crit", false))
	spec["speed"] = Db.f(params, "speed") * Db.f(stats, "projectile_speed_mult", 1.0)
	spec["on_hit"] = ItemSystem.on_hit_effects(GameState.items_passive)
	spec["lifesteal_pct"] = Db.f(stats, "lifesteal_pct")
	spec["elite_mult"] = Db.f(stats, "elite_damage_mult", 1.0)
	spec["boss_mult"] = Db.f(stats, "boss_damage_mult", 1.0)
	return spec


## One-shot area hit for the player side (abilities, item blasts, on-kill explosions).
static func player_blast(position: Vector2, base_damage: float, radius: float, color: String, extra: Dictionary = {}) -> Dictionary:
	var params: Dictionary = {
		"blast": true, "speed": 0.0, "color": color, "ghost": true,
		"radius": radius * GameState.stat("area_mult", 1.0),
		"lifetime": Db.cfg_f("fx.blast_fx_sec"),
	}
	params.merge(extra, true)
	var spec: Dictionary = player_shot(position, Vector2.RIGHT, base_damage, params)
	spec["on_hit"] = []
	return spec


## Direct hit payload (chains, beams, parry counters) without a projectile.
static func player_hit(base_damage: float, extra: Dictionary) -> Dictionary:
	var stats: Dictionary = GameState.stats()
	var hit: Dictionary = DamageCalc.outgoing(base_damage, stats, GameState.rng.randf())
	var out: Dictionary = extra.duplicate(true)
	out["faction"] = FACTION_PLAYER
	out["damage"] = Db.f(hit, "amount")
	out["crit"] = bool(hit.get("crit", false))
	out["elite_mult"] = Db.f(stats, "elite_damage_mult", 1.0)
	out["boss_mult"] = Db.f(stats, "boss_damage_mult", 1.0)
	return out


## Enemy bullet from a data "shot" block. extras: attacker, antiheal_sec, ...
static func enemy_shot(origin: Vector2, direction: Vector2, shot: Dictionary, damage_mult: float, extras: Dictionary) -> Dictionary:
	var spec: Dictionary = {
		"faction": FACTION_ENEMY,
		"position": origin,
		"direction": direction.normalized() if direction.length_squared() > 0.0 else Vector2.RIGHT,
		"damage": Db.f(shot, "damage") * damage_mult,
		"speed": Db.f(shot, "speed"),
		"radius": Db.f(shot, "radius"),
		"lifetime": Db.f(shot, "lifetime"),
		"color": Db.s(shot, "color", "magenta"),
		"shape": "orb",
	}
	spec.merge(extras, true)
	return spec


## Delayed enemy area hit (bombers, explosive elites). Shown as a telegraph ring until it fires.
static func enemy_blast(position: Vector2, damage: float, radius: float, fuse: float, color: String, extras: Dictionary) -> Dictionary:
	var spec: Dictionary = {
		"faction": FACTION_ENEMY, "position": position, "damage": damage, "radius": radius,
		"delay": fuse, "blast": true, "ghost": true, "speed": 0.0, "color": color,
		"lifetime": Db.cfg_f("fx.blast_fx_sec"),
	}
	spec.merge(extras, true)
	return spec


## Bodies with receive_hit() inside a circle on the given collision mask.
static func query_bodies(world: World2D, center: Vector2, radius: float, mask: int) -> Array:
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = maxf(1.0, radius)
	var params: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, center)
	params.collision_mask = mask
	params.collide_with_areas = false
	params.collide_with_bodies = true
	var out: Array = []
	for result: Dictionary in world.direct_space_state.intersect_shape(params, Db.cfg_i("combat.query_max_results")):
		var collider: Variant = result.get("collider")
		if collider is Node2D and is_instance_valid(collider) and (collider as Node2D).has_method("receive_hit"):
			out.append(collider)
	return out


static func enemies_near(world: World2D, center: Vector2, radius: float) -> Array:
	return query_bodies(world, center, radius, Db.layer_bit("enemy"))


static func nearest_enemy(world: World2D, center: Vector2, radius: float, exclude: Array) -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	for body: Variant in enemies_near(world, center, radius):
		var node: Node2D = body
		if exclude.has(node):
			continue
		var dist: float = center.distance_squared_to(node.global_position)
		if dist < best_d:
			best_d = dist
			best = node
	return best


## Lightning: hits `first`, then jumps to the nearest unhit enemy up to `jumps` times.
static func chain(world: World2D, origin: Vector2, first: Node2D, base_damage: float, jumps: int, jump_range: float, extra: Dictionary, color: String) -> void:
	var points: PackedVector2Array = PackedVector2Array([origin])
	var hit: Array = []
	var current: Node2D = first
	for _jump: int in jumps + 1:
		if current == null or not is_instance_valid(current):
			break
		points.append(current.global_position)
		hit.append(current)
		var at: Vector2 = current.global_position
		current.call("receive_hit", player_hit(base_damage, extra))
		current = nearest_enemy(world, at, jump_range, hit)
	if points.size() > 1:
		Signals.beam_fx_requested.emit(points, Db.glow(color), Db.cfg_f("fx.beam_width"), Db.cfg_f("fx.beam_sec"))
