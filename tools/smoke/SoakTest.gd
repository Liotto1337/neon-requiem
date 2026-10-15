extends Node
## Headless soak test: every hero plays the whole location chain with held attacks, every
## ability (levels 1 and 5) and active item, every enemy type and elite modifier, and each
## location's miniboss + boss cycling through all of their patterns. Catches runtime script
## errors in behaviour code the acceptance smoke test does not reach.
##   godot --headless --path . res://tools/smoke/SoakTest.tscn
## Exit code 0 = finished; read the log for SCRIPT ERROR lines.

const Db = preload("res://core/Db.gd")
const HEROES: Array[String] = ["vector", "katar", "chorus"]
const COMBAT_FRAMES: int = 240
const BOSS_FRAMES: int = 420
const ACTION_EVERY: int = 30
const HUGE_DAMAGE: float = 1000000.0
const SPAWN_OFFSET: float = 280.0

var _frame: int = 0
var _report: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _frames(count: int) -> void:
	for _index: int in count:
		await get_tree().process_frame
		await get_tree().physics_frame


func _node(path: String) -> Node:
	return get_tree().current_scene.get_node_or_null(path) if get_tree().current_scene != null else null


func _run() -> void:
	SaveManager.delete_all()
	MetaState.new_profile()
	for hero: String in HEROES:
		if not MetaState.unlocked_heroes.has(hero):
			MetaState.unlocked_heroes.append(hero)
	var placeholder: Node = Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	for hero: String in HEROES:
		await _play_hero(hero)
	var file: FileAccess = FileAccess.open("user://soak_report.txt", FileAccess.WRITE)
	file.store_string("\n".join(_report) + "\n")
	file.close()
	get_tree().paused = false
	get_tree().quit(0)


func _play_hero(hero: String) -> void:
	get_tree().change_scene_to_file(Db.cfg_s("scenes.hub"))
	await _frames(3)
	Signals.run_start_requested.emit(hero)
	await _frames(6)
	await _draft()
	GameState.add_buff({"id": "soak_invuln", "name": "soak", "duration_sec": 999999.0, "invuln_sec": 999999.0})
	_cover_abilities_and_items()
	var visited: Array[String] = []
	var kills: int = 0
	var level: int = 0
	for _location: int in GameState.location_order.size():
		visited.append(GameState.current_location_id())
		kills = GameState.kills
		level = Db.i(GameState.resources, "level")
		await _play_location()
		if not GameState.run_active:
			break
	_report.append("%s: visited %s, kills %d, level %d, run_active %s, scene %s, meta %d" % [hero, visited, kills, level, GameState.run_active, get_tree().current_scene.name, MetaState.currency])
	await _drain()


func _draft() -> void:
	var modal: Node = _node("UI/HeroDraftModal")
	var cards: Node = modal.get_node("Center/Panel/Rows/Options")
	for index: int in Db.cfg_i("run.draft_picks"):
		(cards.get_child(index) as Button).pressed.emit()
	(modal.get_node("Center/Panel/Rows/Confirm") as Button).pressed.emit()
	await _frames(2)


func _cover_abilities_and_items() -> void:
	var caster: Node = _node("World/Player/Caster")
	var aim: Vector2 = (_node("World/Player") as Node2D).global_position + Vector2(200.0, 50.0)
	for data: Variant in Db.list("abilities", "abilities"):
		for level: int in [1, AbilitySystem.max_level()]:
			caster.call("execute", AbilitySystem.level_stats(Db.s(data, "id"), level), aim)
	for data: Variant in Db.list("items", "items"):
		if Db.s(data, "type") == "active":
			var spec: Dictionary = Db.d(data, "active").duplicate()
			spec["id"] = Db.s(data, "id")
			caster.call("execute_item", spec, aim)
		else:
			GameState.add_item(Db.s(data, "id"), "soak")


func _play_location() -> void:
	_spawn_every_enemy()
	await _fight(COMBAT_FRAMES)
	var location: Dictionary = Db.entry("locations", "locations", GameState.current_location_id())
	var spawner: Node = _node("Spawner")
	spawner.call("spawn_boss", Db.s(location, "miniboss"))
	spawner.call("spawn_boss", Db.s(location, "boss"))
	await _fight(BOSS_FRAMES)
	await _drain()
	_kill_all_bosses()
	await _frames(4)
	await _drain()
	if GameState.is_final_location() or _node("UI/LoopChoiceModal").visible:
		_node("UI/LoopChoiceModal").call("_choose", "hub")
		await _frames(6)
		return
	await get_tree().create_timer(Db.cfg_f("run.transition_delay_sec") + Db.cfg_f("run.transition_fade_sec") * 2.0 + 0.5, true, false, true).timeout
	await _drain()


func _spawn_every_enemy() -> void:
	var spawner: Node = _node("Spawner")
	var center: Vector2 = (_node("World/Player") as Node2D).global_position
	var mods: Array = []
	for mod: Variant in Db.list("elites", "modifiers"):
		mods.append(Db.s(mod, "id"))
	var index: int = 0
	for enemy: Variant in Db.list("enemies", "enemies"):
		var spot: Vector2 = center + Vector2.RIGHT.rotated(float(index)) * SPAWN_OFFSET
		var elite: Array = [mods[index % mods.size()]] if index % 2 == 0 else []
		spawner.call("spawn_enemy", enemy, spot, elite)
		index += 1
	spawner.call("spawn_enemy", Db.entry("enemies", "enemies", "grunt"), center + Vector2(0.0, SPAWN_OFFSET), mods)


func _fight(frames: int) -> void:
	Input.action_press("attack_lmb")
	for _index: int in frames:
		_frame += 1
		var angle: float = float(_frame) * 0.03
		Input.action_release("move_wasd_right")
		Input.action_release("move_wasd_down")
		Input.action_press("move_wasd_right" if sin(angle) > 0.0 else "move_wasd_left")
		Input.action_press("move_wasd_down" if cos(angle) > 0.0 else "move_wasd_up")
		if _frame % ACTION_EVERY == 0:
			_tap_actions()
		await _frames(1)
		await _drain()
	for action: String in ["attack_lmb", "move_wasd_right", "move_wasd_left", "move_wasd_down", "move_wasd_up"]:
		Input.action_release(action)


func _tap_actions() -> void:
	var actions: Array[String] = ["attack_rmb", "reload_r"]
	for slot: int in Db.i(GameState.slot_limits, "abilities"):
		actions.append(InputMapHelper.ability_action(slot))
	for slot: int in Db.i(GameState.slot_limits, "active_items"):
		actions.append(InputMapHelper.item_action(slot))
	var action: String = actions[floori(float(_frame) / float(ACTION_EVERY)) % actions.size()]
	Input.action_press(action)
	Input.action_release.call_deferred(action)


func _drain() -> void:
	for modal_name: String in ["LevelUpModal"]:
		var modal: Node = _node("UI/" + modal_name)
		var guard: int = 60
		while modal != null and modal.visible and guard > 0:
			guard -= 1
			modal.call("_choose", 0)
			await get_tree().process_frame


func _kill_all_bosses() -> void:
	for child: Node in _node("World/Enemies").get_children():
		if child.get("boss_kind") != null and not bool(child.call("is_dead")):
			child.call("receive_hit", {"damage": HUGE_DAMAGE, "faction": "player"})
