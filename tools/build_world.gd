extends Node
## World builder (run once, or after changing data/tiles.json / locations.json layouts):
##   godot --headless --path . res://tools/BuildWorld.tscn
## Runs as a scene so the location scripts compile against the autoloads.
## 1. Builds the TileSet from the code-drawn atlas assets/tiles/neon_atlas.png (64x64 tiles,
##    made by `python3 tools/art/build_art.py tiles` from data/tiles.json): physics layer =
##    wall, custom data "collision" and "tile_id", floor variants, animated hazards.
## 2. Assembles every location scene from its "layout" block: Floor / Walls / Decor
##    TileMapLayers + Markers. Wall cells with open floor below get the "face" tile (3/4 view).
##    The saved .tscn files stay editable in the editor.

const Db = preload("res://core/Db.gd")
const LAYER_FLOOR_Z: int = -10
const LAYER_DECOR_Z: int = -8
const LAYER_WALL_Z: int = -6
const BOSS_OFFSET_CELLS: int = 8
const SPOT_ATTEMPTS: int = 400

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _tiles: Dictionary = {}


func _ready() -> void:
	var ok: bool = _build()
	get_tree().quit(0 if ok else 1)


func _build() -> bool:
	for tile: Variant in Db.list("tiles", "tiles"):
		_tiles[Db.s(tile, "id")] = tile
	var atlas: Texture2D = load(Db.s(Db.table("locations"), "atlas"))
	if atlas == null:
		push_error("build_world: run tools/art/build_art.py tiles and import the project first")
		return false
	var tileset: TileSet = _make_tileset(atlas)
	var tileset_path: String = Db.s(Db.table("locations"), "tileset")
	if ResourceSaver.save(tileset, tileset_path) != OK:
		push_error("build_world: cannot save %s" % tileset_path)
		return false
	var saved: TileSet = load(tileset_path)
	for location: Variant in Db.list("locations", "locations"):
		if not _build_location(location, saved):
			return false
	return true


# ---------------------------------------------------------------- tileset

func _make_tileset(texture: Texture2D) -> TileSet:
	var size: int = Db.i(Db.table("tiles"), "tile_size")
	var tileset: TileSet = TileSet.new()
	tileset.tile_size = Vector2i(size, size)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, Db.layer_bit("wall"))
	tileset.set_physics_layer_collision_mask(0, 0)
	for layer_name: String in ["collision", "tile_id"]:
		var index: int = tileset.get_custom_data_layers_count()
		tileset.add_custom_data_layer()
		tileset.set_custom_data_layer_name(index, layer_name)
		tileset.set_custom_data_layer_type(index, TYPE_STRING)
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(size, size)
	tileset.add_source(source, Db.i(Db.table("tiles"), "source_id"))
	for tile: Variant in _tiles.values():
		_add_tile(source, tile, float(size) * 0.5)
	return tileset


func _add_tile(source: TileSetAtlasSource, tile: Dictionary, half: float) -> void:
	for variant: int in maxi(1, Db.i(tile, "variants", 1)):
		_add_cell(source, tile, _atlas(tile) + Vector2i(variant, 0), half)
	var frames: int = Db.i(tile, "frames", 1)
	if frames > 1:
		source.set_tile_animation_columns(_atlas(tile), frames)
		source.set_tile_animation_frames_count(_atlas(tile), frames)
		for frame: int in frames:
			source.set_tile_animation_frame_duration(_atlas(tile), frame, Db.f(Db.table("tiles"), "frame_sec", 0.2))


func _add_cell(source: TileSetAtlasSource, tile: Dictionary, coords: Vector2i, half: float) -> void:
	source.create_tile(coords)
	var data: TileData = source.get_tile_data(coords, 0)
	data.set_custom_data("collision", Db.s(tile, "collision"))
	data.set_custom_data("tile_id", Db.s(tile, "id"))
	if Db.s(tile, "collision") == "solid":
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half),
		]))


func _atlas(tile: Dictionary) -> Vector2i:
	var coords: Array = Db.a(tile, "atlas")
	return Vector2i(int(Db.num(coords[0])), int(Db.num(coords[1])))


# ---------------------------------------------------------------- locations

