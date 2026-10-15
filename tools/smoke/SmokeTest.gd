extends Node
## Headless acceptance test:
##   godot --headless --path . res://tools/smoke/SmokeTest.tscn
## Wipes the saves, then plays through the acceptance checklist programmatically (hub -> run
## -> draft -> controls -> level-up / ultimate -> elites -> difficulty -> bosses -> location
## transition -> final boss -> loop -> death -> meta purchase) and checks the PURE modules.
## Writes user://smoke_report.txt and exits with code 0 when every check passes.

const Db = preload("res://core/Db.gd")
const Sprites = preload("res://core/Sprites.gd")
const REPORT_PATH: String = "user://smoke_report.txt"
const HUGE_DAMAGE: float = 1000000.0
const PURE_SCRIPTS: Array[String] = ["res://autoload/SpawnDirector.gd", "res://autoload/DamageCalc.gd", "res://autoload/WaveDirector.gd"]
const FORBIDDEN_IN_PURE: Array[String] = ["GameState", "MetaState", "get_node", "get_tree", "$", "Node2D", "Signals.", "RandomNumberGenerator"]

var _lines: Array[String] = []
var _failed: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _check(label: String, ok: bool, detail: String = "") -> void:
	_lines.append("%s %s%s" % ["PASS" if ok else "FAIL", label, (" — " + detail) if not detail.is_empty() else ""])
	if not ok:
		_failed += 1
		push_error("SMOKE FAIL: %s %s" % [label, detail])


## Waits `count` rendered frames (each also lets at least one physics step run).
func _frames(count: int) -> void:
	for _index: int in count:
		await get_tree().process_frame
		await get_tree().physics_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _scene() -> Node:
	return get_tree().current_scene


func _node(path: String) -> Node:
	return _scene().get_node_or_null(path) if _scene() != null else null


func _run() -> void:
	SaveManager.delete_all()
	MetaState.new_profile()
	SaveManager.write_meta(MetaState.to_save_dict())
	var placeholder: Node = Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	await _test_hub_boot()
	await _test_start_run()
	await _test_draft()
	await _test_controls()
	await _test_visuals()
	await _test_levelup_and_ultimate()
	await _test_elites()
	await _test_difficulty()
	await _test_bosses_and_transition()
	await _test_final_and_loop()
	await _test_death_and_meta()
	_test_purity()
	_finish()


func _finish() -> void:
	_lines.append("TOTAL: %d checks, %d failed" % [_lines.size(), _failed])
	var file: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_lines) + "\n")
		file.close()
	get_tree().paused = false
	get_tree().quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- 1. hub

func _test_hub_boot() -> void:
	get_tree().change_scene_to_file(Db.cfg_s("scenes.menu"))
	await _frames(5)
	_check("main menu boots with 3 hero cards", _scene() != null and _scene().name == "MainMenu" and _node("UI/Menu/Rows/Cards").get_child_count() == 3)
	get_tree().change_scene_to_file(Db.cfg_s("scenes.hub"))
	await _frames(5)
	_check("hub boots", _scene() != null and _scene().name == "Hub")
	_check("hub has the walking hero and 5 terminals", _node("World/Avatar") != null and _scene().get("_terminals").size() == 5)
	_scene().call("use_terminal", "tree")
	await _frames(2)
	_check("skill tree terminal opens the graph", str(_scene().call("open_overlay")) == "tree")
	_scene().call("_close_overlays")
	_check("fresh meta currency", MetaState.currency == Db.cfg_i("meta.start_currency"), str(MetaState.currency))
	_check("one hero unlocked at start", MetaState.unlocked_heroes.size() == 1)


# ---------------------------------------------------------------- 2. run start

func _test_start_run() -> void:
	Signals.run_start_requested.emit("vector")
	await _frames(10)
	_check("run scene loaded", _scene() != null and _scene().name == "Run")
	_check("run active", GameState.run_active)
	_check("3 starting abilities on Z X C", GameState.abilities.size() == 3 and not GameState.ability_in_slot(0).is_empty())
	var order: Array[String] = GameState.location_order
	var final_id: String = Db.s(Db.table("locations"), "final")
	_check("location chain covers all, final last", order.size() == 5 and order[4] == final_id and order[0] != final_id, str(order))
	_check("player placed in location", _node("World/LocationSlot").get_child_count() == 1)


