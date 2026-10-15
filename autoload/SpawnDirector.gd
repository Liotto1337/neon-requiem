extends Node
## PURE spawn schedule. Input: location entry, enemy table, difficulty table, tier, time
## window (t_from, t_to] in location seconds and the run seed. Output: spawn events.
## Zero node refs, zero GameState refs, no RNG objects: randomness is a hash of
## (seed, location, pulse, slot), so the same inputs always produce the same events.
##
## Event shapes:
##   {"type": "enemy", "enemy_id": String, "count": int, "formation": "scatter"|"ring", "salt": int, "t": float}
##   {"type": "miniboss" | "boss", "boss_id": String, "t": float}

const HASH_MASK: int = 0x7FFFFFFF
const TYPE_ENEMY: String = "enemy"
const TYPE_MINIBOSS: String = "miniboss"
const TYPE_BOSS: String = "boss"
const FORMATION_SCATTER: String = "scatter"
const FORMATION_RING: String = "ring"
const SALT_STRIDE: int = 1000
const BURST_SLOT: int = 999


func events_between(location: Dictionary, enemies: Dictionary, difficulty: Dictionary, tier: int, t_from: float, t_to: float, seed_value: int) -> Array:
	var events: Array = []
	var spawn: Dictionary = difficulty.get("spawn", {})
	var pulse: float = float(spawn.get("pulse_sec", 0.0))
	if pulse > 0.0 and t_to > t_from:
		var first: int = floori(t_from / pulse) + 1
		var last: int = floori(t_to / pulse)
		for k: int in range(maxi(first, 1), last + 1):
			events.append_array(_pulse_events(location, enemies, difficulty, tier, k, seed_value, float(k) * pulse))
	events.append_array(boss_events(location, t_from, t_to))
	return events


## Miniboss / boss events whose spawn time falls inside (t_from, t_to].
func boss_events(location: Dictionary, t_from: float, t_to: float) -> Array:
	var out: Array = []
	var mini_at: float = float(location.get("miniboss_at_sec", -1.0))
	var boss_at: float = float(location.get("boss_at_sec", -1.0))
	if t_from < mini_at and mini_at <= t_to:
		out.append({"type": TYPE_MINIBOSS, "boss_id": str(location.get("miniboss", "")), "t": mini_at})
	if t_from < boss_at and boss_at <= t_to:
		out.append({"type": TYPE_BOSS, "boss_id": str(location.get("boss", "")), "t": boss_at})
	return out


func _pulse_events(location: Dictionary, enemies: Dictionary, difficulty: Dictionary, tier: int, k: int, seed_value: int, t: float) -> Array:
	var spawn: Dictionary = difficulty.get("spawn", {})
	var scale: float = 1.0 + float(difficulty.get("count_per_tier", 0.0)) * float(tier)
	var raw: float = float(spawn.get("base_count", 0.0)) * scale
	var count: int = floori(raw)
	var loc_id: String = str(location.get("id", ""))
	if _unit(seed_value, loc_id, k, 0) < raw - float(count):
		count += 1
	var out: Array = []
	for slot: int in count:
		var enemy_id: String = _pick_enemy(location, enemies, spawn, tier, _unit(seed_value, loc_id, k, slot + 1))
		if not enemy_id.is_empty():
			out.append(_enemy_event(enemy_id, 1, FORMATION_SCATTER, k * SALT_STRIDE + slot, t))
	var every: int = int(spawn.get("burst_every_pulses", 0))
	if every > 0 and k % every == 0:
		var burst_id: String = _pick_enemy(location, enemies, spawn, tier, _unit(seed_value, loc_id, k, BURST_SLOT))
		var burst: int = roundi(float(spawn.get("burst_count", 0.0)) * scale)
		if not burst_id.is_empty() and burst > 0:
			out.append(_enemy_event(burst_id, burst, FORMATION_RING, k * SALT_STRIDE + BURST_SLOT, t))
	return out


func _enemy_event(enemy_id: String, count: int, formation: String, salt: int, t: float) -> Dictionary:
	return {"type": TYPE_ENEMY, "enemy_id": enemy_id, "count": count, "formation": formation, "salt": salt, "t": t}


## Weighted pick over the location's unique enemies (boosted) and the shared common pool.
func _pick_enemy(location: Dictionary, enemies: Dictionary, spawn: Dictionary, tier: int, roll: float) -> String:
	var pool: Array = _pool(location, enemies, spawn, tier)
	var total: float = 0.0
	for entry: Dictionary in pool:
		total += float(entry["weight"])
	if total <= 0.0:
		return ""
	var value: float = roll * total
	for entry: Dictionary in pool:
		value -= float(entry["weight"])
		if value < 0.0:
			return str(entry["id"])
	return str((pool[pool.size() - 1] as Dictionary)["id"])


func _pool(location: Dictionary, enemies: Dictionary, spawn: Dictionary, tier: int) -> Array:
	var by_id: Dictionary = {}
	for enemy: Variant in enemies.get("enemies", []):
		by_id[str((enemy as Dictionary).get("id", ""))] = enemy
	var out: Array = []
	var unique_mult: float = float(spawn.get("unique_weight_mult", 1.0))
	for id: Variant in location.get("enemies", []):
		_add_to_pool(out, by_id.get(str(id), {}), tier, unique_mult)
	for id: Variant in enemies.get("common", []):
		_add_to_pool(out, by_id.get(str(id), {}), tier, 1.0)
	return out


func _add_to_pool(pool: Array, enemy: Dictionary, tier: int, weight_mult: float) -> void:
	if enemy.is_empty() or int(enemy.get("min_tier", 0)) > tier:
		return
	pool.append({"id": str(enemy.get("id", "")), "weight": float(enemy.get("weight", 0.0)) * weight_mult})


func _unit(seed_value: int, tag: String, k: int, slot: int) -> float:
	return float(hash([seed_value, tag, k, slot]) & HASH_MASK) / float(HASH_MASK)
