extends Node
## Persistent meta progression owner: banked currency, unlocked heroes, skill tree levels,
## signature item tiers, lifetime stats and purchases. Mutate only through methods; every
## mutation saves user://meta_save.json and emits Signals.meta_changed once.

const Db = preload("res://core/Db.gd")
const REASON_OK: String = ""
const REASON_MAXED: String = "maxed"
const REASON_LOCKED: String = "locked"
const REASON_CURRENCY: String = "currency"

var currency: int = 0
var unlocked_heroes: Array[String] = []
var meta_tree_nodes: Dictionary = {}
var starting_item_tiers: Dictionary = {}
var stats: Dictionary = {}
var flags: Dictionary = {}
var selected_hero: String = ""


func _ready() -> void:
	Signals.hero_selected.connect(select_hero)
	Signals.hero_unlock_requested.connect(unlock_hero)
	Signals.meta_node_purchase_requested.connect(purchase_node)
	Signals.starting_item_upgrade_requested.connect(upgrade_starting_item)
	Signals.purchase_completed.connect(_on_purchase_completed)
	Signals.ad_rewarded_completed.connect(_on_ad_rewarded)
	var data: Dictionary = SaveManager.load_meta()
	if data.is_empty():
		new_profile()
		SaveManager.write_meta(to_save_dict())
	else:
		from_save_dict(data)


func new_profile() -> void:
	currency = Db.cfg_i("meta.start_currency")
	unlocked_heroes.assign([Db.cfg_s("meta.starting_hero")])
	meta_tree_nodes = {}
	starting_item_tiers = {}
	for hero: Variant in Db.list("heroes", "heroes"):
		starting_item_tiers[Db.s(hero, "id")] = 1
	stats = _default_stats()
	flags = {"no_ads": false}
	selected_hero = Db.cfg_s("meta.starting_hero")


func _default_stats() -> Dictionary:
	return {"runs": 0, "wins": 0, "best_loop": 0, "best_time_sec": 0.0}


func emit_all() -> void:
	Signals.meta_changed.emit(snapshot())


func snapshot() -> Dictionary:
	return {
		"currency": currency,
		"unlocked_heroes": unlocked_heroes.duplicate(),
		"meta_tree_nodes": meta_tree_nodes.duplicate(),
		"starting_item_tiers": starting_item_tiers.duplicate(),
		"stats": stats.duplicate(),
		"selected_hero": selected_hero,
		"has_run_save": SaveManager.has_run_save(),
		"no_ads": bool(flags.get("no_ads", false)),
	}


func is_unlocked(hero_id: String) -> bool:
	return unlocked_heroes.has(hero_id)


func select_hero(hero_id: String) -> void:
	if not is_unlocked(hero_id):
		Signals.toast_requested.emit("Герой ещё не открыт")
		return
	selected_hero = hero_id
	_commit()


func unlock_hero(hero_id: String) -> void:
	var hero: Dictionary = Db.entry("heroes", "heroes", hero_id)
	if hero.is_empty() or is_unlocked(hero_id):
		return
	var cost: int = Db.i(hero, "unlock_cost")
	if currency < cost:
		Signals.toast_requested.emit("Не хватает кредитов: нужно %d" % cost)
		return
	currency -= cost
	unlocked_heroes.append(hero_id)
	selected_hero = hero_id
	_commit()


func node_level(node_id: String) -> int:
	return int(meta_tree_nodes.get(node_id, 0))


## REASON_OK when the next level of `node_id` can be bought right now.
func can_purchase(node_id: String) -> String:
	var node: Dictionary = Db.entry("meta_tree", "nodes", node_id)
	var level: int = node_level(node_id)
	if node.is_empty() or level >= Db.i(node, "max_level"):
		return REASON_MAXED
	if not _requirements_met(node):
		return REASON_LOCKED
	return REASON_OK if currency >= node_cost(node_id) else REASON_CURRENCY


func node_cost(node_id: String) -> int:
	var costs: Array = Db.a(Db.entry("meta_tree", "nodes", node_id), "costs")
	var level: int = node_level(node_id)
	return int(Db.num(costs[level])) if level < costs.size() else 0


func _requirements_met(node: Dictionary) -> bool:
	var requires: Array = Db.a(node, "requires")
	if requires.is_empty():
		return true
	for id: Variant in requires:
		if node_level(str(id)) > 0:
			return true
	return false


func purchase_node(node_id: String) -> void:
	var reason: String = can_purchase(node_id)
	if reason != REASON_OK:
		Signals.toast_requested.emit(_reason_text(reason))
		return
	currency -= node_cost(node_id)
	meta_tree_nodes[node_id] = node_level(node_id) + 1
	_commit()


func _reason_text(reason: String) -> String:
	match reason:
		REASON_MAXED:
			return "Узел прокачан до предела"
		REASON_LOCKED:
			return "Сначала откройте предыдущий узел"
	return "Не хватает кредитов"


