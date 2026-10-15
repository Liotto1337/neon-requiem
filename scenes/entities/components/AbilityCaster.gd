extends Node
## Executes abilities (Z X C V [B]) and active items (1..6 [7]). AbilitySystem / ItemSystem
## check cooldown and mana and return the level stats; this component turns them into
## projectiles, blasts, zones, buffs and drone requests. Level 5 flags come in the stats.

const Db = preload("res://core/Db.gd")
const ShotFactory = preload("res://scenes/entities/components/ShotFactory.gd")
const PIERCE_ALL: int = 99

var _player: CharacterBody2D = null


func setup(player: CharacterBody2D) -> void:
	_player = player


func _origin() -> Vector2:
	return _player.global_position


func _aim_dir(aim: Vector2) -> Vector2:
	var direction: Vector2 = aim - _origin()
	return direction.normalized() if direction.length_squared() > 0.0 else Vector2.RIGHT


func _area(value: float) -> float:
	return value * GameState.stat("area_mult", 1.0)


func _attach(spec: Dictionary) -> void:
	_player.get_node("Attack").call("attach", spec)


func cast_ability(slot: int, aim: Vector2) -> void:
	var spec: Dictionary = AbilitySystem.try_cast(slot)
	if not spec.is_empty():
		_player.call("animate", "cast")
		execute(spec, aim)


## Runs an ability from its level stats (also used by the smoke test).
func execute(spec: Dictionary, aim: Vector2) -> void:
	match Db.s(spec, "kind"):
		"projectile":
			_cast_projectile(spec, aim)
		"spread":
			_cast_spread(spec, aim)
		"radial":
			_cast_radial(spec)
		"chain":
			_cast_chain(spec, aim)
		"blink":
			_cast_blink(spec, aim)
		"spin":
			_cast_spin(spec)
		"emp":
			_cast_emp(spec)
		"drone":
			Signals.drone_requested.emit(spec)
		"homing":
			_cast_homing(spec, aim)
		"orbit":
			_cast_orbit(spec)
		"pull":
			_cast_pull(spec, aim)
		"buff":
			_cast_buff(spec)


func _bolt(spec: Dictionary) -> Dictionary:
	return {
		"speed": Db.f(spec, "speed"), "radius": Db.f(spec, "radius"), "lifetime": Db.f(spec, "lifetime"),
		"pierce": Db.i(spec, "pierce"), "color": Db.s(spec, "color", "white"), "shape": "bolt",
		"sprite": Db.s(spec, "sprite", "bolt"), "source": Db.s(spec, "id"),
	}


func _cast_projectile(spec: Dictionary, aim: Vector2) -> void:
	var params: Dictionary = _bolt(spec)
	params["split"] = Db.i(spec, "split")
	params["split_damage_mult"] = Db.f(spec, "split_damage_mult", 1.0)
	Signals.projectile_requested.emit(ShotFactory.player_shot(_origin(), _aim_dir(aim), Db.f(spec, "damage"), params))


func _cast_spread(spec: Dictionary, aim: Vector2) -> void:
	var count: int = maxi(1, int(Db.f(spec, "count")))
	var spread: float = deg_to_rad(Db.f(spec, "spread_deg"))
	var base: float = _aim_dir(aim).angle()
	for burst: int in maxi(1, Db.i(spec, "bursts", 1)):
		for index: int in count:
			var t: float = float(index) / float(count - 1) if count > 1 else 0.5
			var params: Dictionary = _bolt(spec)
			params["delay"] = Db.f(spec, "burst_gap_sec") * float(burst)
			var direction: Vector2 = Vector2.RIGHT.rotated(base + lerpf(-spread * 0.5, spread * 0.5, t))
			Signals.projectile_requested.emit(ShotFactory.player_shot(_origin(), direction, Db.f(spec, "damage"), params))


