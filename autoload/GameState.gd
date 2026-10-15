extends Node
## Run state owner: resources, abilities, items, buffs, difficulty and the location chain.
## Mutate only through methods; each public mutation marks the changed domains and flushes
## them once at the end (one signal per domain per change). Owns the single seeded
## RandomNumberGenerator used by all gameplay code.

const Db = preload("res://core/Db.gd")
const ShotFactory = preload("res://scenes/entities/components/ShotFactory.gd")
const MSEC: float = 1000.0
const PERCENT: float = 100.0
const DOMAINS: Array[String] = [
	"resources", "stats", "abilities", "items", "slots", "difficulty", "location", "buffs",
]
const KIND_MINIBOSS: String = "miniboss"
const KIND_BOSS: String = "boss"
const SOURCE_REGEN: String = "regen"
const SOURCE_LIFESTEAL: String = "lifesteal"
const OPTION_NEW: String = "new_ability"
const OPTION_UPGRADE: String = "upgrade_ability"
const OPTION_ITEM: String = "item"
const OPTION_CURRENCY: String = "currency"

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var run_active: bool = false
var seed_value: int = 0
var run_start_unix: int = 0
var hero_id: String = ""
var difficulty_tier: int = 0
var tier_cap: int = 0
var difficulty_multiplier: float = 1.0
var next_tier_at_sec: float = 0.0
var loop_count: int = 0
var location_order: Array[String] = []
var location_index: int = 0
var elapsed_sec: float = 0.0
var location_elapsed_sec: float = 0.0
var resources: Dictionary = {}
## [{id, level, slot}]
var abilities: Array = []
## [{id, stacks}]
var items_passive: Array = []
## [{id, slot}]
var items_active: Array = []
var slot_limits: Dictionary = {}
var flags: Dictionary = {}
var kills: int = 0
## [{id, name, color, stats, shield, until_msec}]
var buffs: Array = []

var _stats: Dictionary = {}
var _dirty: Dictionary = {}
var _session_live: bool = false
var _pending_levelups: int = 0
var _levelup_options: Array = []
var _antiheal_until_msec: int = 0
var _antiheal_shown: bool = false
var _invuln_until_msec: int = 0
var _shield_hp: float = 0.0
var _last_autosave_msec: int = 0
var _last_timer_second: int = -1


# =====================================================================
# Lifecycle
# =====================================================================

func _ready() -> void:
	Signals.run_start_requested.connect(start_new_run)
	Signals.run_continue_requested.connect(continue_saved_run)
	Signals.hero_draft_chosen.connect(apply_hero_draft)
	Signals.levelup_option_chosen.connect(choose_levelup)
	Signals.craft_requested.connect(craft)
	Signals.loop_choice_made.connect(_on_loop_choice)
	Signals.game_over_confirmed.connect(_on_game_over_confirmed)
	Signals.return_to_hub_requested.connect(suspend_run)


func start_new_run(new_hero_id: String) -> void:
	if not MetaState.is_unlocked(new_hero_id):
		Signals.toast_requested.emit("Герой ещё не открыт")
		return
	rng.randomize()
	seed_value = rng.randi()
	rng.seed = seed_value
	hero_id = new_hero_id
	run_start_unix = TimeService.now_unix()
	_reset_run_counters()
	location_order = _build_location_order(false)
	abilities = _starting_abilities()
	_recompute_stats()
	resources = {
		"hp": stat("hp_max"), "hp_max": stat("hp_max"),
		"mana": stat("mana_max"), "mana_max": stat("mana_max"),
		"xp": 0.0, "level": 1, "currency": int(stat("start_currency")),
	}
	run_active = true
	save_run()
	Signals.run_started.emit(summary(false))


func _reset_run_counters() -> void:
	var difficulty: Dictionary = Db.table("difficulty")
	difficulty_tier = 0
	tier_cap = Db.i(difficulty, "base_tier_cap")
	difficulty_multiplier = 1.0
	next_tier_at_sec = Db.f(difficulty, "tier_interval_sec")
	loop_count = 0
	location_index = 0
	elapsed_sec = 0.0
	location_elapsed_sec = 0.0
	items_passive = []
	items_active = []
	buffs = []
	kills = 0
	slot_limits = {"abilities": Db.cfg_i("slots.abilities"), "active_items": Db.cfg_i("slots.active_items")}
	flags = {"limit_breaks_used": 0, "draft_done": false, "miniboss_done": false, "boss_done": false}
	_pending_levelups = 0
	_levelup_options = []
	_shield_hp = 0.0
	_antiheal_until_msec = 0
	_invuln_until_msec = 0
	AbilitySystem.reset_cooldowns()
	ItemSystem.reset_cooldowns()


