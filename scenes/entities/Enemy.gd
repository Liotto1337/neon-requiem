extends CharacterBody2D
## Regular enemy. Behaviour (chase / shoot / dash / spinner / bomber / orbit) and stats come
## from data/enemies.json, scaled by WaveDirector tier multipliers. The spawner calls setup()
## before adding the node and passes the target; the enemy never looks nodes up itself.

const Db = preload("res://core/Db.gd")
const Neon = preload("res://core/Neon.gd")
const ShotFactory = preload("res://scenes/entities/components/ShotFactory.gd")
const MSEC: float = 1000.0
const PERCENT: float = 100.0
const BODY_RADIUS_RATIO: float = 0.4
const HP_BAR_OFFSET: float = 0.75
const DASH_IDLE: int = 0
const DASH_WINDUP: int = 1
const DASH_GO: int = 2
const KEEP_FAR: float = 1.1
const KEEP_NEAR: float = 0.8
const STRAFE: float = 0.5
const SPINNER_DRIFT: float = 0.4
const FLASH_ENERGY: float = 2.5

var cfg: Dictionary = {}
var enemy_id: String = ""
var target: Node2D = null
var scaling: Dictionary = {}
var mods: Array = []
var hp: float = 1.0
var hp_max: float = 1.0
var shield: float = 0.0
var damage: float = 0.0
var speed: float = 0.0
var size_px: float = 32.0
var is_elite: bool = false
var is_boss: bool = false
var damage_factor: float = 1.0
var speed_factor: float = 1.0

var _aura_mult: float = 1.0
var _aura_until_msec: int = 0
var _slow_mult: float = 1.0
var _slow_until_msec: int = 0
var _stun_until_msec: int = 0
var _knockback: Vector2 = Vector2.ZERO
var _pull: Vector2 = Vector2.ZERO
var _burn_dps: float = 0.0
var _burn_until_msec: int = 0
var _next_burn_msec: int = 0
var _next_shot_msec: int = 0
var _shot_angle: float = 0.0
var _dash_state: int = DASH_IDLE
var _dash_until_msec: int = 0
var _dash_dir: Vector2 = Vector2.ZERO
var _flash_until_msec: int = 0
var _strafe_sign: float = 1.0
var _dead: bool = false

@onready var _collision: CollisionShape2D = $Collision
@onready var _visual: Node2D = $Visual
@onready var outline_fx: ColorRect = $OutlineFx
@onready var _hp_bar: Line2D = $HpBar


func setup(config: Dictionary, target_node: Node2D, tier_scaling: Dictionary, elite_mods: Array) -> void:
	cfg = config
	enemy_id = Db.s(cfg, "id")
	target = target_node
	scaling = tier_scaling
	mods = elite_mods.duplicate()
	hp_max = Db.f(cfg, "hp") * Db.f(scaling, "hp", 1.0)
	hp = hp_max
	damage = Db.f(cfg, "damage") * Db.f(scaling, "damage", 1.0)
	speed = Db.f(cfg, "speed") * Db.f(scaling, "speed", 1.0)
	size_px = Db.f(cfg, "size")


func _ready() -> void:
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = size_px * BODY_RADIUS_RATIO
	_collision.shape = shape
	Neon.build_body(_visual, Db.s(cfg, "shape", "square"), size_px, Db.s(cfg, "color", "magenta"))
	var cooldown: float = Db.f(Db.d(cfg, "shot"), "cooldown")
	_next_shot_msec = TimeService.run_msec() + int(cooldown * MSEC * GameState.rng.randf())
	_strafe_sign = 1.0 if GameState.rng.randf() < 0.5 else -1.0


func is_dead() -> bool:
	return _dead


func _physics_process(delta: float) -> void:
	if _dead or target == null or not is_instance_valid(target):
		return
	var now: int = TimeService.run_msec()
	_tick_status(now)
	if _dead:
		return
	var move: Vector2 = Vector2.ZERO
	if now >= _stun_until_msec:
		move = _behave(now, delta) * speed * _speed_mult(now)
	velocity = move + _knockback + _pull
	move_and_slide()
	_knockback = _knockback.move_toward(Vector2.ZERO, Db.cfg_f("combat.knockback_decay") * delta)
	_pull = _pull.lerp(Vector2.ZERO, clampf(Db.cfg_f("combat.pull_decay") * delta, 0.0, 1.0))
	var flash: bool = now < _flash_until_msec
	_visual.modulate = Color(FLASH_ENERGY, FLASH_ENERGY, FLASH_ENERGY) if flash else Color.WHITE


## Movement direction for this frame (length 1 = base speed). Also fires shots.
func _behave(now: int, _delta: float) -> Vector2:
	match Db.s(cfg, "behavior", "chase"):
		"shoot":
			return _behave_shoot(now)
		"dash":
			return _behave_dash(now)
		"spinner":
			return _behave_spinner(now)
		"bomber":
			return _behave_bomber()
		"orbit":
			return _behave_orbit(now)
	return _to_target()


