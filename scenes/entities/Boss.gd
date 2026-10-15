extends "res://scenes/entities/Enemy.gd"
## Multi-phase boss / miniboss from data/bosses.json. Phases switch at HP thresholds; each
## phase cycles telegraphed attack patterns (radial, spiral, aimed_spread, summon_adds,
## laser_sweep) and moves by its "move" mode (chase / drift / anchor).

const EliteModifier = preload("res://scenes/entities/components/EliteModifier.gd")
const PATTERN_RADIAL: String = "radial"
const PATTERN_SPIRAL: String = "spiral"
const PATTERN_SPREAD: String = "aimed_spread"
const PATTERN_SUMMON: String = "summon_adds"
const PATTERN_LASER: String = "laser_sweep"
const TELEGRAPH_LINE_PX: float = 320.0
const TELEGRAPH_RING_SCALE: float = 0.9

var boss_cfg: Dictionary = {}
var boss_kind: String = "boss"
var _phase: int = 0
var _attack_index: int = 0
var _next_attack_msec: int = 0
var _pending: Dictionary = {}
var _telegraph_until_msec: int = 0
var _runner: Dictionary = {}
var _invuln_until_msec: int = 0
var _drift_angle: float = 0.0
var _home: Vector2 = Vector2.ZERO

@onready var _telegraph: Line2D = $Telegraph
@onready var _laser: Line2D = $Laser


func setup_boss(boss: Dictionary, target_node: Node2D, tier_scaling: Dictionary) -> void:
	boss_cfg = boss
	boss_kind = Db.s(boss, "kind", "boss")
	var as_enemy: Dictionary = {
		"id": Db.s(boss, "id"), "shape": Db.s(boss, "shape", "hex"), "color": Db.s(boss, "color", "white"),
		"size": Db.f(boss, "size") * Db.f(boss, "scale", 1.0), "hp": Db.f(boss, "hp"),
		"damage": Db.f(boss, "contact_damage"), "speed": Db.f(boss, "speed"),
		"armor": Db.f(boss, "armor"), "knockback_resist": 1.0, "behavior": "boss",
	}
	setup(as_enemy, target_node, tier_scaling, [])
	is_boss = true


func _ready() -> void:
	super._ready()
	_home = global_position
	EliteModifier.apply_outline(body, [Db.glow(Db.s(boss_cfg, "outline", "white"))])
	_next_attack_msec = TimeService.run_msec() + int(Db.f(Db.table("bosses"), "phase_invuln_sec") * MSEC)
	_telegraph.visible = false
	_laser.visible = false
	Signals.boss_spawned.emit(enemy_id, Db.s(boss_cfg, "name"), hp_max, boss_kind)


func current_phase() -> int:
	return _phase


func _phase_cfg() -> Dictionary:
	var phases: Array = Db.a(boss_cfg, "phases")
	return phases[clampi(_phase, 0, phases.size() - 1)] if not phases.is_empty() else {}


func _behave(now: int, delta: float) -> Vector2:
	_check_phase(now)
	_tick_attacks(now)
	match Db.s(_phase_cfg(), "move", "chase"):
		"drift":
			_drift_angle += Db.f(Db.table("bosses"), "drift_speed") * delta
			var spot: Vector2 = target.global_position + Vector2.RIGHT.rotated(_drift_angle) * Db.f(Db.table("bosses"), "drift_radius")
			return (spot - global_position).normalized()
		"anchor":
			var away: Vector2 = _home - global_position
			return away.normalized() if away.length() > Db.f(Db.table("bosses"), "anchor_range") else Vector2.ZERO
	return _to_target()


func _check_phase(now: int) -> void:
	var phases: Array = Db.a(boss_cfg, "phases")
	var next: int = _phase + 1
	if next >= phases.size() or hp / maxf(1.0, hp_max) > Db.f(phases[next], "hp_pct"):
		return
	_phase = next
	_attack_index = 0
	_pending = {}
	_runner = {}
	_telegraph.visible = false
	_laser.visible = false
	_invuln_until_msec = now + int(Db.f(Db.table("bosses"), "phase_invuln_sec") * MSEC)
	_next_attack_msec = _invuln_until_msec
	Signals.screen_shake_requested.emit(Db.cfg_f("fx.boss_phase_shake"), Db.cfg_f("fx.boss_phase_shake_sec"))
	Signals.ring_fx_requested.emit(global_position, size_px, Db.glow(Db.s(boss_cfg, "outline", "white")), Db.cfg_f("fx.ring_sec"))
	Signals.boss_health_changed.emit(hp, hp_max, _phase)


func _tick_attacks(now: int) -> void:
	if not _runner.is_empty():
		_tick_runner(now)
		return
	if not _pending.is_empty():
		if now >= _telegraph_until_msec:
			_execute(_pending, now)
			_pending = {}
		return
	var attacks: Array = Db.a(_phase_cfg(), "attacks")
	if now < _next_attack_msec or attacks.is_empty():
		return
	_pending = attacks[_attack_index % attacks.size()]
	_attack_index += 1
	_telegraph_until_msec = now + int(Db.f(_pending, "telegraph") * MSEC)
	_show_telegraph(_pending)