## Random non-final start (or the loop start), chain through the rest, final location last.
func _build_location_order(from_loop_start: bool) -> Array[String]:
	var table: Dictionary = Db.table("locations")
	var final_id: String = Db.s(table, "final")
	var chain: Array[String] = []
	for entry: Variant in Db.list("locations", "locations"):
		if Db.s(entry, "id") != final_id:
			chain.append(Db.s(entry, "id"))
	var out: Array[String] = []
	if not chain.is_empty():
		var start: int = rng.randi_range(0, chain.size() - 1)
		if from_loop_start:
			start = maxi(0, chain.find(Db.s(table, "loop_start")))
		for offset: int in chain.size():
			out.append(chain[(start + offset) % chain.size()])
	out.append(final_id)
	return out


func _starting_abilities() -> Array:
	var out: Array = []
	var ids: Array = Db.a(hero(), "abilities")
	for slot: int in mini(ids.size(), Db.cfg_i("slots.abilities")):
		out.append({"id": str(ids[slot]), "level": 1, "slot": slot})
	return out


func continue_saved_run() -> void:
	var data: Dictionary = SaveManager.load_run()
	if data.is_empty() or Db.entry("heroes", "heroes", Db.s(data, "hero_id")).is_empty():
		Signals.toast_requested.emit("Сохранённый забег не найден")
		SaveManager.delete_run()
		MetaState.emit_all()
		return
	from_save_dict(data)
	AbilitySystem.reset_cooldowns()
	ItemSystem.reset_cooldowns()
	run_active = true
	Signals.run_started.emit(summary(false))


## Called by the Run scene once the location and player exist: starts the clock, pushes the
## whole state to the UI and opens the start draft or pending level-ups.
func begin_session() -> void:
	TimeService.start_run_clock(elapsed_sec, location_elapsed_sec)
	_session_live = true
	_last_autosave_msec = TimeService.run_msec()
	_last_timer_second = -1
	_apply_start_shield()
	emit_all()
	if not bool(flags.get("draft_done", false)):
		Signals.run_draft_ready.emit(hero_id, hero_draft_options())
	elif _pending_levelups > 0:
		_offer_levelup()


func end_session() -> void:
	_session_live = false


func _process(delta: float) -> void:
	if not run_active or not _session_live:
		return
	_tick_time()
	_tick_regen(delta)
	_tick_buffs()
	_tick_antiheal()
	if TimeService.run_msec() - _last_autosave_msec >= int(Db.cfg_f("autosave_seconds") * MSEC):
		save_run()
	_flush()


func _tick_time() -> void:
	elapsed_sec = TimeService.elapsed_sec()
	location_elapsed_sec = TimeService.location_elapsed_sec()
	var interval: float = Db.f(Db.table("difficulty"), "tier_interval_sec")
	while interval > 0.0 and elapsed_sec >= next_tier_at_sec:
		difficulty_tier = WaveDirector.next_tier(difficulty_tier, tier_cap)
		next_tier_at_sec += interval
		_mark("difficulty")
	var second: int = floori(elapsed_sec)
	if second != _last_timer_second:
		_last_timer_second = second
		Signals.timer_changed.emit(elapsed_sec, location_elapsed_sec)


func _tick_regen(delta: float) -> void:
	var hp: float = Db.f(resources, "hp")
	var hp_max: float = Db.f(resources, "hp_max")
	if hp > 0.0 and hp < hp_max and stat("hp_regen") > 0.0:
		var healed: float = DamageCalc.heal(stat("hp_regen") * delta, stat("heal_mult", 1.0), is_heal_blocked(SOURCE_REGEN))
		if healed > 0.0:
			resources["hp"] = minf(hp_max, hp + healed)
			_mark("resources")
	var mana: float = Db.f(resources, "mana")
	var mana_max: float = Db.f(resources, "mana_max")
	if mana < mana_max and stat("mana_regen") > 0.0:
		resources["mana"] = minf(mana_max, mana + stat("mana_regen") * delta)
		_mark("resources")


func _tick_buffs() -> void:
	var now: int = TimeService.run_msec()
	var kept: Array = []
	for buff: Variant in buffs:
		if Db.i(buff, "until_msec") > now:
			kept.append(buff)
		elif Db.f(buff, "shield") > 0.0:
			_shield_hp = 0.0
			_mark("resources")
	if kept.size() != buffs.size():
		buffs = kept
		_recompute_stats()
		_mark("buffs")


func _tick_antiheal() -> void:
	var active: bool = is_antiheal_active()
	if active != _antiheal_shown:
		_antiheal_shown = active
		Signals.antiheal_changed.emit(active)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if run_active and _session_live:
				save_run()


# =====================================================================
# Queries (read-only)
# =====================================================================

func hero() -> Dictionary:
	return Db.entry("heroes", "heroes", hero_id)


func hero_class() -> String:
	return Db.s(hero(), "class")


func stats() -> Dictionary:
	return _stats


func stat(key: String, fallback: float = 0.0) -> float:
	return Db.f(_stats, key, fallback)


func current_location_id() -> String:
	return location_order[location_index] if location_index >= 0 and location_index < location_order.size() else ""