func _build_location(location: Dictionary, tileset: TileSet) -> bool:
	var layout: Dictionary = Db.d(location, "layout")
	_rng.seed = Db.i(layout, "seed")
	var size: Vector2i = Vector2i(int(Db.num(Db.a(layout, "size")[0])), int(Db.num(Db.a(layout, "size")[1])))
	var root: Node2D = Node2D.new()
	root.name = Db.s(location, "node_name")
	root.set_script(load(Db.s(location, "script")))
	root.set("location_id", Db.s(location, "id"))
	var floor_layer: TileMapLayer = _layer(root, "Floor", tileset, LAYER_FLOOR_Z)
	var wall_layer: TileMapLayer = _layer(root, "Walls", tileset, LAYER_WALL_Z)
	var decor_layer: TileMapLayer = _layer(root, "Decor", tileset, LAYER_DECOR_Z)
	var solid: Dictionary = _plan_walls(layout, size)
	_paint_floor(floor_layer, layout, size)
	var hazards: Dictionary = _paint_hazards(floor_layer, layout, size, solid)
	_paint_walls(wall_layer, layout, size, solid)
	_paint_decor(decor_layer, layout, size, solid, hazards)
	_add_markers(root, layout, size, solid, tileset.tile_size.x)
	var scene: PackedScene = PackedScene.new()
	if scene.pack(root) != OK or ResourceSaver.save(scene, Db.s(location, "scene")) != OK:
		push_error("build_world: cannot save %s" % Db.s(location, "scene"))
		return false
	root.free()
	return true


func _layer(root: Node2D, layer_name: String, tileset: TileSet, z: int) -> TileMapLayer:
	var layer: TileMapLayer = TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tileset
	layer.z_index = z
	root.add_child(layer)
	layer.owner = root
	return layer


func _put(layer: TileMapLayer, cell: Vector2i, tile_id: String) -> void:
	if _tiles.has(tile_id):
		var tile: Dictionary = _tiles[tile_id]
		var variant: int = _variant(tile)
		layer.set_cell(cell, Db.i(Db.table("tiles"), "source_id"), _atlas(tile) + Vector2i(variant, 0))


func _variant(tile: Dictionary) -> int:
	var weights: Array = Db.a(tile, "variant_weights")
	if weights.is_empty():
		return _rng.randi_range(0, maxi(1, Db.i(tile, "variants", 1)) - 1)
	var table: Dictionary = {}
	for index: int in weights.size():
		table[str(index)] = weights[index]
	return int(_weighted(table))


func _weighted(weights: Dictionary) -> String:
	var keys: Array = weights.keys()
	var values: Array = []
	for key: Variant in keys:
		values.append(Db.num(weights[key]))
	var total: float = 0.0
	for value: Variant in values:
		total += float(value)
	var roll: float = _rng.randf() * total
	for index: int in keys.size():
		roll -= float(values[index])
		if roll < 0.0:
			return str(keys[index])
	return str(keys[keys.size() - 1])


func _paint_floor(layer: TileMapLayer, layout: Dictionary, size: Vector2i) -> void:
	var weights: Dictionary = Db.d(layout, "floor")
	for x: int in size.x:
		for y: int in size.y:
			_put(layer, Vector2i(x, y), _weighted(weights))
	if Db.s(layout, "style") == "rail":
		for row: Variant in Db.a(layout, "tracks"):
			for x: int in size.x:
				for dy: int in Db.i(layout, "track_width", 2):
					_put(layer, Vector2i(x, int(Db.num(row)) + dy), Db.s(layout, "track_tile"))


func _center(size: Vector2i) -> Vector2i:
	return Vector2i(floori(float(size.x) * 0.5), floori(float(size.y) * 0.5))


func _near_center(cell: Vector2i, size: Vector2i, layout: Dictionary) -> bool:
	return Vector2(cell - _center(size)).length() < Db.f(layout, "clear_radius")


func _inside(cell: Vector2i, size: Vector2i) -> bool:
	return cell.x > 0 and cell.y > 0 and cell.x < size.x - 1 and cell.y < size.y - 1


