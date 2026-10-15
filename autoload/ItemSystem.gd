extends Node
## Item rules: passive stacking (linear or per-stack table), signature item tiers, on-hit and
## on-kill effects, crafting recipes, rarity rolls and active item cooldowns / mana costs.
## GameState owns the item arrays; the mutating helpers here receive them as arguments.

const Db = preload("res://core/Db.gd")
const TYPE_ACTIVE: String = "active"
const KIND_ITEM: String = "item"
const PERCENT: float = 100.0
const MSEC: float = 1000.0

var _ready_at: Dictionary = {}


func item(id: String) -> Dictionary:
	return Db.entry("items", "items", id)


func is_active(id: String) -> bool:
	return Db.s(item(id), "type") == TYPE_ACTIVE


func rarities() -> Array:
	return Db.list("items", "rarities")


func rarity_index(id: String) -> int:
	var rarity_id: String = Db.s(item(id), "rarity")
	var list: Array = rarities()
	for index: int in list.size():
		if Db.s(list[index], "id") == rarity_id:
			return index
	return 0


func rarity_of(id: String) -> Dictionary:
	var list: Array = rarities()
	return list[rarity_index(id)] if not list.is_empty() else {}


func stacks_of(passives: Array, id: String) -> int:
	for entry: Variant in passives:
		if Db.s(entry, "id") == id:
			return Db.i(entry, "stacks")
	return 0


## Duplicate passive -> stack +1 (Risk of Rain rule).
func add_passive(passives: Array, id: String) -> void:
	for entry: Variant in passives:
		if Db.s(entry, "id") == id:
			(entry as Dictionary)["stacks"] = Db.i(entry, "stacks") + 1
			return
	passives.append({"id": id, "stacks": 1})


func remove_stack(passives: Array, id: String) -> bool:
	for index: int in passives.size():
		var entry: Dictionary = passives[index]
		if Db.s(entry, "id") != id:
			continue
		entry["stacks"] = Db.i(entry, "stacks") - 1
		if Db.i(entry, "stacks") <= 0:
			passives.remove_at(index)
		return true
	return false