func is_final_location() -> bool:
	return location_index >= location_order.size() - 1


func xp_needed(level: int) -> int:
	var steps: float = float(maxi(0, level - 1))
	return roundi(Db.cfg_f("player.xp_base") * pow(Db.cfg_f("player.xp_growth"), steps) + Db.cfg_f("player.xp_flat") * steps)


func ability_in_slot(slot: int) -> Dictionary:
	for entry: Variant in abilities:
		if Db.i(entry, "slot") == slot:
			return entry
	return {}


func active_in_slot(slot: int) -> String:
	for entry: Variant in items_active:
		if Db.i(entry, "slot") == slot:
			return Db.s(entry, "id")
	return ""


func hero_draft_options() -> Array:
	return Db.a(hero(), "starting_items")


func is_antiheal_active() -> bool:
	return TimeService.run_msec() < _antiheal_until_msec


func is_heal_blocked(source: String) -> bool:
	if not is_antiheal_active():
		return false
	var antiheal: Dictionary = Db.d(Db.entry("elites", "modifiers", "antiheal"), "effect")
	return Db.a(antiheal, "blocks").has(source)


func shield_hp() -> float:
	return _shield_hp


func pending_levelups() -> int:
	return _pending_levelups


func summary(victory: bool) -> Dictionary:
	return {
		"victory": victory,
		"hero_id": hero_id,
		"elapsed_sec": elapsed_sec,
		"loop_count": loop_count,
		"kills": kills,
		"level": Db.i(resources, "level", 1),
		"currency": Db.i(resources, "currency"),
		"tier": difficulty_tier,
		"location_id": current_location_id(),
	}


func resources_snapshot() -> Dictionary:
	var out: Dictionary = resources.duplicate()
	out["xp_needed"] = xp_needed(Db.i(resources, "level", 1))
	out["level_cap"] = Db.cfg_i("player.level_cap")
	out["shield"] = _shield_hp
	return out


# =====================================================================
# Combat resources
# =====================================================================

## Applies an incoming hit after the player's own i-frames / parry. hit: {damage, source,
## antiheal_sec}. Returns the DamageCalc result plus "thorns", or {} when ignored.
func damage_player(hit: Dictionary) -> Dictionary:
	if not run_active or Db.f(resources, "hp") <= 0.0 or TimeService.run_msec() < _invuln_until_msec:
		return {}
	var target: Dictionary = {"shield": _shield_hp, "armor": stat("armor"), "armor_k": Db.cfg_f("combat.armor_k")}
	var result: Dictionary = DamageCalc.apply_to_target(Db.f(hit, "damage"), target)
	_shield_hp = Db.f(result, "shield_left")
	resources["hp"] = maxf(0.0, Db.f(resources, "hp") - Db.f(result, "hp_damage"))
	if Db.f(hit, "antiheal_sec") > 0.0:
		apply_antiheal(Db.f(hit, "antiheal_sec"))
	result["thorns"] = DamageCalc.thorns(Db.f(hit, "damage"), stat("thorns_pct"))
	_mark("resources")
	_flush()
	Signals.player_damaged.emit(Db.f(result, "total"), Db.s(hit, "source"))
	if Db.f(resources, "hp") <= 0.0:
		Signals.player_died.emit(summary(false))
	return result


func apply_antiheal(seconds: float) -> void:
	_antiheal_until_msec = maxi(_antiheal_until_msec, TimeService.deadline(seconds))
	_tick_antiheal()


## Heals the player unless `source` is blocked by antiheal. Returns the amount healed.
func heal_player(amount: float, source: String) -> float:
	if not run_active or Db.f(resources, "hp") <= 0.0:
		return 0.0
	var hp_max: float = Db.f(resources, "hp_max")
	var healed: float = minf(DamageCalc.heal(amount, stat("heal_mult", 1.0), is_heal_blocked(source)), hp_max - Db.f(resources, "hp"))
	if healed <= 0.0:
		return 0.0
	resources["hp"] = Db.f(resources, "hp") + healed
	_mark("resources")
	_flush()
	return healed


func spend_mana(cost: float) -> bool:
	if cost <= 0.0:
		return true
	if Db.f(resources, "mana") < cost:
		return false
	resources["mana"] = Db.f(resources, "mana") - cost
	_mark("resources")
	_flush()
	return true


func restore_mana(amount: float) -> void:
	resources["mana"] = minf(Db.f(resources, "mana_max"), Db.f(resources, "mana") + maxf(0.0, amount))
	_mark("resources")
	_flush()


