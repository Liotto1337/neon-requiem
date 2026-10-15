extends Node
## Visual QA tour of the main menu and the hub: menu with hero cards, the hub room, every
## terminal window (skill tree graph, workshop, hero pod, records). PNGs go to $SHOTS_OUT.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 res://tools/shots/HubShots.tscn

const Db = preload("res://core/Db.gd")

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


func _scene() -> Node:
	return get_tree().current_scene


func _run() -> void:
	SaveManager.delete_all()
	MetaState.new_profile()
	MetaState.currency = 1500
	MetaState.meta_tree_nodes = {"o_power": 2, "o_crit": 1, "d_vitality": 3, "d_plating": 1, "u_stride": 1}
	var placeholder: Node = Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	get_tree().change_scene_to_file(Db.cfg_s("scenes.menu"))
	await _frames(12)
	await _shot("01_menu")
	get_tree().change_scene_to_file(Db.cfg_s("scenes.hub"))
	await _frames(12)
	await _shot("02_hub")
	for action: String in ["tree", "workshop", "heroes", "stats"]:
		_scene().call("use_terminal", action)
		await _frames(8)
		await _shot("03_" + action)
		_scene().call("_close_overlays")
		await _frames(2)
	var avatar: Node2D = _scene().get_node("World/Avatar")
	avatar.global_position = (_scene().get_node("World/HubRoom/Markers/tree") as Node2D).global_position + Vector2(90.0, 40.0)
	await _frames(10)
	await _shot("04_terminal_prompt")
	get_tree().quit()
