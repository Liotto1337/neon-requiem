extends Node
## Visual QA tour: starts a run, spawns every enemy (some elite), casts, calls a boss and saves
## screenshots to $SHOTS_OUT. Hero via $SHOT_HERO (default vector).
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 res://tools/shots/GameShots.tscn

const Db = preload("res://core/Db.gd")
const ELITE_SETS: Array = [["antiheal", "shielded"], ["berserk"], [], ["aura", "vampiric", "explosive"], []]

var _out: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_out = OS.get_environment("SHOTS_OUT")
	_run.call_deferred()


func _frames(count: int) -> void:
	for _index: int in count:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, shot_name])


func _node(path: String) -> Node:
	return get_tree().current_scene.get_node_or_null(path)


func _run() -> void:
	SaveManager.delete_all()
	MetaState.new_profile()
	MetaState.unlocked_heroes.assign(["vector", "katar", "chorus"])
	var placeholder: Node = Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	get_tree().change_scene_to_file(Db.cfg_s("scenes.hub"))
	await _frames(6)
	var hero: String = OS.get_environment("SHOT_HERO")
	Signals.run_start_requested.emit(hero if hero != "" else "vector")
	await _frames(10)
	await _shot("01_draft")
	_finish_draft()
	await _frames(20)
	await _shot("02_start")
	_spawn_crowd()
	await _combat(90)
	await _shot("03_combat")
	_node("Spawner").call("spawn_boss", Db.s(Db.entry("locations", "locations", GameState.current_location_id()), "boss"))
	await _combat(120)
	await _shot("04_boss")
	await _hud_and_reload()
	get_tree().quit()


## Hit through the QA invulnerability to catch the ghost chunk, then a reload on the move.
func _hud_and_reload() -> void:
	GameState.heal_player(100.0, "qa")
	await _frames(2)
	GameState.set("_invuln_until_msec", 0)
	GameState.damage_player({"damage": 30.0, "source": "qa"})
	GameState.add_buff({"id": "shot_invuln2", "name": "QA", "duration_sec": 9999.0, "invuln_sec": 9999.0})
	await _frames(2)
	await _shot("05_hud_hit")
	await get_tree().create_timer(0.55).timeout
	await _shot("06_hud_fall")
	Input.action_press("move_wasd_left")
	Input.action_press("reload_r")
	await _frames(2)
	Input.action_release("reload_r")
	await get_tree().create_timer(0.35).timeout
	await _shot("07_reload")
	Input.action_release("move_wasd_left")


func _finish_draft() -> void:
	var modal: Node = _node("UI/HeroDraftModal")
	var cards: Node = modal.get_node("Center/Panel/Rows/Options")
	(cards.get_child(0) as Button).pressed.emit()
	(cards.get_child(1) as Button).pressed.emit()
	(modal.get_node("Center/Panel/Rows/Confirm") as Button).pressed.emit()
	GameState.add_buff({"id": "shot_invuln", "name": "QA", "duration_sec": 9999.0, "invuln_sec": 9999.0})


func _spawn_crowd() -> void:
	var spawner: Node = _node("Spawner")
	var player: Node2D = _node("World/Player")
	var index: int = 0
	for enemy: Variant in Db.list("enemies", "enemies"):
		var offset: Vector2 = Vector2.RIGHT.rotated(float(index) * 0.7) * (240.0 + 40.0 * float(index % 4))
		spawner.call("spawn_enemy", enemy, player.global_position + offset, ELITE_SETS[index % ELITE_SETS.size()])
		index += 1


func _combat(frame_count: int) -> void:
	var player: Node2D = _node("World/Player")
	Input.action_press("attack_lmb")
	for frame: int in frame_count:
		await _frames(1)
		if frame == 30:
			Input.action_press("move_wasd_right")
		if frame == 50:
			_node("World/Player/Caster").call("cast_ability", 0, player.global_position + Vector2(200.0, 0.0))
		var levelup: Node = _node("UI/LevelUpModal")
		if levelup != null and levelup.visible:
			levelup.call("_choose", 0)
	Input.action_release("move_wasd_right")
	Input.action_release("attack_lmb")