func add_xp(amount: float) -> void:
	if not run_active or amount <= 0.0:
		return
	var cap: int = Db.cfg_i("player.level_cap")
	resources["xp"] = Db.f(resources, "xp") + amount * stat("xp_mult", 1.0)
	while Db.i(resources, "level", 1) < cap and Db.f(resources, "xp") >= float(xp_needed(Db.i(resources, "level", 1))):
		resources["xp"] = Db.f(resources, "xp") - float(xp_needed(Db.i(resources, "level", 1)))
		resources["level"] = Db.i(resources, "level", 1) + 1
		_pending_levelups += 1
	if Db.i(resources, "level", 1) >= cap:
		resources["xp"] = 0.0
	_mark("resources")
	_flush()
	if _pending_levelups > 0 and _levelup_options.is_empty() and bool(flags.get("draft_done", false)):
		_offer_levelup()


func add_currency(amount: float) -> void:
	if not run_active or amount <= 0.0:
		return
	resources["currency"] = Db.i(resources, "currency") + maxi(1, roundi(amount * stat("currency_mult", 1.0)))
	_mark("resources")
	_flush()


## buff: {id, name, color, duration_sec, stats, shield, invuln_sec, powerup}
func add_buff(buff: Dictionary) -> void:
	var duration: float = Db.f(buff, "duration_sec")
	if bool(buff.get("powerup", false)):
		duration *= stat("powerup_duration_mult", 1.0)
	if Db.f(buff, "invuln_sec") > 0.0:
		_invuln_until_msec = maxi(_invuln_until_msec, TimeService.deadline(Db.f(buff, "invuln_sec")))
	if Db.f(buff, "shield") > 0.0:
		_shield_hp = maxf(_shield_hp, Db.f(buff, "shield"))
		_mark("resources")
	if duration > 0.0:
		_remove_buff(Db.s(buff, "id"))
		var entry: Dictionary = buff.duplicate(true)
		entry["until_msec"] = TimeService.deadline(duration)
		buffs.append(entry)
		_recompute_stats()
		_mark("buffs")
	_flush()


func _remove_buff(buff_id: String) -> void:
	for index: int in range(buffs.size() - 1, -1, -1):
		if Db.s(buffs[index], "id") == buff_id:
			buffs.remove_at(index)


func _apply_start_shield() -> void:
	if stat("start_shield") > 0.0:
		_shield_hp = maxf(_shield_hp, stat("start_shield"))
		_mark("resources")


func collect_pickup(kind: String, value: float, extra: Dictionary) -> void:
	match kind:
		"xp":
			add_xp(value)
		"currency":
			add_currency(value)
		"heal":
			heal_player(value, "pickup")
		"powerup":
			apply_powerup(Db.s(extra, "id"))


func apply_powerup(powerup_id: String) -> void:
	var data: Dictionary = Db.entry("locations", "powerups", powerup_id)
	if data.is_empty():
		return
	Signals.toast_requested.emit(Db.s(data, "name"))
	if bool(data.get("magnet", false)):
		Signals.magnet_requested.emit()
	if Db.f(data, "heal") > 0.0:
		heal_player(Db.f(data, "heal"), "pickup")
	if Db.f(data, "duration") > 0.0:
		add_buff({
			"id": powerup_id, "name": Db.s(data, "name"), "color": Db.s(data, "color"),
			"duration_sec": Db.f(data, "duration"), "stats": Db.d(data, "stats"),
			"shield": Db.f(data, "shield"), "powerup": true,
		})


# =====================================================================
# Kills, bosses, location chain
# =====================================================================

## Called by an enemy when it dies. info: {enemy_id, position, elite}.
func register_kill(info: Dictionary) -> void:
	kills += 1
	for effect: Variant in ItemSystem.on_kill_effects(items_passive):
		_apply_kill_effect(effect, info)
	_flush()


func _apply_kill_effect(effect: Dictionary, info: Dictionary) -> void:
	var chance: float = Db.f(effect, "chance", 1.0)
	if chance < 1.0 and rng.randf() >= chance:
		return
	match Db.s(effect, "kind"):
		"mana":
			restore_mana(Db.f(effect, "amount"))
		"heal":
			heal_player(Db.f(effect, "amount"), "kill")
		"explode":
			var position: Vector2 = info.get("position", Vector2.ZERO)
			Signals.projectile_requested.emit(ShotFactory.player_blast(position, Db.f(effect, "damage"), Db.f(effect, "radius"), "yellow"))


func register_boss_kill(boss_id: String) -> void:
	var boss: Dictionary = Db.entry("bosses", "bosses", boss_id)
	var kind: String = Db.s(boss, "kind", KIND_BOSS)
	var is_final: bool = bool(boss.get("final", false))
	flags["miniboss_done" if kind == KIND_MINIBOSS else "boss_done"] = true
	_grant_boss_rewards(Db.d(boss, "rewards"))
	_flush()
	Signals.boss_defeated.emit(boss_id, kind, is_final)
	if is_final:
		Signals.victory_reached.emit(summary(true))


