extends Node
## Ability rules: templates from data/abilities.json, level scaling 1..5 (level 5 merges the
## "ultimate" block), mana costs and per-slot cooldowns on the run clock, draft rolls.

const Db = preload("res://core/Db.gd")
const KIND_ABILITY: String = "ability"
const MSEC: float = 1000.0

var _ready_at: Dictionary = {}


func ability(id: String) -> Dictionary:
	return Db.entry("abilities", "abilities", id)


func max_level() -> int:
	return Db.i(Db.table("abilities"), "max_level", 1)


## Effective numbers at `level`: base + per_level * (level - 1); max level adds "ultimate".
func level_stats(id: String, level: int) -> Dictionary:
	var data: Dictionary = ability(id)
	var out: Dictionary = Db.d(data, "base").duplicate()
	var per_level: Dictionary = Db.d(data, "per_level")
	var clamped: int = clampi(level, 1, max_level())
	for key: Variant in per_level.keys():
		out[key] = Db.f(out, str(key)) + Db.f(per_level, str(key)) * float(clamped - 1)
	var ultimate: bool = clamped >= max_level()
	if ultimate:
		var extra: Dictionary = Db.d(data, "ultimate")
		for key: Variant in extra.keys():
			out[key] = extra[key]
	out["ultimate"] = ultimate
	out["id"] = id
	out["level"] = clamped
	out["kind"] = Db.s(data, "kind")
	out["color"] = Db.s(data, "color", "white")
	return out


## Checks cooldown and mana for the ability in `slot`; returns its level stats or {}.
func try_cast(slot: int) -> Dictionary:
	var entry: Dictionary = GameState.ability_in_slot(slot)
	if entry.is_empty():
		return {}
	var stats: Dictionary = level_stats(Db.s(entry, "id"), Db.i(entry, "level", 1))
	var now: int = TimeService.run_msec()
	if now < int(_ready_at.get(slot, 0)):
		Signals.cast_failed.emit(KIND_ABILITY, slot, "cooldown")
		return {}
	if not GameState.spend_mana(Db.f(stats, "mana_cost")):
		Signals.cast_failed.emit(KIND_ABILITY, slot, "mana")
		return {}
	var cooldown: float = Db.f(stats, "cooldown") * GameState.stat("cooldown_mult", 1.0)
	_ready_at[slot] = now + int(cooldown * MSEC)
	Signals.ability_cooldown_started.emit(slot, cooldown)
	stats["slot"] = slot
	return stats


func cooldown_left(slot: int) -> float:
	return maxf(0.0, TimeService.until_sec(int(_ready_at.get(slot, 0))))


func reset_cooldowns() -> void:
	_ready_at = {}


## New ability id for the level-up draft, weighted towards the hero class; "" when none left.
func roll_new_ability(rng: RandomNumberGenerator, owned: Array, hero_class: String) -> String:
	var candidates: Array = []
	var bias: float = Db.cfg_f("levelup.class_bias")
	for data: Variant in Db.list("abilities", "abilities"):
		var id: String = Db.s(data, "id")
		if owned.has(id):
			continue
		var classes: Array = Db.a(data, "classes")
		candidates.append({"id": id, "weight": bias if classes.has(hero_class) else 1.0})
	return Db.s(LootRoller.pick_weighted(rng, candidates, "weight"), "id")


## Owned ability entries that can still level up.
func upgradable(abilities: Array) -> Array:
	var out: Array = []
	for entry: Variant in abilities:
		if Db.i(entry, "level", 1) < max_level():
			out.append(entry)
	return out