## Summed stat bonuses of all passives. tiers: {signature_item_id: tier 1..5}.
func stat_bonus(passives: Array, tiers: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for entry: Variant in passives:
		var id: String = Db.s(entry, "id")
		var data: Dictionary = item(id)
		var tier_mult: float = signature_mult(int(tiers.get(id, 1))) if bool(data.get("signature", false)) else 1.0
		var stats: Dictionary = Db.d(data, "stats")
		var table: Dictionary = Db.d(data, "stack_table")
		for stat: Variant in stats.keys():
			var value: float = stacked_value(Db.f(stats, str(stat)), Db.a(table, str(stat)), Db.i(entry, "stacks"))
			out[stat] = Db.f(out, str(stat)) + value * tier_mult
	return out


## Linear stacking, or a per-stack table that keeps its last step past the end.
func stacked_value(base: float, table: Array, stacks: int) -> float:
	if stacks <= 0:
		return 0.0
	if table.is_empty():
		return base * float(stacks)
	if stacks <= table.size():
		return Db.num(table[stacks - 1])
	var last: float = Db.num(table[table.size() - 1])
	var previous: float = Db.num(table[table.size() - 2]) if table.size() > 1 else 0.0
	return last + (last - previous) * float(stacks - table.size())


func signature_mult(tier: int) -> float:
	var scaling: Array = Db.a(Db.table("items"), "signature_tier_scaling")
	if scaling.is_empty():
		return 1.0
	return Db.num(scaling[clampi(tier, 1, scaling.size()) - 1], 1.0)


## On-hit effects with chance scaled by stacks (capped at 1).
func on_hit_effects(passives: Array) -> Array:
	return _effects(passives, "on_hit")


## On-kill effects with amount and chance scaled by stacks.
func on_kill_effects(passives: Array) -> Array:
	return _effects(passives, "on_kill")


func _effects(passives: Array, key: String) -> Array:
	var out: Array = []
	for entry: Variant in passives:
		var effect: Dictionary = Db.d(item(Db.s(entry, "id")), key)
		if effect.is_empty():
			continue
		var stacks: int = maxi(1, Db.i(entry, "stacks"))
		var scaled: Dictionary = effect.duplicate()
		if effect.has("chance"):
			scaled["chance"] = minf(1.0, Db.f(effect, "chance") * float(stacks))
		if effect.has("amount"):
			scaled["amount"] = Db.f(effect, "amount") * float(stacks)
		out.append(scaled)
	return out


## Recipes whose inputs are all owned (two equal inputs need two stacks).
func available_recipes(passives: Array) -> Array:
	var out: Array = []
	for recipe: Variant in Db.list("items", "recipes"):
		if _can_craft(passives, recipe):
			out.append(recipe)
	return out


func _can_craft(passives: Array, recipe: Dictionary) -> bool:
	var need: Dictionary = {}
	for input: Variant in Db.a(recipe, "inputs"):
		need[str(input)] = int(need.get(str(input), 0)) + 1
	for id: Variant in need.keys():
		if stacks_of(passives, str(id)) < int(need[id]):
			return false
	return not need.is_empty()


## Consumes the inputs of `recipe_id` from `passives`; returns the output id or "".
func craft(passives: Array, recipe_id: String) -> String:
	var recipe: Dictionary = Db.entry("items", "recipes", recipe_id)
	if recipe.is_empty() or not _can_craft(passives, recipe):
		return ""
	for input: Variant in Db.a(recipe, "inputs"):
		remove_stack(passives, str(input))
	return Db.s(recipe, "output")


## Rolls a droppable item id. context: {min_rarity, luck_pct, allow_limit_break, allow_active}.
func roll_item(rng: RandomNumberGenerator, context: Dictionary) -> String:
	var weights: Array = _rarity_weights(context)
	for _attempt: int in weights.size():
		var index: int = LootRoller.roll_weighted(rng, weights)
		if index < 0:
			return ""
		var pool: Array = _pool(index, context)
		if not pool.is_empty():
			return str(LootRoller.pick(rng, pool))
		weights[index] = 0.0
	return ""


func _rarity_weights(context: Dictionary) -> Array:
	var step: float = Db.f(Db.table("items"), "luck_weight_step")
	var luck: float = Db.f(context, "luck_pct") / PERCENT
	var min_rarity: int = Db.i(context, "min_rarity")
	var weights: Array = []
	for index: int in rarities().size():
		var base: float = Db.f(rarities()[index], "weight")
		weights.append(0.0 if index < min_rarity else base * (1.0 + luck * step * float(index)))
	return weights


func _pool(rarity: int, context: Dictionary) -> Array:
	var rarity_id: String = Db.s(rarities()[rarity], "id")
	var out: Array = []
	for data: Variant in Db.list("items", "items"):
		if Db.s(data, "rarity") == rarity_id and _droppable(data, context):
			out.append(Db.s(data, "id"))
	return out


func _droppable(data: Dictionary, context: Dictionary) -> bool:
	if bool(data.get("craft_only", false)) or bool(data.get("signature", false)):
		return false
	if data.has("limit_break") and not bool(context.get("allow_limit_break", false)):
		return false
	return Db.s(data, "type") != TYPE_ACTIVE or bool(context.get("allow_active", true))


## Checks cooldown and mana for the active item in `slot`; returns its effect spec or {}.
func try_use_active(slot: int) -> Dictionary:
	var id: String = GameState.active_in_slot(slot)
	if id.is_empty():
		return {}
	var spec: Dictionary = Db.d(item(id), "active")
	var now: int = TimeService.run_msec()
	if now < int(_ready_at.get(slot, 0)):
		Signals.cast_failed.emit(KIND_ITEM, slot, "cooldown")
		return {}
	if not GameState.spend_mana(Db.f(spec, "mana_cost")):
		Signals.cast_failed.emit(KIND_ITEM, slot, "mana")
		return {}
	var cooldown: float = Db.f(spec, "cooldown") * GameState.stat("cooldown_mult", 1.0)
	_ready_at[slot] = now + int(cooldown * MSEC)
	Signals.item_cooldown_started.emit(slot, cooldown)
	var out: Dictionary = spec.duplicate()
	out["id"] = id
	out["slot"] = slot
	return out


func cooldown_left(slot: int) -> float:
	return maxf(0.0, TimeService.until_sec(int(_ready_at.get(slot, 0))))


func reset_cooldowns() -> void:
	_ready_at = {}