func _grant_boss_rewards(rewards: Dictionary) -> void:
	add_currency(Db.f(rewards, "currency"))
	var item_id: String = ItemSystem.roll_item(rng, _item_roll_context(Db.i(rewards, "item_min_rarity")))
	if not item_id.is_empty():
		add_item(item_id, "boss")
		Signals.toast_requested.emit("Трофей: %s" % Db.s(ItemSystem.item(item_id), "name"))
	add_xp(Db.f(rewards, "xp"))


func advance_location() -> void:
	location_index = mini(location_index + 1, location_order.size() - 1)
	_enter_location()
	save_run()


func _enter_location() -> void:
	location_elapsed_sec = 0.0
	flags["miniboss_done"] = false
	flags["boss_done"] = false
	TimeService.reset_location_clock()
	_apply_start_shield()
	_mark("location")
	_flush()


func start_loop() -> void:
	var params: Dictionary = WaveDirector.loop_params(difficulty_tier, difficulty_multiplier, Db.table("difficulty"))
	loop_count += 1
	difficulty_multiplier = Db.f(params, "multiplier", 1.0)
	tier_cap = Db.i(params, "tier_cap")
	location_order = _build_location_order(true)
	location_index = 0
	_mark("difficulty")
	_enter_location()
	save_run()
	Signals.loop_started.emit(loop_count, difficulty_multiplier)


func _on_loop_choice(choice: String) -> void:
	if choice == "loop":
		start_loop()
	else:
		end_run(true)


func _on_game_over_confirmed() -> void:
	end_run(false)


func end_run(victory: bool) -> void:
	if not run_active:
		return
	var result: Dictionary = summary(victory)
	result["banked"] = MetaState.bank_run(result)
	run_active = false
	_session_live = false
	SaveManager.delete_run()
	Signals.run_ended.emit(result)


## Leaves to the hub keeping the run save (pause menu "to hub").
func suspend_run() -> void:
	if not run_active:
		return
	save_run()
	run_active = false
	_session_live = false
	Signals.run_ended.emit({"suspended": true})


# =====================================================================
# Abilities, items, level-ups, draft
# =====================================================================

func apply_hero_draft(item_ids: Array) -> void:
	if bool(flags.get("draft_done", false)):
		return
	var allowed: Array = hero_draft_options()
	for id: Variant in item_ids.slice(0, Db.cfg_i("run.draft_picks")):
		if allowed.has(str(id)):
			add_item(str(id), "draft")
	flags["draft_done"] = true
	save_run()
	Signals.draft_completed.emit()
	if _pending_levelups > 0:
		_offer_levelup()


func add_item(item_id: String, source: String) -> void:
	var data: Dictionary = ItemSystem.item(item_id)
	if data.is_empty():
		push_error("GameState: unknown item '%s'" % item_id)
		return
	if data.has("limit_break"):
		_apply_limit_break(Db.s(data, "limit_break"))
	if ItemSystem.is_active(item_id):
		_add_active(item_id)
	else:
		ItemSystem.add_passive(items_passive, item_id)
		_recompute_stats()
	_mark("items")
	_flush()
	Signals.item_gained.emit(item_id, source)


func _add_active(item_id: String) -> void:
	var slot: int = _free_active_slot()
	if slot < 0:
		add_currency(Db.cfg_f("run.item_full_currency"))
		Signals.toast_requested.emit("Слоты заняты: предмет обменян на кредиты")
		return
	items_active.append({"id": item_id, "slot": slot})


func _apply_limit_break(kind: String) -> void:
	if Db.i(flags, "limit_breaks_used") > 0:
		return
	flags["limit_breaks_used"] = Db.i(flags, "limit_breaks_used") + 1
	slot_limits[kind] = Db.i(slot_limits, kind) + 1
	_mark("slots")
	_mark("abilities")


func craft(recipe_id: String) -> void:
	var output: String = ItemSystem.craft(items_passive, recipe_id)
	if output.is_empty():
		Signals.toast_requested.emit("Не хватает компонентов")
		return
	_recompute_stats()
	add_item(output, "craft")
	Signals.toast_requested.emit("Создано: %s" % Db.s(ItemSystem.item(output), "name"))


func _free_active_slot() -> int:
	var used: Array = []
	for entry: Variant in items_active:
		used.append(Db.i(entry, "slot"))
	for slot: int in Db.i(slot_limits, "active_items"):
		if not used.has(slot):
			return slot
	return -1


func _free_ability_slot() -> int:
	var used: Array = []
	for entry: Variant in abilities:
		used.append(Db.i(entry, "slot"))
	for slot: int in Db.i(slot_limits, "abilities"):
		if not used.has(slot):
			return slot
	return -1


func _ability_ids() -> Array:
	var out: Array = []
	for entry: Variant in abilities:
		out.append(Db.s(entry, "id"))
	return out


func _add_ability(ability_id: String) -> void:
	var slot: int = _free_ability_slot()
	if slot < 0 or _ability_ids().has(ability_id):
		return
	abilities.append({"id": ability_id, "level": 1, "slot": slot})
	_mark("abilities")


