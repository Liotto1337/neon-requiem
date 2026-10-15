extends Node
## Hero base attacks from data/heroes.json: LMB primary, RMB empowered, R class action —
## ranged reloads, melee parries, summoner recalls drones. Shots go out through Signals;
## the melee dash trail is attached to the player.

const Db = preload("res://core/Db.gd")
const ShotFactory = preload("res://scenes/entities/components/ShotFactory.gd")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/entities/Projectile.tscn")
const MSEC: float = 1000.0
const CLASS_RANGED: String = "ranged"
const CLASS_MELEE: String = "melee"
const PIERCE_ALL: int = 99
const KIND_EMPOWERED: String = "empowered"
const KIND_ACTION: String = "class_action"

var _player: CharacterBody2D = null
var _hero: Dictionary = {}
var _attack: Dictionary = {}
var _empowered: Dictionary = {}
var _action: Dictionary = {}
var _class: String = ""
var _ready_msec: int = 0
var _empowered_ready_msec: int = 0
var _action_ready_msec: int = 0
var _ammo: int = 0
var _reloading: bool = false
var _reload_done_msec: int = 0
var _parry_until_msec: int = 0
var _parry_countered: bool = false


func setup(player: CharacterBody2D, hero: Dictionary) -> void:
	_player = player
	_hero = hero
	_attack = Db.d(hero, "attack")
	_empowered = Db.d(hero, "empowered")
	_action = Db.d(hero, "r_action")
	_class = Db.s(hero, "class")
	_ammo = Db.i(_attack, "magazine")
	emit_state()


func _physics_process(_delta: float) -> void:
	if _reloading and TimeService.run_msec() >= _reload_done_msec:
		_reloading = false
		_ammo = Db.i(_attack, "magazine")
		emit_state()


func emit_state() -> void:
	if _class == CLASS_RANGED:
		Signals.ammo_changed.emit(_ammo, Db.i(_attack, "magazine"), _reloading)
		Signals.class_action_changed.emit(Db.s(_action, "label"), TimeService.until_sec(_reload_done_msec) if _reloading else 0.0)
	else:
		Signals.class_action_changed.emit(Db.s(_action, "label"), maxf(0.0, TimeService.until_sec(_action_ready_msec)))


func _origin() -> Vector2:
	return _player.global_position


func _aim_dir(aim: Vector2) -> Vector2:
	var direction: Vector2 = aim - _origin()
	return direction.normalized() if direction.length_squared() > 0.0 else Vector2.RIGHT


# ---------------------------------------------------------------- primary (LMB)

func primary(aim: Vector2) -> void:
	var now: int = TimeService.run_msec()
	if now < _ready_msec:
		return
	match _class:
		CLASS_RANGED:
			if not _fire_bolt(aim):
				return
		CLASS_MELEE:
			_slash(aim)
		_:
			_pulse(aim)
	_ready_msec = now + int(Db.f(_attack, "cooldown") / maxf(0.01, GameState.stat("attack_speed_mult", 1.0)) * MSEC)
	_player.call("animate", "attack")


func _fire_bolt(aim: Vector2) -> bool:
	if _reloading:
		return false
	if _ammo <= 0:
		_start_reload()
		return false
	_ammo -= 1
	var spread: float = deg_to_rad(Db.f(_attack, "spread_deg"))
	var direction: Vector2 = _aim_dir(aim).rotated(GameState.rng.randf_range(-spread, spread))
	Signals.projectile_requested.emit(ShotFactory.player_shot(_origin(), direction, Db.f(_attack, "damage"), _shot_params(_attack)))
	if _ammo <= 0:
		_start_reload()
	emit_state()
	return true


func _shot_params(source: Dictionary) -> Dictionary:
	return {
		"speed": Db.f(source, "speed"), "radius": Db.f(source, "radius"), "lifetime": Db.f(source, "lifetime"),
		"pierce": Db.i(source, "pierce"), "color": Db.s(source, "color", "white"),
		"shape": Db.s(source, "shape", "orb"), "knockback": Db.f(source, "knockback"),
	}


func _slash(aim: Vector2) -> void:
	var direction: Vector2 = _aim_dir(aim)
	var params: Dictionary = _shot_params(_attack)
	params["speed"] = 0.0
	params["pierce"] = PIERCE_ALL
	params["ghost"] = true
	params["arc_deg"] = Db.f(_attack, "arc_deg")
	params["radius"] = Db.f(_attack, "radius") * GameState.stat("area_mult", 1.0)
	Signals.projectile_requested.emit(ShotFactory.player_shot(_origin() + direction * Db.f(_attack, "range"), direction, Db.f(_attack, "damage"), params))


func _pulse(aim: Vector2) -> void:
	Signals.projectile_requested.emit(ShotFactory.player_shot(_origin(), _aim_dir(aim), Db.f(_attack, "damage"), _shot_params(_attack)))
	Signals.drones_command.emit("focus", {"position": aim, "duration": Db.f(_attack, "focus_sec")})


# ---------------------------------------------------------------- empowered (RMB)