## Interior wall cells by layout style; the border is painted separately.
func _plan_walls(layout: Dictionary, size: Vector2i) -> Dictionary:
	var solid: Dictionary = {}
	match Db.s(layout, "style"):
		"alleys":
			_plan_alleys(layout, size, solid)
		"racks":
			_plan_racks(layout, size, solid)
		"garden":
			_plan_blobs(layout, size, solid)
		"rail":
			_plan_chunks(layout, size, solid)
		"arena":
			_plan_arena(layout, size, solid)
	for cell: Variant in solid.keys():
		if _near_center(cell, size, layout) or not _inside(cell, size):
			solid.erase(cell)
	return solid


func _length(layout: Dictionary) -> int:
	var bounds: Array = Db.a(layout, "feature_len")
	return _rng.randi_range(int(Db.num(bounds[0])), int(Db.num(bounds[1])))


func _plan_alleys(layout: Dictionary, size: Vector2i, solid: Dictionary) -> void:
	var gap: int = Db.i(layout, "feature_gap")
	for _index: int in Db.i(layout, "features"):
		var horizontal: bool = _rng.randf() < 0.5
		var start: Vector2i = Vector2i(_rng.randi_range(2, size.x - 3), _rng.randi_range(2, size.y - 3))
		var length: int = _length(layout)
		for step: int in length:
			if gap > 0 and step % (gap * 3) >= gap * 2:
				continue
			var cell: Vector2i = start + (Vector2i(step, 0) if horizontal else Vector2i(0, step))
			solid[cell] = true
			solid[cell + (Vector2i(0, 1) if horizontal else Vector2i(1, 0))] = true


func _plan_racks(layout: Dictionary, size: Vector2i, solid: Dictionary) -> void:
	var step_y: int = maxi(3, Db.i(layout, "rack_row_step"))
	var gap: int = Db.i(layout, "feature_gap")
	for y: int in range(step_y, size.y - 2, step_y):
		var x: int = 3 + _rng.randi_range(0, gap)
		while x < size.x - 3:
			var length: int = _length(layout)
			for dx: int in length:
				solid[Vector2i(x + dx, y)] = true
			x += length + gap + _rng.randi_range(0, gap)


func _plan_blobs(layout: Dictionary, size: Vector2i, solid: Dictionary) -> void:
	for _index: int in Db.i(layout, "features"):
		var center: Vector2i = Vector2i(_rng.randi_range(3, size.x - 4), _rng.randi_range(3, size.y - 4))
		var radius: int = _length(layout)
		for dx: int in range(-radius, radius + 1):
			for dy: int in range(-radius, radius + 1):
				if Vector2(dx, dy).length() <= float(radius) * 0.75:
					solid[center + Vector2i(dx, dy)] = true


func _plan_chunks(layout: Dictionary, size: Vector2i, solid: Dictionary) -> void:
	var tracks: Array = []
	for row: Variant in Db.a(layout, "tracks"):
		for dy: int in Db.i(layout, "track_width", 2):
			tracks.append(int(Db.num(row)) + dy)
	for _index: int in Db.i(layout, "features"):
		var origin: Vector2i = Vector2i(_rng.randi_range(3, size.x - 8), _rng.randi_range(3, size.y - 8))
		var extent: Vector2i = Vector2i(_length(layout), _rng.randi_range(2, 3))
		for dx: int in extent.x:
			for dy: int in extent.y:
				var cell: Vector2i = origin + Vector2i(dx, dy)
				if not tracks.has(cell.y) and not tracks.has(cell.y - 1) and not tracks.has(cell.y + 1):
					solid[cell] = true


func _plan_arena(layout: Dictionary, size: Vector2i, solid: Dictionary) -> void:
	var center: Vector2 = Vector2(_center(size))
	var radius: float = Db.f(layout, "arena_radius")
	for x: int in size.x:
		for y: int in size.y:
			if Vector2(x, y).distance_to(center) > radius:
				solid[Vector2i(x, y)] = Db.s(layout, "outer_wall", Db.s(layout, "wall"))
	var count: int = Db.i(layout, "pillars")
	for index: int in count:
		var spot: Vector2 = center + Vector2.RIGHT.rotated(TAU * float(index) / float(maxi(1, count))) * Db.f(layout, "pillar_ring")
		var cell: Vector2i = Vector2i(roundi(spot.x), roundi(spot.y))
		for offset: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			solid[cell + offset] = true