func upgrade_ability(ability_id: String) -> void:
	for entry: Variant in abilities:
		if Db.s(entry, "id") == ability_id:
			(entry as Dictionary)["level"] = mini(AbilitySystem.max_level(), Db.i(entry, "level", 1) + 1)
			_mark("abilities")
	_flush()


func _offer_levelup() -> void:
	_levelup_options = _build_levelup_options()
	Signals.level_up_ready.emit(Db.i(resources, "level", 1), _levelup_options.duplicate(true))


func choose_levelup(index: int) -> void:
	if _levelup_options.is_empty():
		return
	var option: Dictionary = _levelup_options[clampi(index, 0, _levelup_options.size() - 1)]
	_levelup_options = []
	_pending_levelups = maxi(0, _pending_levelups - 1)
	match Db.s(option, "kind"):
		OPTION_NEW:
			_add_ability(Db.s(option, "id"))
		OPTION_UPGRADE:
			upgrade_ability(Db.s(option, "id"))
		OPTION_ITEM:
			add_item(Db.s(option, "id"), "levelup")
		OPTION_CURRENCY:
			add_currency(Db.f(option, "amount"))
	_flush()
	if _pending_levelups > 0:
		_offer_levelup()


func _build_levelup_options() -> Array:
	var count: int = Db.cfg_i("levelup.options") + int(stat("levelup_options_flat"))
	var attempts: int = count * Db.cfg_i("levelup.attempts_per_option")
	var options: Array = []
	while options.size() < count and attempts > 0:
		attempts -= 1
		var option: Dictionary = _roll_option()
		if not option.is_empty() and not _has_option(options, option):
			options.append(option)
	if options.is_empty():
		options.append({"kind": OPTION_CURRENCY, "amount": Db.cfg_f("levelup.fallback_currency")})
	return options


func _roll_option() -> Dictionary:
	var weights_cfg: Dictionary = Db.cfg_d("levelup.weights")
	var upgradable: Array = AbilitySystem.upgradable(abilities)
	var weights: Array = [
		Db.f(weights_cfg, OPTION_NEW) if _free_ability_slot() >= 0 else 0.0,
		Db.f(weights_cfg, OPTION_UPGRADE) if not upgradable.is_empty() else 0.0,
		Db.f(weights_cfg, OPTION_ITEM),
	]
	match LootRoller.roll_weighted(rng, weights):
		0:
			var ability_id: String = AbilitySystem.roll_new_ability(rng, _ability_ids(), hero_class())
			return {} if ability_id.is_empty() else {"kind": OPTION_NEW, "id": ability_id, "level": 1}
		1:
			var entry: Dictionary = LootRoller.pick(rng, upgradable)
			return {"kind": OPTION_UPGRADE, "id": Db.s(entry, "id"), "level": Db.i(entry, "level", 1) + 1}
		2:
			var item_id: String = ItemSystem.roll_item(rng, _item_roll_context(0))
			return {} if item_id.is_empty() else {"kind": OPTION_ITEM, "id": item_id}
	return {}


func _has_option(options: Array, option: Dictionary) -> bool:
	for existing: Variant in options:
		if Db.s(existing, "kind") == Db.s(option, "kind") and Db.s(existing, "id") == Db.s(option, "id"):
			return true
	return false


func _item_roll_context(min_rarity: int) -> Dictionary:
	return {
		"min_rarity": min_rarity,
		"luck_pct": stat("luck_pct"),
		"allow_limit_break": Db.i(flags, "limit_breaks_used") == 0,
		"allow_active": _free_active_slot() >= 0,
	}


# =====================================================================
# Stats
# =====================================================================

func _recompute_stats() -> void:
	var base: Dictionary = Db.d(hero(), "stats")
	var bonus: Dictionary = MetaState.meta_bonuses()
	var tiers: Dictionary = {Db.s(hero(), "signature_item"): MetaState.starting_item_tier(hero_id)}
	_add_into(bonus, ItemSystem.stat_bonus(items_passive, tiers))
	for buff: Variant in buffs:
		_add_into(bonus, Db.d(buff, "stats"))
	var next: Dictionary = _core_stats(base, bonus)
	next.merge(_offense_stats(base, bonus))
	next.merge(_utility_stats(bonus))
	_apply_max_changes(next)
	_stats = next
	_mark("stats")


func _add_into(target: Dictionary, source: Dictionary) -> void:
	for key: Variant in source.keys():
		target[key] = Db.f(target, str(key)) + Db.f(source, str(key))


func _pct(bonus: Dictionary, key: String) -> float:
	return 1.0 + Db.f(bonus, key) / PERCENT