func _show_telegraph(attack: Dictionary) -> void:
	var tint: Color = Db.glow(Db.s(attack, "color", "white"))
	tint.a = Db.cfg_f("fx.telegraph_alpha")
	match Db.s(attack, "pattern"):
		PATTERN_SPREAD, PATTERN_LASER:
			var length: float = Db.f(attack, "length", TELEGRAPH_LINE_PX)
			var direction: Vector2 = _to_target()
			_telegraph.points = PackedVector2Array([Vector2.ZERO, direction * length])
			_telegraph.default_color = tint
			_telegraph.width = Db.cfg_f("fx.telegraph_width")
			_telegraph.visible = true
		_:
			Signals.ring_fx_requested.emit(global_position, size_px * TELEGRAPH_RING_SCALE, tint, Db.f(attack, "telegraph"))


func _execute(attack: Dictionary, now: int) -> void:
	_telegraph.visible = false
	match Db.s(attack, "pattern"):
		PATTERN_RADIAL:
			_fire_ring(attack, deg_to_rad(Db.f(attack, "offset_deg")) * float(_attack_index), Db.i(attack, "count"))
		PATTERN_SPREAD:
			_fire_spread(attack)
		PATTERN_SPIRAL:
			_runner = {"pattern": PATTERN_SPIRAL, "attack": attack, "until": now + int(Db.f(attack, "duration") * MSEC), "next": now, "angle": _to_target().angle()}
		PATTERN_SUMMON:
			Signals.adds_requested.emit(Db.s(attack, "enemy_id"), Db.i(attack, "count"), global_position, Db.f(attack, "spread_px"))
		PATTERN_LASER:
			_start_laser(attack, now)
	if _runner.is_empty():
		_next_attack_msec = now + int(Db.f(attack, "cooldown") * MSEC)


func _fire_ring(attack: Dictionary, offset: float, count: int) -> void:
	for index: int in maxi(1, count):
		var angle: float = offset + TAU * float(index) / float(maxi(1, count))
		_emit_bullet(attack, angle)


func _fire_spread(attack: Dictionary) -> void:
	var count: int = maxi(1, Db.i(attack, "count"))
	var spread: float = deg_to_rad(Db.f(attack, "spread_deg"))
	var base: float = _to_target().angle()
	for index: int in count:
		var t: float = float(index) / float(count - 1) if count > 1 else 0.5
		_emit_bullet(attack, base + lerpf(-spread * 0.5, spread * 0.5, t))


func _emit_bullet(attack: Dictionary, angle: float) -> void:
	Signals.projectile_requested.emit(ShotFactory.enemy_shot(muzzle_point(Vector2.RIGHT.rotated(angle)), Vector2.RIGHT.rotated(angle), attack, shot_damage_mult(TimeService.run_msec()), hit_extras()))


func _start_laser(attack: Dictionary, now: int) -> void:
	var start: float = _to_target().angle() - deg_to_rad(Db.f(attack, "sweep_deg")) * 0.5
	_runner = {"pattern": PATTERN_LASER, "attack": attack, "start_msec": now, "until": now + int(Db.f(attack, "duration") * MSEC), "next": now, "start": start}
	_laser.width = Db.f(attack, "width")
	_laser.default_color = Db.glow(Db.s(attack, "color", "white"))
	_laser.visible = true


func _tick_runner(now: int) -> void:
	var attack: Dictionary = _runner["attack"]
	if Db.s(_runner, "pattern") == PATTERN_SPIRAL:
		_tick_spiral(attack, now)
	else:
		_tick_laser(attack, now)
	if now >= Db.i(_runner, "until"):
		_laser.visible = false
		_runner = {}
		_next_attack_msec = now + int(Db.f(attack, "cooldown") * MSEC)


func _tick_spiral(attack: Dictionary, now: int) -> void:
	var interval: int = maxi(1, int(Db.f(attack, "interval") * MSEC))
	while now >= Db.i(_runner, "next") and Db.i(_runner, "next") < Db.i(_runner, "until"):
		var angle: float = Db.f(_runner, "angle")
		_fire_ring(attack, angle, Db.i(attack, "arms"))
		_runner["angle"] = angle + deg_to_rad(Db.f(attack, "turn_deg"))
		_runner["next"] = Db.i(_runner, "next") + interval


func _tick_laser(attack: Dictionary, now: int) -> void:
	var span: float = maxf(1.0, float(Db.i(_runner, "until") - Db.i(_runner, "start_msec")))
	var progress: float = clampf(float(now - Db.i(_runner, "start_msec")) / span, 0.0, 1.0)
	var angle: float = Db.f(_runner, "start") + deg_to_rad(Db.f(attack, "sweep_deg")) * progress
	var tip: Vector2 = Vector2.RIGHT.rotated(angle) * Db.f(attack, "length")
	_laser.points = PackedVector2Array([Vector2.ZERO, tip])
	if now < Db.i(_runner, "next"):
		return
	_runner["next"] = now + int(Db.f(attack, "tick_sec") * MSEC)
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(target.global_position, global_position, global_position + tip)
	if closest.distance_to(target.global_position) <= Db.f(attack, "width") * 0.5 and target.has_method("receive_hit"):
		var hit: Dictionary = hit_extras()
		hit["damage"] = Db.f(attack, "damage") * shot_damage_mult(now)
		hit["source"] = "laser"
		target.call("receive_hit", hit)


func receive_hit(hit: Dictionary) -> Dictionary:
	if TimeService.run_msec() < _invuln_until_msec:
		return {}
	var result: Dictionary = super.receive_hit(hit)
	Signals.boss_health_changed.emit(maxf(0.0, hp), hp_max, _phase)
	return result


func apply_pull(_center: Vector2, _force: float) -> void:
	pass


func _grant_rewards() -> void:
	GameState.register_kill({"enemy_id": enemy_id, "position": global_position, "elite": true})
	GameState.register_boss_kill(enemy_id)
