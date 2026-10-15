extends "res://scenes/Locations/LocationBase.gd"
## Ashen Rail: abandoned monorail yard. Moving hazard: a train runs along a random track row
## every few seconds after a flashing warning line; touching it hurts.

var _trains: Array = []
var _next_train_msec: int = 0


func _on_ready_flavor() -> void:
	_next_train_msec = TimeService.deadline(Db.f(Db.d(config, "flavor"), "train_interval_sec"))


func _tick_flavor(now: int, delta: float) -> void:
	var flavor: Dictionary = Db.d(config, "flavor")
	if now >= _next_train_msec:
		_next_train_msec = now + int(Db.f(flavor, "train_interval_sec") * MSEC)
		_launch_train(now, flavor)
	for train: Variant in _trains.duplicate():
		_update_train(train, now, delta, flavor)


func _launch_train(now: int, flavor: Dictionary) -> void:
	var tracks: Array = Db.a(Db.d(config, "layout"), "tracks")
	if tracks.is_empty():
		return
	var tile: float = float(floor_layer.tile_set.tile_size.y)
	var row: float = Db.num(LootRoller.pick(GameState.rng, tracks))
	var area: Rect2 = bounds()
	var y: float = area.position.y + (row + 1.0) * tile
	var direction: float = 1.0 if GameState.rng.randf() < 0.5 else -1.0
	var length: float = Db.f(flavor, "train_length_px")
	var warn: Line2D = Neon.ring(1.0, Db.glow(Db.s(flavor, "warn_color", "orange")), Db.f(flavor, "train_height_px") * 0.25)
	warn.closed = false
	warn.points = PackedVector2Array([Vector2(area.position.x, y), Vector2(area.end.x, y)])
	add_child(warn)
	var body: Node2D = _train_body(Vector2(length, Db.f(flavor, "train_height_px")), Db.s(flavor, "train_color", "amber"))
	body.position = Vector2(area.position.x - length if direction > 0.0 else area.end.x + length, y)
	body.visible = false
	add_child(body)
	_trains.append({"body": body, "warn": warn, "direction": direction, "start_msec": now + int(Db.f(flavor, "train_warn_sec") * MSEC)})


func _train_body(size: Vector2, color_name: String) -> Node2D:
	var half: Vector2 = size * 0.5
	var outline: PackedVector2Array = PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	var body: Node2D = Node2D.new()
	var fill: Polygon2D = Polygon2D.new()
	fill.polygon = outline
	fill.color = Db.color(color_name).darkened(Db.cfg_f("art.fill_darken"))
	body.add_child(fill)
	body.add_child(Neon.rim(outline, color_name, Db.cfg_f("art.edge_width") * 2.0))
	return body


func _update_train(train: Dictionary, now: int, delta: float, flavor: Dictionary) -> void:
	var body: Node2D = train["body"]
	var warn: Line2D = train["warn"]
	if now < Db.i(train, "start_msec"):
		warn.visible = floori(float(now) / (MSEC * Db.f(flavor, "warn_blink_sec"))) % 2 == 0
		return
	warn.visible = false
	body.visible = true
	body.position.x += Db.f(train, "direction") * Db.f(flavor, "train_speed") * delta
	var size: Vector2 = Vector2(Db.f(flavor, "train_length_px"), Db.f(flavor, "train_height_px"))
	if target != null and is_instance_valid(target) and Rect2(body.position - size * 0.5, size).has_point(target.global_position):
		target.call("receive_hit", {"damage": Db.f(flavor, "train_damage"), "source": "train"})
	var area: Rect2 = bounds()
	if body.position.x < area.position.x - size.x * 2.0 or body.position.x > area.end.x + size.x * 2.0:
		body.queue_free()
		warn.queue_free()
		_trains.erase(train)