func _core_stats(base: Dictionary, bonus: Dictionary) -> Dictionary:
	return {
		"hp_max": Db.f(base, "hp_max") + Db.f(bonus, "hp_max_flat"),
		"mana_max": Db.f(base, "mana_max") + Db.f(bonus, "mana_max_flat"),
		"hp_regen": Db.f(base, "hp_regen") + Db.f(bonus, "hp_regen"),
		"mana_regen": Db.f(base, "mana_regen") + Db.f(bonus, "mana_regen"),
		"move_speed": Db.f(base, "move_speed") * _pct(bonus, "move_speed_pct"),
		"armor": Db.f(base, "armor") + Db.f(bonus, "armor"),
		"pickup_radius": Db.f(base, "pickup_radius") * _pct(bonus, "pickup_radius_pct"),
		"lifesteal_pct": Db.f(bonus, "lifesteal_pct"),
		"thorns_pct": Db.f(bonus, "thorns_pct"),
		"heal_mult": _pct(bonus, "heal_pct"),
		"start_shield": Db.f(bonus, "start_shield"),
	}


func _offense_stats(base: Dictionary, bonus: Dictionary) -> Dictionary:
	var min_cd: float = Db.cfg_f("combat.min_cooldown_mult")
	return {
		"damage_mult": _pct(bonus, "damage_pct"),
		"crit_chance": Db.f(base, "crit_chance") + Db.f(bonus, "crit_chance"),
		"crit_mult": Db.f(base, "crit_mult") + Db.f(bonus, "crit_mult"),
		"attack_speed_mult": _pct(bonus, "attack_speed_pct"),
		"cooldown_mult": maxf(min_cd, 1.0 - Db.f(bonus, "cooldown_reduction_pct") / PERCENT),
		"dash_cooldown_mult": maxf(min_cd, 1.0 - Db.f(bonus, "dash_cooldown_pct") / PERCENT),
		"area_mult": _pct(bonus, "area_pct"),
		"projectile_speed_mult": _pct(bonus, "projectile_speed_pct"),
		"drone_damage_mult": _pct(bonus, "drone_damage_pct"),
		"drone_cap_bonus": Db.f(bonus, "drone_cap_flat"),
		"elite_damage_mult": _pct(bonus, "elite_damage_pct"),
		"boss_damage_mult": _pct(bonus, "boss_damage_pct"),
	}


func _utility_stats(bonus: Dictionary) -> Dictionary:
	return {
		"xp_mult": _pct(bonus, "xp_gain_pct"),
		"currency_mult": _pct(bonus, "currency_gain_pct"),
		"levelup_options_flat": Db.f(bonus, "levelup_options_flat"),
		"luck_pct": Db.f(bonus, "luck_pct"),
		"powerup_duration_mult": _pct(bonus, "powerup_duration_pct"),
		"start_currency": Db.f(bonus, "start_currency"),
	}


## Keeps current HP / mana in step when the maximum changes (gains add, losses clamp).
func _apply_max_changes(next: Dictionary) -> void:
	if resources.is_empty():
		return
	for pair: Array in [["hp", "hp_max"], ["mana", "mana_max"]]:
		var old_max: float = Db.f(resources, str(pair[1]))
		var new_max: float = Db.f(next, str(pair[1]))
		var current: float = Db.f(resources, str(pair[0])) + maxf(0.0, new_max - old_max)
		resources[pair[1]] = new_max
		resources[pair[0]] = clampf(current, 0.0, new_max)
	_mark("resources")


# =====================================================================
# Signals flush
# =====================================================================

func _mark(domain: String) -> void:
	_dirty[domain] = true


func emit_all() -> void:
	for domain: String in DOMAINS:
		_mark(domain)
	_flush()
	Signals.timer_changed.emit(elapsed_sec, location_elapsed_sec)
	Signals.antiheal_changed.emit(is_antiheal_active())


func _flush() -> void:
	if _dirty.is_empty():
		return
	var dirty: Dictionary = _dirty
	_dirty = {}
	for domain: String in DOMAINS:
		if dirty.has(domain):
			_emit_domain(domain)


func _emit_domain(domain: String) -> void:
	match domain:
		"resources":
			Signals.resources_changed.emit(resources_snapshot())
		"stats":
			Signals.stats_changed.emit(_stats.duplicate())
		"abilities":
			Signals.abilities_changed.emit(abilities.duplicate(true))
		"items":
			Signals.items_changed.emit(items_passive.duplicate(true), items_active.duplicate(true))
			Signals.recipes_changed.emit(ItemSystem.available_recipes(items_passive))
		"slots":
			Signals.slot_limits_changed.emit(slot_limits.duplicate())
		"difficulty":
			Signals.difficulty_changed.emit(difficulty_tier, difficulty_multiplier, loop_count)
		"location":
			Signals.location_changed.emit(current_location_id(), location_index, location_order.size())
		"buffs":
			Signals.buffs_changed.emit(_buff_snapshot())


func _buff_snapshot() -> Array:
	var out: Array = []
	for buff: Variant in buffs:
		out.append({"id": Db.s(buff, "id"), "name": Db.s(buff, "name"), "color": Db.s(buff, "color"), "until_msec": Db.i(buff, "until_msec")})
	return out