func _to_target() -> Vector2:
	return (target.global_position - global_position).normalized()


func _behave_shoot(now: int) -> Vector2:
	var to_target: Vector2 = target.global_position - global_position
	var keep: float = Db.f(cfg, "keep_distance")
	_try_shoot(now, to_target.angle(), false)
	if to_target.length() > keep * KEEP_FAR:
		return to_target.normalized()
	if to_target.length() < keep * KEEP_NEAR:
		return -to_target.normalized()
	return to_target.normalized().orthogonal() * STRAFE * _strafe_sign


func _behave_spinner(now: int) -> Vector2:
	var shot: Dictionary = Db.d(cfg, "shot")
	if _try_shoot(now, _shot_angle, true):
		_shot_angle += deg_to_rad(Db.f(shot, "rotate_deg"))
	return _to_target() * SPINNER_DRIFT


func _behave_orbit(now: int) -> Vector2:
	var to_target: Vector2 = target.global_position - global_position
	_try_shoot(now, to_target.angle(), false)
	var radial: float = clampf((to_target.length() - Db.f(cfg, "orbit_distance")) / Db.f(cfg, "orbit_distance"), -1.0, 1.0)
	return (to_target.normalized() * radial + to_target.normalized().orthogonal() * _strafe_sign).normalized()


func _behave_dash(now: int) -> Vector2:
	var dash: Dictionary = Db.d(cfg, "dash")
	match _dash_state:
		DASH_WINDUP:
			if now >= _dash_until_msec:
				_dash_state = DASH_GO
				_dash_dir = _to_target()
				_dash_until_msec = now + int(Db.f(dash, "duration") * MSEC)
			return Vector2.ZERO
		DASH_GO:
			if now >= _dash_until_msec:
				_dash_state = DASH_IDLE
				_next_shot_msec = now + int(Db.f(dash, "cooldown") * MSEC)
			return _dash_dir * (Db.f(dash, "speed") / maxf(1.0, speed))
	var in_range: bool = global_position.distance_to(target.global_position) <= Db.f(dash, "range")
	if in_range and now >= _next_shot_msec:
		_dash_state = DASH_WINDUP
		_dash_until_msec = now + int(Db.f(dash, "windup") * MSEC)
		_flash_until_msec = _dash_until_msec
	return _to_target()


func _behave_bomber() -> Vector2:
	var explode: Dictionary = Db.d(cfg, "explode")
	if global_position.distance_to(target.global_position) <= Db.f(explode, "trigger_range"):
		_self_destruct(explode)
		return Vector2.ZERO
	return _to_target()


## Bomber: leaves a delayed blast where it stands and disappears without rewards.
func _self_destruct(explode: Dictionary) -> void:
	var blast_damage: float = Db.f(explode, "damage") * Db.f(scaling, "damage", 1.0) * damage_factor
	Signals.projectile_requested.emit(ShotFactory.enemy_blast(global_position, blast_damage, Db.f(explode, "radius"), Db.f(explode, "fuse"), Db.s(explode, "color", "amber"), hit_extras()))
	_dead = true
	queue_free()


## Fires the data "shot" block when off cooldown: aimed fan, or a full ring when `ring`.
func _try_shoot(now: int, base_angle: float, ring: bool) -> bool:
	var shot: Dictionary = Db.d(cfg, "shot")
	if shot.is_empty() or now < _next_shot_msec:
		return false
	_next_shot_msec = now + int(Db.f(shot, "cooldown") * MSEC)
	var count: int = maxi(1, Db.i(shot, "count", 1))
	var spread: float = deg_to_rad(Db.f(shot, "spread_deg"))
	for index: int in count:
		var angle: float = base_angle
		if ring:
			angle += TAU * float(index) / float(count)
		elif count > 1:
			angle += lerpf(-spread * 0.5, spread * 0.5, float(index) / float(count - 1))
		Signals.projectile_requested.emit(ShotFactory.enemy_shot(global_position, Vector2.RIGHT.rotated(angle), shot, shot_damage_mult(now), hit_extras()))
	return true


func shot_damage_mult(now: int) -> float:
	var aura: float = _aura_mult if now < _aura_until_msec else 1.0
	return Db.f(scaling, "damage", 1.0) * damage_factor * aura


func _speed_mult(now: int) -> float:
	var slow: float = _slow_mult if now < _slow_until_msec else 1.0
	return speed_factor * slow


## Extra fields every hit from this enemy carries (elites add antiheal etc.).
func hit_extras() -> Dictionary:
	return {"attacker": self, "source": enemy_id}


## Contact damage payload polled by the player's hurtbox.
func contact_hit() -> Dictionary:
	var hit: Dictionary = hit_extras()
	var now: int = TimeService.run_msec()
	var aura: float = _aura_mult if now < _aura_until_msec else 1.0
	hit["damage"] = damage * damage_factor * aura
	return hit


## Vampiric elites heal here; regular enemies ignore it.
func on_damage_dealt(_amount: float) -> void:
	pass