func _cast_radial(spec: Dictionary) -> void:
	var count: int = maxi(1, int(Db.f(spec, "count")))
	for ring: int in maxi(1, Db.i(spec, "rings", 1)):
		for index: int in count:
			var params: Dictionary = _bolt(spec)
			params["shape"] = "orb"
			params["delay"] = Db.f(spec, "ring_gap_sec") * float(ring)
			var angle: float = TAU * (float(index) + 0.5 * float(ring)) / float(count)
			Signals.projectile_requested.emit(ShotFactory.player_shot(_origin(), Vector2.RIGHT.rotated(angle), Db.f(spec, "damage"), params))


func _cast_chain(spec: Dictionary, aim: Vector2) -> void:
	var world: World2D = _player.get_world_2d()
	var first: Node2D = ShotFactory.nearest_enemy(world, aim, Db.f(spec, "jump_range"), [])
	if first == null or first.global_position.distance_to(_origin()) > Db.f(spec, "range"):
		first = ShotFactory.nearest_enemy(world, _origin(), Db.f(spec, "range"), [])
	if first == null:
		Signals.cast_failed.emit("ability", Db.i(spec, "slot"), "no_target")
		return
	var extra: Dictionary = {"source": Db.s(spec, "id"), "stun_sec": Db.f(spec, "stun_sec")}
	ShotFactory.chain(world, _origin(), first, Db.f(spec, "damage"), int(Db.f(spec, "jumps")), Db.f(spec, "jump_range"), extra, Db.s(spec, "color", "cyan"))


func _cast_blink(spec: Dictionary, aim: Vector2) -> void:
	var color: String = Db.s(spec, "color", "magenta")
	if bool(spec.get("origin_blast", false)):
		Signals.projectile_requested.emit(ShotFactory.player_blast(_origin(), Db.f(spec, "damage"), Db.f(spec, "radius"), color))
	var destination: Vector2 = _player.call("blink_to", aim, Db.f(spec, "range"))
	_player.call("grant_iframes", Db.f(spec, "iframes"))
	Signals.projectile_requested.emit(ShotFactory.player_blast(destination, Db.f(spec, "damage"), Db.f(spec, "radius"), color))


func _cast_spin(spec: Dictionary) -> void:
	var params: Dictionary = {
		"speed": 0.0, "radius": _area(Db.f(spec, "radius")), "lifetime": Db.f(spec, "duration"),
		"hit_interval": Db.f(spec, "hit_interval"), "pull_force": Db.f(spec, "pull_force"),
		"ghost": true, "color": Db.s(spec, "color", "magenta"), "source": Db.s(spec, "id"),
	}
	_attach(ShotFactory.player_shot(_origin(), Vector2.RIGHT, Db.f(spec, "damage"), params))


func _cast_emp(spec: Dictionary) -> void:
	var extra: Dictionary = {"slow_mult": Db.f(spec, "slow_mult", 1.0), "slow_sec": Db.f(spec, "slow_sec"), "stun_sec": Db.f(spec, "stun_sec")}
	Signals.projectile_requested.emit(ShotFactory.player_blast(_origin(), Db.f(spec, "damage"), Db.f(spec, "radius"), Db.s(spec, "color", "blue"), extra))


func _cast_homing(spec: Dictionary, aim: Vector2) -> void:
	var count: int = maxi(1, int(Db.f(spec, "count")))
	var base: float = _aim_dir(aim).angle()
	for index: int in count:
		var params: Dictionary = _bolt(spec)
		params["homing"] = true
		params["turn_rate"] = Db.f(spec, "turn_rate")
		if Db.f(spec, "blast_radius") > 0.0:
			params["blast_on_expire"] = {"damage": Db.f(spec, "damage") * Db.f(spec, "blast_damage_mult", 1.0), "radius": Db.f(spec, "blast_radius")}
		var angle: float = base + TAU * (float(index) / float(count) - 0.5) * 0.5
		Signals.projectile_requested.emit(ShotFactory.player_shot(_origin(), Vector2.RIGHT.rotated(angle), Db.f(spec, "damage"), params))