# =====================================================================
# Save / load
# =====================================================================

func save_run() -> void:
	if not run_active:
		return
	_last_autosave_msec = TimeService.run_msec()
	SaveManager.write_run(to_save_dict())


func to_save_dict() -> Dictionary:
	return {
		"version": Db.cfg_i("save_version"),
		"seed": seed_value,
		"rng_state": str(rng.state),
		"run_start_unix": run_start_unix,
		"hero_id": hero_id,
		"difficulty_tier": difficulty_tier,
		"difficulty_multiplier": difficulty_multiplier,
		"tier_cap": tier_cap,
		"next_tier_at_sec": next_tier_at_sec,
		"loop_count": loop_count,
		"location_order": location_order.duplicate(),
		"location_index": location_index,
		"elapsed_sec": elapsed_sec,
		"location_elapsed_sec": location_elapsed_sec,
		"kills": kills,
		"pending_levelups": _pending_levelups,
		"resources": _resources_to_save(),
		"abilities": abilities.duplicate(true),
		"items_passive": items_passive.duplicate(true),
		"items_active": items_active.duplicate(true),
		"slot_limits": slot_limits.duplicate(),
		"flags": flags.duplicate(),
	}


func _resources_to_save() -> Dictionary:
	return {
		"hp": Db.f(resources, "hp"), "hp_max": Db.f(resources, "hp_max"),
		"mana": Db.f(resources, "mana"), "mana_max": Db.f(resources, "mana_max"),
		"xp": floori(Db.f(resources, "xp")), "level": Db.i(resources, "level", 1),
		"currency": Db.i(resources, "currency"),
	}


func from_save_dict(data: Dictionary) -> void:
	hero_id = Db.s(data, "hero_id")
	_reset_run_counters()
	seed_value = Db.i(data, "seed")
	rng.seed = seed_value
	var state: String = Db.s(data, "rng_state")
	if state.is_valid_int():
		rng.state = state.to_int()
	run_start_unix = Db.i(data, "run_start_unix", TimeService.now_unix())
	_load_difficulty(data)
	_load_lists(data)
	_recompute_stats()
	_load_resources(Db.d(data, "resources"))


func _load_difficulty(data: Dictionary) -> void:
	difficulty_tier = maxi(0, Db.i(data, "difficulty_tier"))
	difficulty_multiplier = maxf(1.0, Db.f(data, "difficulty_multiplier", 1.0))
	tier_cap = maxi(difficulty_tier, Db.i(data, "tier_cap", tier_cap))
	next_tier_at_sec = Db.f(data, "next_tier_at_sec", next_tier_at_sec)
	loop_count = maxi(0, Db.i(data, "loop_count"))
	location_order.assign(Db.a(data, "location_order"))
	if location_order.is_empty():
		location_order = _build_location_order(false)
	location_index = clampi(Db.i(data, "location_index"), 0, location_order.size() - 1)
	elapsed_sec = maxf(0.0, Db.f(data, "elapsed_sec"))
	location_elapsed_sec = maxf(0.0, Db.f(data, "location_elapsed_sec"))
	kills = maxi(0, Db.i(data, "kills"))
	_pending_levelups = maxi(0, Db.i(data, "pending_levelups"))


func _load_lists(data: Dictionary) -> void:
	abilities = []
	for entry: Variant in Db.a(data, "abilities"):
		if entry is Dictionary and not AbilitySystem.ability(Db.s(entry, "id")).is_empty():
			abilities.append({"id": Db.s(entry, "id"), "level": clampi(Db.i(entry, "level", 1), 1, AbilitySystem.max_level()), "slot": Db.i(entry, "slot")})
	for entry: Variant in Db.a(data, "items_passive"):
		if entry is Dictionary and not ItemSystem.item(Db.s(entry, "id")).is_empty():
			items_passive.append({"id": Db.s(entry, "id"), "stacks": maxi(1, Db.i(entry, "stacks", 1))})
	for entry: Variant in Db.a(data, "items_active"):
		if entry is Dictionary and ItemSystem.is_active(Db.s(entry, "id")):
			items_active.append({"id": Db.s(entry, "id"), "slot": Db.i(entry, "slot")})
	slot_limits.merge(Db.d(data, "slot_limits"), true)
	flags.merge(Db.d(data, "flags"), true)


func _load_resources(saved: Dictionary) -> void:
	resources = {
		"hp_max": stat("hp_max"), "mana_max": stat("mana_max"),
		"hp": clampf(Db.f(saved, "hp", stat("hp_max")), 1.0, stat("hp_max")),
		"mana": clampf(Db.f(saved, "mana", stat("mana_max")), 0.0, stat("mana_max")),
		"xp": maxf(0.0, Db.f(saved, "xp")),
		"level": clampi(Db.i(saved, "level", 1), 1, Db.cfg_i("player.level_cap")),
		"currency": maxi(0, Db.i(saved, "currency")),
	}