func receive_hit(hit: Dictionary) -> Dictionary:
	if _dead:
		return {}
	var mult: float = 1.0
	if is_elite:
		mult *= Db.f(hit, "elite_mult", 1.0)
	if is_boss:
		mult *= Db.f(hit, "boss_mult", 1.0)
	var target_stats: Dictionary = {"shield": shield, "armor": Db.f(cfg, "armor"), "armor_k": Db.cfg_f("combat.armor_k"), "damage_taken_mult": mult}
	var result: Dictionary = DamageCalc.apply_to_target(Db.f(hit, "damage"), target_stats)
	shield = Db.f(result, "shield_left")
	hp -= Db.f(result, "hp_damage")
	_on_damaged(result, hit)
	if hp <= 0.0:
		_die()
	return result


func _on_damaged(result: Dictionary, hit: Dictionary) -> void:
	var color_name: String = "blue" if Db.f(result, "shield_absorbed") > 0.0 else ("amber" if bool(hit.get("crit", false)) else "white")
	Signals.damage_number_requested.emit(global_position, Db.f(result, "total"), bool(hit.get("crit", false)), Db.glow(color_name))
	var now: int = TimeService.run_msec()
	_flash_until_msec = now + int(Db.cfg_f("fx.enemy_flash_sec") * MSEC)
	if Db.f(hit, "stun_sec") > 0.0:
		apply_stun(Db.f(hit, "stun_sec"))
	if Db.f(hit, "slow_sec") > 0.0:
		apply_slow(Db.f(hit, "slow_mult", 1.0), Db.f(hit, "slow_sec"))
	if Db.f(hit, "knockback") > 0.0:
		var push: Vector2 = hit.get("knockback_dir", Vector2.ZERO)
		_knockback += push * Db.f(hit, "knockback") * (1.0 - Db.f(cfg, "knockback_resist"))
	_update_hp_bar()


func _update_hp_bar() -> void:
	if not _hp_bar.visible:
		return
	var width: float = Db.f(Db.d(Db.table("elites"), "base"), "hp_bar_width")
	var y: float = -size_px * HP_BAR_OFFSET
	var fraction: float = clampf(hp / maxf(1.0, hp_max), 0.0, 1.0)
	_hp_bar.points = PackedVector2Array([Vector2(-width * 0.5, y), Vector2(-width * 0.5 + width * fraction, y)])
	_hp_bar.default_color = Db.glow("blue" if shield > 0.0 else "red")


func show_hp_bar() -> void:
	_hp_bar.visible = true
	_update_hp_bar()


func _tick_status(now: int) -> void:
	if now >= _burn_until_msec or now < _next_burn_msec:
		return
	var tick: float = Db.cfg_f("combat.burn_tick_sec")
	_next_burn_msec = now + int(tick * MSEC)
	var amount: float = DamageCalc.dot(_burn_dps, tick)
	hp -= amount
	Signals.damage_number_requested.emit(global_position, amount, false, Db.glow("orange"))
	_update_hp_bar()
	if hp <= 0.0:
		_die()


func apply_slow(mult: float, seconds: float) -> void:
	_slow_mult = minf(_slow_mult if TimeService.run_msec() < _slow_until_msec else 1.0, mult)
	_slow_until_msec = maxi(_slow_until_msec, TimeService.deadline(seconds))


func apply_stun(seconds: float) -> void:
	if is_boss:
		return
	_stun_until_msec = maxi(_stun_until_msec, TimeService.deadline(seconds))


func apply_pull(center: Vector2, force: float) -> void:
	_pull = (center - global_position).normalized() * force * (1.0 - Db.f(cfg, "knockback_resist"))


func apply_burn(dps: float, seconds: float) -> void:
	_burn_dps = maxf(_burn_dps if TimeService.run_msec() < _burn_until_msec else 0.0, dps)
	_burn_until_msec = TimeService.deadline(seconds)


func apply_aura(mult: float, seconds: float) -> void:
	_aura_mult = maxf(1.0, mult)
	_aura_until_msec = TimeService.deadline(seconds)


func heal(amount: float) -> void:
	hp = minf(hp_max, hp + maxf(0.0, amount))
	_update_hp_bar()


func _die() -> void:
	if _dead:
		return
	_dead = true
	_on_death()
	_grant_rewards()
	Signals.enemy_killed.emit(enemy_id, global_position, mods)
	queue_free()


## Hook for subclasses (elite death blast); regular enemies do nothing extra.
func _on_death() -> void:
	pass


func _grant_rewards() -> void:
	GameState.register_kill({"enemy_id": enemy_id, "position": global_position, "elite": is_elite})
	var jitter: float = Db.cfg_f("pickups.jitter_px")
	for drop: Variant in LootRoller.roll_drops(GameState.rng, cfg, scaling, is_elite):
		var offset: Vector2 = Vector2(GameState.rng.randf_range(-jitter, jitter), GameState.rng.randf_range(-jitter, jitter))
		Signals.pickup_requested.emit(Db.s(drop, "kind"), global_position + offset, Db.f(drop, "value"), {})