func starting_item_tier(hero_id: String) -> int:
	return int(starting_item_tiers.get(hero_id, 1))


## Cost of the next signature item tier, or -1 at max tier.
func starting_item_upgrade_cost(hero_id: String) -> int:
	var costs: Array = Db.a(Db.table("items"), "signature_upgrade_costs")
	var tier: int = starting_item_tier(hero_id)
	return int(Db.num(costs[tier - 1])) if tier - 1 < costs.size() else -1


func upgrade_starting_item(hero_id: String) -> void:
	var cost: int = starting_item_upgrade_cost(hero_id)
	if cost < 0:
		Signals.toast_requested.emit("Предмет уже максимального уровня")
		return
	if currency < cost:
		Signals.toast_requested.emit("Не хватает кредитов: нужно %d" % cost)
		return
	currency -= cost
	starting_item_tiers[hero_id] = starting_item_tier(hero_id) + 1
	_commit()


## Summed stat bonuses of every bought skill tree level.
func meta_bonuses() -> Dictionary:
	var out: Dictionary = {}
	for node_id: Variant in meta_tree_nodes.keys():
		var level: int = node_level(str(node_id))
		var node_stats: Dictionary = Db.d(Db.entry("meta_tree", "nodes", str(node_id)), "stats")
		for stat: Variant in node_stats.keys():
			out[stat] = Db.f(out, str(stat)) + Db.f(node_stats, str(stat)) * float(level)
	return out


## Banks a finished run. summary: {victory, currency, elapsed_sec, loop_count}. Returns banked.
func bank_run(summary: Dictionary) -> int:
	var victory: bool = bool(summary.get("victory", false))
	var earned: int = Db.i(summary, "currency")
	var banked: int = earned if victory else floori(float(earned) * Db.cfg_f("meta.defeat_keep_fraction"))
	currency += banked
	stats["runs"] = Db.i(stats, "runs") + 1
	if victory:
		stats["wins"] = Db.i(stats, "wins") + 1
	stats["best_loop"] = maxi(Db.i(stats, "best_loop"), Db.i(summary, "loop_count"))
	stats["best_time_sec"] = maxf(Db.f(stats, "best_time_sec"), Db.f(summary, "elapsed_sec"))
	_commit()
	return banked


func _on_purchase_completed(sku: String) -> void:
	var grant: Dictionary = Db.d(IAP.product(sku), "grant")
	currency += Db.i(grant, "currency")
	for hero: Variant in Db.a(grant, "unlock_heroes"):
		if not is_unlocked(str(hero)):
			unlocked_heroes.append(str(hero))
	if bool(grant.get("no_ads", false)):
		flags["no_ads"] = true
	_commit()
	Signals.toast_requested.emit("Покупка получена")


func _on_ad_rewarded(placement: String) -> void:
	var reward: Dictionary = Db.d(Db.d(Db.d(Db.table("iap"), "ads"), "rewarded"), placement)
	if reward.is_empty():
		return
	currency += Db.i(reward, "currency")
	_commit()
	Signals.toast_requested.emit("+%d кредитов" % Db.i(reward, "currency"))


func _commit() -> void:
	SaveManager.write_meta(to_save_dict())
	emit_all()


func to_save_dict() -> Dictionary:
	return {
		"version": Db.cfg_i("save_version"),
		"currency": currency,
		"unlocked_heroes": unlocked_heroes.duplicate(),
		"meta_tree_nodes": meta_tree_nodes.duplicate(),
		"starting_item_tiers": starting_item_tiers.duplicate(),
		"stats": stats.duplicate(),
		"selected_hero": selected_hero,
		"flags": flags.duplicate(),
	}


func from_save_dict(data: Dictionary) -> void:
	new_profile()
	currency = maxi(0, Db.i(data, "currency"))
	var heroes: Array[String] = []
	for id: Variant in Db.a(data, "unlocked_heroes"):
		if not Db.entry("heroes", "heroes", str(id)).is_empty() and not heroes.has(str(id)):
			heroes.append(str(id))
	if not heroes.is_empty():
		unlocked_heroes = heroes
	for node_id: Variant in Db.d(data, "meta_tree_nodes").keys():
		meta_tree_nodes[str(node_id)] = Db.i(Db.d(data, "meta_tree_nodes"), str(node_id))
	for hero_id: Variant in Db.d(data, "starting_item_tiers").keys():
		starting_item_tiers[str(hero_id)] = maxi(1, Db.i(Db.d(data, "starting_item_tiers"), str(hero_id), 1))
	stats.merge(Db.d(data, "stats"), true)
	flags.merge(Db.d(data, "flags"), true)
	var hero: String = Db.s(data, "selected_hero")
	selected_hero = hero if is_unlocked(hero) else unlocked_heroes[0]
