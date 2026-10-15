extends Node
## PURE difficulty rules: tier steps, tier scaling of enemies and bosses, alive caps, loop
## parameters and elite modifier rolls per spawn event. Zero node refs, zero GameState refs;
## the tables (difficulty.json, elites.json) arrive as arguments.

const HASH_MASK: int = 0x7FFFFFFF
const ELITE_SALT: String = "elite"
const DOUBLE_SALT: String = "elite_double"
const TRIPLE_SALT: String = "elite_triple"
const PICK_SALT: String = "elite_pick"


func next_tier(tier: int, cap: int) -> int:
	return mini(tier + 1, cap) if cap > 0 else tier + 1


## Multipliers for regular enemies at `tier` with the loop `multiplier`.
func scaling(tier: int, multiplier: float, difficulty: Dictionary) -> Dictionary:
	var t: float = float(maxi(0, tier))
	return {
		"hp": (1.0 + float(difficulty.get("hp_per_tier", 0.0)) * t) * multiplier,
		"damage": (1.0 + float(difficulty.get("damage_per_tier", 0.0)) * t) * multiplier,
		"speed": 1.0 + float(difficulty.get("speed_per_tier", 0.0)) * t,
		"xp": 1.0 + float(difficulty.get("xp_per_tier", 0.0)) * t,
	}


func boss_scaling(tier: int, multiplier: float, difficulty: Dictionary) -> Dictionary:
	var t: float = float(maxi(0, tier))
	return {
		"hp": (1.0 + float(difficulty.get("boss_hp_per_tier", 0.0)) * t) * multiplier,
		"damage": (1.0 + float(difficulty.get("boss_damage_per_tier", 0.0)) * t) * multiplier,
		"speed": 1.0,
		"xp": 1.0,
	}


func max_alive(tier: int, difficulty: Dictionary) -> int:
	var spawn: Dictionary = difficulty.get("spawn", {})
	var value: float = float(spawn.get("max_alive_base", 0.0)) + float(spawn.get("max_alive_per_tier", 0.0)) * float(tier)
	return mini(int(value), int(spawn.get("max_alive_cap", value)))


## Loop step: multiplier grows by the factor and the tier cap becomes current tier + bonus %.
func loop_params(tier: int, multiplier: float, difficulty: Dictionary) -> Dictionary:
	var loop: Dictionary = difficulty.get("loop", {})
	return {
		"multiplier": multiplier * float(loop.get("multiplier_factor", 1.0)),
		"tier_cap": maxi(tier, ceili(float(tier) * (1.0 + float(loop.get("tier_cap_bonus", 0.0))))),
	}


## Elite modifier ids for one spawned enemy (empty = regular enemy). Deterministic per
## (seed, salt), so a reload produces the same elites for the same spawn events.
func roll_elite_mods(seed_value: int, salt: int, tier: int, elites: Dictionary, difficulty: Dictionary) -> Array:
	var rules: Dictionary = difficulty.get("elites", {})
	var chance: float = minf(float(rules.get("max_chance", 0.0)),
		float(rules.get("base_chance", 0.0)) + float(rules.get("chance_per_tier", 0.0)) * float(tier))
	if unit(seed_value, ELITE_SALT, salt) >= chance:
		return []
	var count: int = 1
	if tier >= int(rules.get("double_from_tier", 0)) and unit(seed_value, DOUBLE_SALT, salt) < float(rules.get("double_chance", 0.0)):
		count = 2
	if tier >= int(rules.get("triple_from_tier", 0)) and unit(seed_value, TRIPLE_SALT, salt) < float(rules.get("triple_chance", 0.0)):
		count = 3
	return pick_mods(seed_value, salt, count, elites.get("modifiers", []))


## `count` distinct modifier ids, weighted, without replacement.
func pick_mods(seed_value: int, salt: int, count: int, modifiers: Array) -> Array:
	var pool: Array = modifiers.duplicate()
	var out: Array = []
	for n: int in count:
		if pool.is_empty():
			break
		var total: float = 0.0
		for mod: Variant in pool:
			total += float((mod as Dictionary).get("weight", 0.0))
		var roll: float = unit(seed_value, PICK_SALT, salt * 10 + n) * total
		var index: int = 0
		while index < pool.size() - 1 and roll >= float((pool[index] as Dictionary).get("weight", 0.0)):
			roll -= float((pool[index] as Dictionary).get("weight", 0.0))
			index += 1
		out.append(str((pool[index] as Dictionary).get("id", "")))
		pool.remove_at(index)
	return out


## Deterministic uniform 0..1 from a seed, a tag and an index.
func unit(seed_value: int, tag: String, index: int) -> float:
	return float(hash([seed_value, tag, index]) & HASH_MASK) / float(HASH_MASK)