# ---------------------------------------------------------------- 3. draft

func _test_draft() -> void:
	var modal: Control = _node("UI/HeroDraftModal")
	_check("hero draft modal open", modal != null and modal.visible)
	_check("game paused during draft", get_tree().paused)
	var cards: Node = modal.get_node("Center/Panel/Rows/Options")
	for index: int in Db.cfg_i("run.draft_picks"):
		(cards.get_child(index) as Button).pressed.emit()
	(modal.get_node("Center/Panel/Rows/Confirm") as Button).pressed.emit()
	await _frames(3)
	_check("2 drafted items applied", GameState.items_passive.size() + GameState.items_active.size() == 2)
	_check("draft closes and unpauses", not modal.visible and not get_tree().paused)
	GameState.add_buff({"id": "smoke_invuln", "name": "smoke", "duration_sec": 99999.0, "invuln_sec": 99999.0})


# ---------------------------------------------------------------- 4. controls

func _press(action: String, hold_frames: int) -> void:
	await get_tree().physics_frame
	Input.action_press(action)
	await _frames(hold_frames)
	Input.action_release(action)
	await _frames(1)


func _test_controls() -> void:
	var player: Node2D = _node("World/Player")
	var start_x: float = player.global_position.x
	await _press("move_wasd_right", 20)
	_check("WASD moves the player", player.global_position.x > start_x, "%s -> %s" % [start_x, player.global_position.x])
	await _press("attack_lmb", 6)
	await _frames(1)
	_check("LMB fires", _node("World/Projectiles").get_child_count() > 0)
	await _press("attack_rmb", 1)
	_check("RMB empowered shot on cooldown", int(player.get_node("Attack").get("_empowered_ready_msec")) > TimeService.run_msec())
	await _press("reload_r", 1)
	_check("R reloads (ranged)", bool(player.get_node("Attack").get("_reloading")))
	for slot: int in 3:
		await _press(InputMapHelper.ability_action(slot), 1)
		_check("ability key %s casts" % InputMapHelper.label(InputMapHelper.ability_action(slot)), AbilitySystem.cooldown_left(slot) > 0.0)
	_check("V slot exists (4 ability slots)", Db.i(GameState.slot_limits, "abilities") == 4 and InputMap.has_action("ability_v"))
	GameState.add_item("nano_heal", "smoke")
	GameState.resources["hp"] = 40.0
	await _press(InputMapHelper.item_action(0), 1)
	_check("item key 1 uses active item", ItemSystem.cooldown_left(0) > 0.0 and Db.f(GameState.resources, "hp") > 40.0)
	for slot: int in 6:
		_check("item action %d mapped" % (slot + 1), InputMap.has_action(InputMapHelper.item_action(slot)))


# ---------------------------------------------------------------- 4b. sprites, reload bar, camera, HUD

func _test_visuals() -> void:
	var player: Node2D = _node("World/Player")
	var sprite: AnimatedSprite2D = player.get_node("Animator").get("sprite")
	var clips: PackedStringArray = sprite.sprite_frames.get_animation_names() if sprite != null else PackedStringArray()
	var wanted: Array[String] = ["idle", "run", "reload", "reload_run", "attack", "hurt", "levelup", "cast"]
	_check("hero sprite has 8 animations", wanted.all(func(clip: String) -> bool: return clips.has(clip)), ", ".join(clips))
	await _seconds(1.0)
	player.call("animate", "attack")
	await _frames(1)
	_check("attack plays the attack clip", sprite.animation == &"attack", str(sprite.animation))
	await _seconds(0.4)
	player.call("animate", "reload", 1.0, 1.0)
	await _frames(2)
	_check("reload bar shows during R", bool(player.get_node("ReloadBar").visible))
	_check("reload clip while standing", sprite.animation == &"reload")
	_check("enemy sprites come from the sheet manifest", Sprites.has("enemies/grunt") and Sprites.has("enemies/requiem"))
	var camera: Node = _node("Camera")
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = Vector2(40.0, 0.0)
	motion.position = Vector2(1700.0, 540.0)
	Input.parse_input_event(motion)
	await _frames(2)
	_check("camera leads while the aim moves", bool(camera.call("aiming")))
	get_tree().paused = true
	await _frames(1)
	_check("camera recentres while a modal pauses the run", not bool(camera.call("aiming")))
	get_tree().paused = false
	_check("HUD difficulty strip starts at ТИШИНА", str(_node("UI/HUD/RunInfo/Difficulty").call("current_name")) == "ТИШИНА")