func empowered(aim: Vector2) -> void:
	var now: int = TimeService.run_msec()
	if now < _empowered_ready_msec:
		Signals.cast_failed.emit(KIND_EMPOWERED, -1, "cooldown")
		return
	var done: bool = false
	match _class:
		CLASS_RANGED:
			done = _rail(aim)
		CLASS_MELEE:
			done = _dash_strike(aim)
		_:
			done = _overclock()
	if not done:
		return
	_player.call("animate", "attack")
	var mult: float = GameState.stat("dash_cooldown_mult", 1.0) if _class == CLASS_MELEE else GameState.stat("cooldown_mult", 1.0)
	_empowered_ready_msec = now + int(Db.f(_empowered, "cooldown") * mult * MSEC)


func _rail(aim: Vector2) -> bool:
	var cost: int = Db.i(_empowered, "ammo_cost")
	if _reloading or _ammo < cost:
		Signals.cast_failed.emit(KIND_EMPOWERED, -1, "ammo")
		return false
	_ammo -= cost
	var damage: float = Db.f(_attack, "damage") * Db.f(_empowered, "damage_mult", 1.0)
	Signals.projectile_requested.emit(ShotFactory.player_shot(_origin(), _aim_dir(aim), damage, _shot_params(_empowered)))
	Signals.screen_shake_requested.emit(Db.cfg_f("player.hurt_shake") * 0.5, Db.cfg_f("player.hurt_shake_sec"))
	if _ammo <= 0:
		_start_reload()
	emit_state()
	return true


func _dash_strike(aim: Vector2) -> bool:
	if not GameState.spend_mana(Db.f(_empowered, "mana_cost")):
		Signals.cast_failed.emit(KIND_EMPOWERED, -1, "mana")
		return false
	var duration: float = Db.f(_empowered, "duration")
	_player.call("start_dash", _aim_dir(aim), Db.f(_empowered, "distance"), duration, true)
	var params: Dictionary = {
		"speed": 0.0, "radius": Db.f(_empowered, "radius") * GameState.stat("area_mult", 1.0),
		"lifetime": duration, "pierce": PIERCE_ALL, "ghost": true, "attached": true,
		"color": Db.s(_empowered, "color", "white"), "shape": "orb", "sprite": "slash",
	}
	var damage: float = Db.f(_attack, "damage") * Db.f(_empowered, "damage_mult", 1.0)
	attach(ShotFactory.player_shot(_origin(), _aim_dir(aim), damage, params))
	return true


func _overclock() -> bool:
	if not GameState.spend_mana(Db.f(_empowered, "mana_cost")):
		Signals.cast_failed.emit(KIND_EMPOWERED, -1, "mana")
		return false
	Signals.drones_command.emit("overclock", {"duration": Db.f(_empowered, "duration"), "mult": Db.f(_empowered, "fire_rate_mult", 1.0)})
	return true


## Projectile that lives in the player's local space (dash trails, spin zones, orbit blades).
func attach(spec: Dictionary) -> void:
	spec["attached"] = true
	var node: Node = PROJECTILE_SCENE.instantiate()
	node.call("setup", spec)
	(_player.get("orbit_root") as Node2D).add_child(node)


# ---------------------------------------------------------------- class action (R)

func class_action(_aim: Vector2) -> void:
	var now: int = TimeService.run_msec()
	match _class:
		CLASS_RANGED:
			if not _reloading and _ammo < Db.i(_attack, "magazine"):
				_start_reload()
		CLASS_MELEE:
			_parry(now)
		_:
			_recall(now)


func _start_reload() -> void:
	if _reloading:
		return
	_reloading = true
	var seconds: float = Db.f(_attack, "reload_sec") / maxf(0.01, GameState.stat("attack_speed_mult", 1.0))
	_reload_done_msec = TimeService.deadline(seconds)
	_player.call("animate", "reload", seconds, seconds)
	emit_state()


func _parry(now: int) -> void:
	if now < _action_ready_msec:
		Signals.cast_failed.emit(KIND_ACTION, -1, "cooldown")
		return
	_parry_until_msec = now + int(Db.f(_action, "window_sec") * MSEC)
	_parry_countered = false
	_action_ready_msec = now + int(Db.f(_action, "cooldown") * GameState.stat("cooldown_mult", 1.0) * MSEC)
	_player.call("animate", "reload", 0.0, TimeService.until_sec(_action_ready_msec))
	Signals.ring_fx_requested.emit(_origin(), Db.f(_action, "counter_radius") * 0.5, Db.glow("magenta"), Db.f(_action, "window_sec"))
	emit_state()


## True when the hit lands inside the parry window: the hit is negated and, once per
## window, a counter blast fires and mana is refunded.
func try_parry(_hit: Dictionary) -> bool:
	if _class != CLASS_MELEE or TimeService.run_msec() >= _parry_until_msec:
		return false
	if not _parry_countered:
		_parry_countered = true
		Signals.projectile_requested.emit(ShotFactory.player_blast(_origin(), Db.f(_action, "counter_damage"), Db.f(_action, "counter_radius"), "magenta"))
		GameState.restore_mana(Db.f(_action, "mana_refund"))
		Signals.toast_requested.emit("Парирование!")
	return true


func _recall(now: int) -> void:
	if now < _action_ready_msec:
		Signals.cast_failed.emit(KIND_ACTION, -1, "cooldown")
		return
	_action_ready_msec = now + int(Db.f(_action, "cooldown") * GameState.stat("cooldown_mult", 1.0) * MSEC)
	_player.call("animate", "reload", 0.0, TimeService.until_sec(_action_ready_msec))
	Signals.drones_recall_requested.emit(Db.f(_action, "haste_sec"), Db.f(_action, "haste_mult", 1.0))
	emit_state()