## Wall tiles by cell (interior + border); a wall with open floor below shows its face tile.
func _paint_walls(layer: TileMapLayer, layout: Dictionary, size: Vector2i, solid: Dictionary) -> void:
	var walls: Dictionary = {}
	for cell: Variant in solid.keys():
		walls[cell] = solid[cell] if solid[cell] is String else Db.s(layout, "wall")
	for x: int in size.x:
		walls[Vector2i(x, 0)] = Db.s(layout, "border")
		walls[Vector2i(x, size.y - 1)] = Db.s(layout, "border")
	for y: int in size.y:
		walls[Vector2i(0, y)] = Db.s(layout, "border")
		walls[Vector2i(size.x - 1, y)] = Db.s(layout, "border")
	for cell: Variant in walls.keys():
		var tile_id: String = str(walls[cell])
		var below: Vector2i = (cell as Vector2i) + Vector2i(0, 1)
		var face: String = Db.s(Db.d(_tiles, tile_id), "face")
		_put(layer, cell, face if face != "" and not walls.has(below) and below.y < size.y else tile_id)


func _paint_hazards(layer: TileMapLayer, layout: Dictionary, size: Vector2i, solid: Dictionary) -> Dictionary:
	var hazards: Dictionary = {}
	var radius_bounds: Array = Db.a(layout, "hazard_radius")
	for _index: int in Db.i(layout, "hazard_patches"):
		var center: Vector2i = _random_open_cell(layout, size, solid)
		var radius: int = _rng.randi_range(int(Db.num(radius_bounds[0])), int(Db.num(radius_bounds[1])))
		for dx: int in range(-radius, radius + 1):
			for dy: int in range(-radius, radius + 1):
				var cell: Vector2i = center + Vector2i(dx, dy)
				if Vector2(dx, dy).length() <= float(radius) + 0.4 and _inside(cell, size) and not solid.has(cell) and not _near_center(cell, size, layout):
					_put(layer, cell, Db.s(layout, "hazard_tile"))
					hazards[cell] = true
	return hazards


func _random_open_cell(layout: Dictionary, size: Vector2i, solid: Dictionary) -> Vector2i:
	var cell: Vector2i = _center(size)
	for _attempt: int in SPOT_ATTEMPTS:
		cell = Vector2i(_rng.randi_range(2, size.x - 3), _rng.randi_range(2, size.y - 3))
		if not solid.has(cell) and not _near_center(cell, size, layout):
			return cell
	return cell


func _paint_decor(layer: TileMapLayer, layout: Dictionary, size: Vector2i, solid: Dictionary, hazards: Dictionary) -> void:
	var weights: Dictionary = Db.d(layout, "decor")
	var density: float = Db.f(layout, "decor_density")
	for x: int in range(1, size.x - 1):
		for y: int in range(1, size.y - 1):
			var cell: Vector2i = Vector2i(x, y)
			if not solid.has(cell) and not hazards.has(cell) and _rng.randf() < density:
				_put(layer, cell, _weighted(weights))


func _add_markers(root: Node2D, layout: Dictionary, size: Vector2i, solid: Dictionary, tile: int) -> void:
	var markers: Node2D = _marker(root, root, "Markers", Vector2.ZERO)
	var center: Vector2i = _center(size)
	_marker(root, markers, "PlayerSpawn", _cell_center(center, tile))
	_marker(root, markers, "BossSpawn", _cell_center(center - Vector2i(0, BOSS_OFFSET_CELLS), tile))
	var group: Node2D = _marker(root, markers, "Powerups", Vector2.ZERO)
	for index: int in Db.i(layout, "powerup_spots"):
		var cell: Vector2i = _random_open_cell(layout, size, solid)
		_marker(root, group, "Spot%d" % index, _cell_center(cell, tile))


func _marker(root: Node2D, parent: Node, marker_name: String, position: Vector2) -> Node2D:
	var marker: Marker2D = Marker2D.new()
	marker.name = marker_name
	marker.position = position
	parent.add_child(marker)
	marker.owner = root
	return marker


func _cell_center(cell: Vector2i, tile: int) -> Vector2:
	return Vector2(cell * tile) + Vector2.ONE * float(tile) * 0.5