# ---------------------------------------------------------------- 5. level-up / ultimate

func _drain_levelups() -> void:
	var modal: Control = _node("UI/LevelUpModal")
	var guard: int = 50
	while modal != null and modal.visible and guard > 0:
		guard -= 1
		modal.call("_choose", 0)
		await _frames(2)


func _test_levelup_and_ultimate() -> void:
	await _drain_levelups()
	var level: int = Db.i(GameState.resources, "level", 1)
	GameState.add_xp(float(GameState.xp_needed(level)) / GameState.stat("xp_mult", 1.0) + 0.5)
	await _frames(2)
	var modal: Control = _node("UI/LevelUpModal")
	_check("level-up modal shows options", modal.visible and modal.get_node("Center/Panel/Rows/Options").get_child_count() == 3)
	_check("paused during level-up", get_tree().paused)
	await _drain_levelups()
	_check("level increased", Db.i(GameState.resources, "level", 1) > level)
	for _step: int in AbilitySystem.max_level():
		GameState.upgrade_ability("piercing_shot")
	var stats: Dictionary = AbilitySystem.level_stats("piercing_shot", 5)
	_check("ability level 5 = ultimate", bool(stats.get("ultimate", false)) and Db.i(stats, "split") == 3)
	var spawned: Array = []
	var catcher: Callable = func(spec: Dictionary) -> void: spawned.append(spec)
	Signals.projectile_requested.connect(catcher)
	_node("World/Player/Caster").call("execute", stats, _node("World/Player").global_position + Vector2.RIGHT * 100.0)
	Signals.projectile_requested.disconnect(catcher)
	_check("ultimate variant applied on cast", not spawned.is_empty() and Db.i(spawned[0], "split") == 3 and Db.i(spawned[0], "pierce") == 99)


# ---------------------------------------------------------------- 6. elites

func _spawn_elite(mods: Array) -> Node:
	var config: Dictionary = Db.entry("enemies", "enemies", "grunt")
	var player: Node2D = _node("World/Player")
	return _node("Spawner").call("spawn_enemy", config, player.global_position + Vector2(260.0, 0.0), mods)


func _outline(enemy: Node) -> ShaderMaterial:
	return (enemy.get("body") as CanvasItem).material as ShaderMaterial


func _test_elites() -> void:
	var dual: Node = _spawn_elite(["antiheal", "shielded"])
	var single: Node = _spawn_elite(["berserk"])
	var rainbow: Node = _spawn_elite(["aura", "vampiric", "explosive"])
	await _frames(2)
	_check("elite sprite outline on", _outline(dual) != null and int(_outline(dual).get_shader_parameter("outline_mode")) >= 0)
	_check("2 mods -> dual outline (red + blue)", int(_outline(dual).get_shader_parameter("outline_mode")) == 1 and _color_close(_outline(dual).get_shader_parameter("color_a"), Db.glow("red")) and _color_close(_outline(dual).get_shader_parameter("color_b"), Db.glow("blue")))
	_check("1 mod -> single colour (berserk orange)", int(_outline(single).get_shader_parameter("outline_mode")) == 0 and _color_close(_outline(single).get_shader_parameter("color_a"), Db.glow("orange")))
	_check("3 mods -> rainbow", int(_outline(rainbow).get_shader_parameter("outline_mode")) == 2)
	var shield: float = float(dual.get("shield"))
	var hp: float = float(dual.get("hp"))
	dual.call("receive_hit", {"damage": 1.0, "faction": "player"})
	_check("shield absorbs damage first", shield > 0.0 and float(dual.get("shield")) < shield and is_equal_approx(float(dual.get("hp")), hp))
	await _test_antiheal()