func _cast_orbit(spec: Dictionary) -> void:
	var count: int = maxi(1, int(Db.f(spec, "count")))
	for index: int in count:
		var params: Dictionary = {
			"speed": 0.0, "radius": Db.f(spec, "radius"), "lifetime": Db.f(spec, "duration"),
			"hit_interval": Db.f(spec, "hit_interval"), "orbit_radius": _area(Db.f(spec, "orbit_radius")),
			"angular_speed": Db.f(spec, "angular_speed"), "phase": TAU * float(index) / float(count),
			"ghost": true, "color": Db.s(spec, "color", "white"), "shape": "orb", "source": Db.s(spec, "id"),
			"sprite": Db.s(spec, "sprite", "blade"),
		}
		_attach(ShotFactory.player_shot(_origin(), Vector2.RIGHT, Db.f(spec, "damage"), params))


func _cast_pull(spec: Dictionary, aim: Vector2) -> void:
	var point: Vector2 = _origin() + (aim - _origin()).limit_length(Db.f(spec, "range"))
	var params: Dictionary = {
		"speed": 0.0, "radius": _area(Db.f(spec, "radius")), "lifetime": Db.f(spec, "duration"),
		"hit_interval": Db.f(spec, "hit_interval"), "pull_force": Db.f(spec, "force"), "ghost": true,
		"color": Db.s(spec, "color", "purple"), "source": Db.s(spec, "id"),
	}
	if Db.f(spec, "blast_damage") > 0.0:
		params["blast_on_expire"] = {"damage": Db.f(spec, "blast_damage"), "radius": Db.f(spec, "blast_radius")}
	Signals.projectile_requested.emit(ShotFactory.player_shot(point, Vector2.RIGHT, Db.f(spec, "damage"), params))


func _cast_buff(spec: Dictionary) -> void:
	var stats: Dictionary = {
		"attack_speed_pct": Db.f(spec, "attack_speed_pct"),
		"move_speed_pct": Db.f(spec, "move_speed_pct"),
		"damage_pct": Db.f(spec, "damage_pct"),
	}
	GameState.add_buff({
		"id": Db.s(spec, "id"), "name": Db.s(AbilitySystem.ability(Db.s(spec, "id")), "name"),
		"color": Db.s(spec, "color", "amber"), "duration_sec": Db.f(spec, "duration"),
		"stats": stats, "invuln_sec": Db.f(spec, "invuln_sec"),
	})


func use_item(slot: int, aim: Vector2) -> void:
	var spec: Dictionary = ItemSystem.try_use_active(slot)
	if not spec.is_empty():
		_player.call("animate", "cast")
		execute_item(spec, aim)


func execute_item(spec: Dictionary, aim: Vector2) -> void:
	var item_name: String = Db.s(ItemSystem.item(Db.s(spec, "id")), "name")
	match Db.s(spec, "kind"):
		"heal":
			GameState.heal_player(Db.f(spec, "amount"), "item")
		"mana":
			GameState.restore_mana(Db.f(spec, "amount"))
		"invuln":
			GameState.add_buff({"id": Db.s(spec, "id"), "name": item_name, "color": "white", "duration_sec": Db.f(spec, "duration"), "invuln_sec": Db.f(spec, "duration")})
		"shield":
			GameState.add_buff({"id": Db.s(spec, "id"), "name": item_name, "color": "blue", "duration_sec": Db.f(spec, "duration"), "shield": Db.f(spec, "amount")})
		"magnet":
			Signals.magnet_requested.emit()
		"blast_cursor":
			var point: Vector2 = _origin() + (aim - _origin()).limit_length(Db.f(spec, "range"))
			var extra: Dictionary = {"delay": Db.f(spec, "delay"), "slow_mult": Db.f(spec, "slow_mult", 1.0), "slow_sec": Db.f(spec, "slow_sec")}
			Signals.projectile_requested.emit(ShotFactory.player_blast(point, Db.f(spec, "damage"), Db.f(spec, "radius"), Db.s(spec, "color", "white"), extra))
