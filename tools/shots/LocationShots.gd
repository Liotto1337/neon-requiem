extends Node
## Visual QA: renders every location around its player spawn and saves PNGs to $SHOTS_OUT.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 res://tools/shots/LocationShots.tscn

const Db = preload("res://core/Db.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_environment("SHOTS_OUT")
	for location: Variant in Db.list("locations", "locations"):
		var scene: Node2D = (load(Db.s(location, "scene")) as PackedScene).instantiate()
		add_child(scene)
		var camera: Camera2D = Camera2D.new()
		scene.add_child(camera)
		camera.global_position = scene.call("player_spawn") + Vector2(0, 260)
		camera.make_current()
		for _frame: int in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, Db.s(location, "id")])
		scene.queue_free()
		await get_tree().process_frame
	get_tree().quit()
