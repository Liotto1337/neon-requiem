extends Node
## PURE damage maths: outgoing hits, crits, armor, shields, lifesteal, thorns, heals.
## Zero node refs, zero GameState refs: every input arrives as an argument, so callers pass
## the stat dictionaries and the random roll they drew from GameState.rng.

const PERCENT: float = 100.0


## Outgoing hit from `base` damage. stats: {damage_mult, crit_chance (percent), crit_mult}.
## crit_roll: uniform 0..1 drawn by the caller.
func outgoing(base: float, stats: Dictionary, crit_roll: float) -> Dictionary:
	var crit: bool = crit_roll * PERCENT < float(stats.get("crit_chance", 0.0))
	var amount: float = maxf(0.0, base) * float(stats.get("damage_mult", 1.0))
	if crit:
		amount *= float(stats.get("crit_mult", 1.0))
	return {"amount": amount, "crit": crit}


## Applies a hit to a target. target: {shield, armor, armor_k, damage_taken_mult}.
## Shield absorbs first, the rest goes to HP.
func apply_to_target(amount: float, target: Dictionary) -> Dictionary:
	var scaled: float = maxf(0.0, amount) * float(target.get("damage_taken_mult", 1.0))
	var armor_k: float = maxf(1.0, float(target.get("armor_k", 1.0)))
	var armor: float = maxf(0.0, float(target.get("armor", 0.0)))
	scaled *= armor_k / (armor_k + armor)
	var shield: float = maxf(0.0, float(target.get("shield", 0.0)))
	var absorbed: float = minf(shield, scaled)
	return {
		"total": scaled,
		"shield_absorbed": absorbed,
		"shield_left": shield - absorbed,
		"hp_damage": scaled - absorbed,
	}


func lifesteal(hp_damage: float, lifesteal_pct: float) -> float:
	return maxf(0.0, hp_damage) * maxf(0.0, lifesteal_pct) / PERCENT


func thorns(incoming: float, thorns_pct: float) -> float:
	return maxf(0.0, incoming) * maxf(0.0, thorns_pct) / PERCENT


## Heal after the receiver's heal multiplier; 0 when healing is blocked.
func heal(amount: float, heal_mult: float, blocked: bool) -> float:
	return 0.0 if blocked else maxf(0.0, amount) * maxf(0.0, heal_mult)


## Damage over time for `dt` seconds at `dps`.
func dot(dps: float, dt: float) -> float:
	return maxf(0.0, dps) * maxf(0.0, dt)
