extends Node
## Seeded loot rolls. Owns no RNG: every call takes GameState's single seeded stream, so the
## loot sequence is reproducible per run seed.

const Db = preload("res://core/Db.gd")


func roll_weighted(rng: RandomNumberGenerator, weights: Array) -> int:
	var total: float = 0.0
	for weight: Variant in weights:
		total += maxf(0.0, Db.num(weight))
	if total <= 0.0:
		return -1
	var roll: float = rng.randf() * total
	for index: int in weights.size():
		roll -= maxf(0.0, Db.num(weights[index]))
		if roll < 0.0:
			return index
	return weights.size() - 1


## Random element of `entries` weighted by entries[i][weight_key]; {} when empty.
func pick_weighted(rng: RandomNumberGenerator, entries: Array, weight_key: String) -> Dictionary:
	var weights: Array = []
	for entry: Variant in entries:
		weights.append(Db.f(entry, weight_key, 1.0) if entry is Dictionary else 0.0)
	var index: int = roll_weighted(rng, weights)
	return entries[index] if index >= 0 else {}


func pick(rng: RandomNumberGenerator, items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[rng.randi_range(0, items.size() - 1)]


func shuffled(rng: RandomNumberGenerator, items: Array) -> Array:
	var out: Array = items.duplicate()
	for index: int in range(out.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var tmp: Variant = out[index]
		out[index] = out[other]
		out[other] = tmp
	return out


## Drops for a killed enemy: [{kind, value}]. `scaling` comes from WaveDirector.scaling().
func roll_drops(rng: RandomNumberGenerator, enemy: Dictionary, scaling: Dictionary, elite: bool) -> Array:
	var elites: Dictionary = Db.d(Db.table("elites"), "base")
	var xp: float = Db.f(enemy, "xp") * Db.f(scaling, "xp", 1.0)
	var currency_chance: float = Db.f(enemy, "currency_chance")
	var currency: float = Db.f(enemy, "currency")
	if elite:
		xp *= Db.f(elites, "xp_mult", 1.0)
		currency_chance = maxf(currency_chance, Db.f(elites, "currency_chance"))
		currency *= Db.f(elites, "currency_mult", 1.0)
	var drops: Array = [{"kind": "xp", "value": xp}]
	if rng.randf() < currency_chance:
		drops.append({"kind": "currency", "value": currency})
	if rng.randf() < Db.f(enemy, "heal_chance"):
		drops.append({"kind": "heal", "value": Db.f(enemy, "heal")})
	return drops