func _color_close(value: Variant, expected: Color) -> bool:
	return value is Color and (value as Color).is_equal_approx(expected)


func _test_antiheal() -> void:
	GameState.add_buff({"id": "smoke_regen", "name": "regen", "duration_sec": 60.0, "stats": {"hp_regen": 30.0}})
	GameState.resources["hp"] = 30.0
	GameState.apply_antiheal(2.0)
	await _frames(20)
	_check("antiheal blocks HP regen", is_equal_approx(Db.f(GameState.resources, "hp"), 30.0), str(GameState.resources["hp"]))
	TimeService.skip(2.5)
	await _frames(20)
	_check("regen resumes after antiheal", Db.f(GameState.resources, "hp") > 30.0)


# ---------------------------------------------------------------- 7. difficulty

func _test_difficulty() -> void:
	await _drain_levelups()
	var tier: int = GameState.difficulty_tier
	TimeService.skip(Db.f(Db.table("difficulty"), "tier_interval_sec") + 1.0)
	await _frames(3)
	_check("tier +1 after 60 s", GameState.difficulty_tier == tier + 1, "%d -> %d" % [tier, GameState.difficulty_tier])
	var low: Dictionary = WaveDirector.scaling(0, 1.0, Db.table("difficulty"))
	var high: Dictionary = WaveDirector.scaling(GameState.difficulty_tier, 1.0, Db.table("difficulty"))
	_check("enemy hp / damage scale with tier", Db.f(high, "hp") > Db.f(low, "hp") and Db.f(high, "damage") > Db.f(low, "damage"))
	var enemy: Node = _node("Spawner").call("spawn_enemy", Db.entry("enemies", "enemies", "grunt"), _node("World/Player").global_position + Vector2(0.0, 300.0), [])
	await _frames(1)
	_check("spawned enemy uses scaled hp", float(enemy.get("hp_max")) > Db.f(Db.entry("enemies", "enemies", "grunt"), "hp"))
	_check("enemies are spawning", int(_node("Spawner").call("enemy_count")) > 0)


# ---------------------------------------------------------------- 8. bosses + transition

func _bosses() -> Array:
	var out: Array = []
	for child: Node in _node("World/Enemies").get_children():
		if child.get("boss_kind") != null and not bool(child.call("is_dead")):
			out.append(child)
	return out


func _kill_boss(kind: String) -> bool:
	for boss: Variant in _bosses():
		if str((boss as Node).get("boss_kind")) == kind:
			(boss as Node).call("receive_hit", {"damage": HUGE_DAMAGE, "faction": "player"})
			return true
	return false


func _skip_location_to(seconds: float) -> void:
	TimeService.skip(maxf(0.0, seconds - TimeService.location_elapsed_sec()) + 0.5)
	await _frames(4)
	await _drain_levelups()
	await _frames(2)


func _test_bosses_and_transition() -> void:
	var location: Dictionary = Db.entry("locations", "locations", GameState.current_location_id())
	await _skip_location_to(Db.f(location, "miniboss_at_sec"))
	_check("miniboss spawns at T+2 min", bool(_node("Spawner").call("boss_alive", "miniboss")))
	_check("miniboss killed", _kill_boss("miniboss"))
	await _frames(2)
	_check("miniboss flagged done", bool(GameState.flags.get("miniboss_done", false)))
	await _skip_location_to(Db.f(location, "boss_at_sec"))
	_check("boss spawns at T+5 min", bool(_node("Spawner").call("boss_alive", "boss")))
	var items_before: int = GameState.items_passive.size()
	var index_before: int = GameState.location_index
	_check("boss killed", _kill_boss("boss"))
	await _drain_levelups()
	await _seconds(Db.cfg_f("run.transition_delay_sec") + Db.cfg_f("run.transition_fade_sec") * 2.0 + 0.6)
	await _drain_levelups()
	_check("boss defeat -> next location", GameState.location_index == index_before + 1)
	var loaded: Node = _node("World/LocationSlot").get_child(0)
	_check("next location scene loaded", loaded != null and str(loaded.get("location_id")) == GameState.current_location_id())
	_check("items kept across transition", GameState.items_passive.size() >= items_before)


# ---------------------------------------------------------------- 9. final boss + loop

func _test_final_and_loop() -> void:
	GameState.location_index = GameState.location_order.size() - 2
	var current: Dictionary = Db.entry("locations", "locations", GameState.current_location_id())
	_node("Spawner").call("spawn_boss", Db.s(current, "boss"))
	await _frames(2)
	_kill_boss("boss")
	await _drain_levelups()
	await _seconds(Db.cfg_f("run.transition_delay_sec") + Db.cfg_f("run.transition_fade_sec") * 2.0 + 0.6)
	await _drain_levelups()
	_check("reached the final location", GameState.is_final_location())
	_node("Spawner").call("spawn_boss", Db.s(Db.entry("locations", "locations", GameState.current_location_id()), "boss"))
	await _frames(2)
	var items_before: int = GameState.items_passive.size() + GameState.items_active.size()
	var tier_before: int = GameState.difficulty_tier
	_kill_boss("boss")
	await _frames(3)
	var modal: Control = _node("UI/LoopChoiceModal")
	_check("final boss -> loop choice modal", modal != null and modal.visible)
	await _drain_levelups()
	modal.call("_choose", "loop")
	await _seconds(Db.cfg_f("run.transition_fade_sec") * 2.0 + 0.6)
	_check("loop count 1", GameState.loop_count == 1)
	_check("difficulty multiplier x1.5", is_equal_approx(GameState.difficulty_multiplier, 1.5))
	_check("loop restarts at location 1", GameState.location_index == 0 and GameState.current_location_id() == Db.s(Db.table("locations"), "loop_start"))
	_check("items kept on loop", GameState.items_passive.size() + GameState.items_active.size() >= items_before)
	_check("tier kept, cap = +20%", GameState.difficulty_tier >= tier_before and GameState.tier_cap == maxi(tier_before, ceili(float(tier_before) * 1.2)))


# ---------------------------------------------------------------- 10. death + meta

func _test_death_and_meta() -> void:
	await _drain_levelups()
	GameState.set("_invuln_until_msec", 0)
	var meta_before: int = MetaState.currency
	GameState.resources["currency"] = 77
	GameState.damage_player({"damage": HUGE_DAMAGE, "source": "smoke"})
	await _frames(3)
	var modal: Control = _node("UI/GameOverModal")
	_check("death -> game over modal", modal != null and modal.visible)
	modal.call("_on_to_hub")
	await _frames(10)
	_check("returned to hub", _scene() != null and _scene().name == "Hub")
	var kept: int = floori(77.0 * Db.cfg_f("meta.defeat_keep_fraction"))
	_check("run currency lost, meta banked", MetaState.currency == meta_before + kept, "%d -> %d" % [meta_before, MetaState.currency])
	_check("run save removed", not SaveManager.has_run_save())
	_check("meta save written", SaveManager.has_meta_save() and not SaveManager.load_meta().is_empty())
	var cost: int = MetaState.node_cost("o_power")
	Signals.meta_node_purchase_requested.emit("o_power")
	await _frames(2)
	_check("skill tree node purchasable", MetaState.node_level("o_power") == 1 and MetaState.currency == meta_before + kept - cost)
	_check("meta survives reload", Db.i(Db.d(SaveManager.load_meta(), "meta_tree_nodes"), "o_power") == 1)


# ---------------------------------------------------------------- 11. purity

func _test_purity() -> void:
	for path: String in PURE_SCRIPTS:
		var code: Array[String] = []
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			var stripped: String = line.strip_edges()
			if not stripped.begins_with("#") and not stripped.begins_with("extends"):
				code.append(stripped)
		var body: String = "\n".join(code)
		var hits: Array[String] = []
		for token: String in FORBIDDEN_IN_PURE:
			if body.contains(token):
				hits.append(token)
		_check("%s has no node / GameState refs" % path.get_file(), hits.is_empty(), ", ".join(hits))
