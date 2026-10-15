extends RefCounted
## Procedural placeholder pixel art for the tile atlas (32x32 cells): one painter per "art"
## style of data/tiles.json. Deterministic — each tile seeds its own RNG from its id.
## Tooling only (used by tools/build_world.gd); the game itself never paints tiles.

const Db = preload("res://core/Db.gd")
const CLEAR: Color = Color(0, 0, 0, 0)
const HALO_ALPHA: float = 0.35
const SPECK_AREA: float = 256.0


static func paint_atlas(spec: Dictionary) -> Image:
	var size: int = Db.i(spec, "tile_size")
	var image: Image = Image.create(size * Db.i(spec, "atlas_columns"), size * Db.i(spec, "atlas_rows"), false, Image.FORMAT_RGBA8)
	image.fill(CLEAR)
	for tile: Variant in Db.a(spec, "tiles"):
		var coords: Array = Db.a(tile, "atlas")
		var origin: Vector2i = Vector2i(int(Db.num(coords[0])) * size, int(Db.num(coords[1])) * size)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = hash(Db.s(tile, "id"))
		_paint(image, Rect2i(origin, Vector2i(size, size)), tile, rng)
	return image


static func _paint(img: Image, r: Rect2i, tile: Dictionary, rng: RandomNumberGenerator) -> void:
	var c: Dictionary = {
		"base": Color.html(Db.s(tile, "base")), "speck": Color.html(Db.s(tile, "speck")),
		"seam": Color.html(Db.s(tile, "seam")), "accent": Color.html(Db.s(tile, "accent")),
		"density": Db.f(tile, "density"),
	}
	match Db.s(tile, "art"):
		"floor", "puddle", "grid", "glow", "plate", "marble", "rune", "track":
			_paint_floor_style(img, r, Db.s(tile, "art"), c, rng)
		"brick", "rack", "overgrown", "girder", "pillar", "neon_block", "crate":
			_paint_wall_style(img, r, Db.s(tile, "art"), c, rng)
		"vines", "rail_h", "rail_v", "toxic", "static", "void":
			_paint_hazard_style(img, r, Db.s(tile, "art"), c, rng)
		_:
			_paint_decor_style(img, r, Db.s(tile, "art"), c, rng)


# ---------------------------------------------------------------- pen

static func px(img: Image, r: Rect2i, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < r.size.x and y < r.size.y:
		img.set_pixel(r.position.x + x, r.position.y + y, color)


static func fill(img: Image, r: Rect2i, x: int, y: int, w: int, h: int, color: Color) -> void:
	for dx: int in w:
		for dy: int in h:
			px(img, r, x + dx, y + dy, color)


static func frame(img: Image, r: Rect2i, inset: int, thickness: int, color: Color) -> void:
	var side: int = r.size.x - inset * 2
	fill(img, r, inset, inset, side, thickness, color)
	fill(img, r, inset, r.size.y - inset - thickness, side, thickness, color)
	fill(img, r, inset, inset, thickness, side, color)
	fill(img, r, r.size.x - inset - thickness, inset, thickness, side, color)


static func specks(img: Image, r: Rect2i, density: float, color: Color, rng: RandomNumberGenerator) -> void:
	for _index: int in int(density * SPECK_AREA):
		fill(img, r, rng.randi_range(0, r.size.x - 2), rng.randi_range(0, r.size.y - 2), 2, 2, color)


static func ellipse(img: Image, r: Rect2i, center: Vector2, radii: Vector2, color: Color) -> void:
	for x: int in r.size.x:
		for y: int in r.size.y:
			var d: Vector2 = (Vector2(x, y) - center) / radii
			if d.length() <= 1.0:
				px(img, r, x, y, color)


static func ring(img: Image, r: Rect2i, center: Vector2, radius: float, color: Color) -> void:
	for x: int in r.size.x:
		for y: int in r.size.y:
			if absf(Vector2(x, y).distance_to(center) - radius) < 0.8:
				px(img, r, x, y, color)


static func walk(img: Image, r: Rect2i, start: Vector2i, steps: int, bias: Vector2i, color: Color, rng: RandomNumberGenerator) -> void:
	var p: Vector2i = start
	for _step: int in steps:
		px(img, r, p.x, p.y, color)
		p += bias + Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
		p = Vector2i(clampi(p.x, 0, r.size.x - 1), clampi(p.y, 0, r.size.y - 1))


static func mid(r: Rect2i) -> Vector2:
	return Vector2(r.size) * 0.5 - Vector2.ONE * 0.5


# ---------------------------------------------------------------- floors

static func _paint_floor_style(img: Image, r: Rect2i, art: String, c: Dictionary, rng: RandomNumberGenerator) -> void:
	fill(img, r, 0, 0, r.size.x, r.size.y, c["base"])
	specks(img, r, float(c["density"]), c["speck"], rng)
	match art:
		"floor":
			fill(img, r, r.size.x - 1, 0, 1, r.size.y, c["seam"])
			fill(img, r, 0, r.size.y - 1, r.size.x, 1, c["seam"])
			px(img, r, rng.randi_range(2, r.size.x - 3), rng.randi_range(2, r.size.y - 3), c["accent"])
		"puddle":
			ellipse(img, r, mid(r) + Vector2(0, 2), Vector2(10, 5), (c["accent"] as Color).darkened(0.55))
			ellipse(img, r, mid(r) + Vector2(-2, 0), Vector2(5, 2), (c["accent"] as Color).darkened(0.15))
		"grid":
			_paint_circuit(img, r, c, rng)
		"glow":
			frame(img, r, 0, 2, c["seam"])
			fill(img, r, 6, 6, r.size.x - 12, r.size.y - 12, (c["accent"] as Color).darkened(0.35))
			fill(img, r, 10, 10, r.size.x - 20, r.size.y - 20, c["accent"])
			fill(img, r, 14, 14, r.size.x - 28, r.size.y - 28, (c["accent"] as Color).lightened(0.6))
		"plate":
			frame(img, r, 0, 1, c["seam"])
			for corner: Vector2i in [Vector2i(3, 3), Vector2i(r.size.x - 5, 3), Vector2i(3, r.size.y - 5), Vector2i(r.size.x - 5, r.size.y - 5)]:
				fill(img, r, corner.x, corner.y, 2, 2, (c["accent"] as Color).darkened(0.55))
		"marble":
			for _vein: int in 3:
				walk(img, r, Vector2i(rng.randi_range(0, r.size.x - 1), 0), r.size.y, Vector2i(0, 1), (c["accent"] as Color).darkened(0.5), rng)
		"rune":
			ring(img, r, mid(r), 10.0, c["accent"])
			fill(img, r, 15, 9, 2, 14, (c["accent"] as Color).darkened(0.2))
			fill(img, r, 9, 15, 14, 2, (c["accent"] as Color).darkened(0.2))
			fill(img, r, 15, 15, 2, 2, (c["accent"] as Color).lightened(0.6))
		"track":
			for x: int in range(2, r.size.x, 8):
				fill(img, r, x, 0, 3, r.size.y, c["speck"])
			fill(img, r, 0, 15, r.size.x, 2, c["accent"])


static func _paint_circuit(img: Image, r: Rect2i, c: Dictionary, rng: RandomNumberGenerator) -> void:
	fill(img, r, 0, 0, r.size.x, 1, c["seam"])
	fill(img, r, 0, 0, 1, r.size.y, c["seam"])
	var trace: Color = (c["accent"] as Color).darkened(0.4)
	for _index: int in 3:
		var start: Vector2i = Vector2i(rng.randi_range(4, r.size.x - 10), rng.randi_range(4, r.size.y - 10))
		var length: int = rng.randi_range(5, 10)
		fill(img, r, start.x, start.y, length, 1, trace)
		fill(img, r, start.x + length, start.y, 1, length, trace)
		fill(img, r, start.x - 1, start.y - 1, 2, 2, c["accent"])
		fill(img, r, start.x + length - 1, start.y + length - 1, 2, 2, c["accent"])


# ---------------------------------------------------------------- walls

static func _paint_wall_style(img: Image, r: Rect2i, art: String, c: Dictionary, rng: RandomNumberGenerator) -> void:
	match art:
		"brick":
			_paint_brick(img, r, c, rng)
		"rack":
			_paint_rack(img, r, c, rng)
		"overgrown":
			fill(img, r, 0, 0, r.size.x, r.size.y, c["base"])
			frame(img, r, 0, 2, c["seam"])
			specks(img, r, 0.05, c["speck"], rng)
			for _vine: int in 3:
				walk(img, r, Vector2i(rng.randi_range(2, r.size.x - 3), r.size.y - 1), r.size.y, Vector2i(0, -1), c["accent"], rng)
		"girder":
			_paint_girder(img, r, c)
		"pillar":
			fill(img, r, 0, 0, r.size.x, r.size.y, c["base"])
			for x: int in [7, 23]:
				fill(img, r, x, 0, 2, r.size.y, c["speck"])
			fill(img, r, 0, 0, r.size.x, 3, c["seam"])
			fill(img, r, 0, r.size.y - 3, r.size.x, 3, c["seam"])
			fill(img, r, 15, 3, 2, r.size.y - 6, c["accent"])
		"neon_block":
			fill(img, r, 0, 0, r.size.x, r.size.y, c["base"])
			frame(img, r, 0, 2, c["accent"])
			frame(img, r, 4, 1, c["speck"])
		"crate":
			fill(img, r, 0, 0, r.size.x, r.size.y, c["base"])
			for y: int in range(0, r.size.y, 8):
				fill(img, r, 0, y, r.size.x, 1, c["seam"])
			for i: int in r.size.x:
				fill(img, r, i, i, 2, 1, c["speck"])
			frame(img, r, 0, 2, c["seam"])
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(r.size.x - 3, 0), Vector2i(0, r.size.y - 3), Vector2i(r.size.x - 3, r.size.y - 3)]:
				fill(img, r, corner.x, corner.y, 3, 3, c["accent"])


static func _paint_brick(img: Image, r: Rect2i, c: Dictionary, rng: RandomNumberGenerator) -> void:
	fill(img, r, 0, 0, r.size.x, r.size.y, c["seam"])
	for row: int in 4:
		var y: int = 2 + row * 8
		var offset: int = 0 if row % 2 == 0 else -8
		for col: int in 3:
			var x: int = offset + col * 16
			fill(img, r, x + 1, y, 14, 7, (c["base"] as Color).lightened(rng.randf() * 0.08))
			fill(img, r, x + 2, y + 1, 3, 1, c["speck"])
	fill(img, r, 0, 0, r.size.x, 2, c["accent"])


static func _paint_rack(img: Image, r: Rect2i, c: Dictionary, rng: RandomNumberGenerator) -> void:
	fill(img, r, 0, 0, r.size.x, r.size.y, c["base"])
	frame(img, r, 0, 2, c["seam"])
	for y: int in range(4, r.size.y - 4, 6):
		fill(img, r, 3, y + 4, r.size.x - 6, 1, c["seam"])
		for x: int in [5, 8, 11]:
			if rng.randf() < 0.75:
				px(img, r, x, y + 1, c["accent"])
		fill(img, r, 16, y + 1, 12, 2, c["speck"])


static func _paint_girder(img: Image, r: Rect2i, c: Dictionary) -> void:
	fill(img, r, 0, 0, r.size.x, r.size.y, c["base"])
	for i: int in r.size.x:
		fill(img, r, i, i, 3, 1, c["speck"])
		fill(img, r, r.size.x - 1 - i, i, 3, 1, c["speck"])
	for x: int in r.size.x:
		var stripe: Color = c["accent"] if floori(float(x) / 4.0) % 2 == 0 else c["seam"]
		fill(img, r, x, 0, 1, 4, stripe)
		fill(img, r, x, r.size.y - 4, 1, 4, stripe)


# ---------------------------------------------------------------- hazards

static func _paint_hazard_style(img: Image, r: Rect2i, art: String, c: Dictionary, rng: RandomNumberGenerator) -> void:
	fill(img, r, 0, 0, r.size.x, r.size.y, c["base"])
	match art:
		"vines":
			for _strand: int in 4:
				walk(img, r, Vector2i(rng.randi_range(0, r.size.x - 1), 0), r.size.y + 8, Vector2i(0, 1), c["accent"], rng)
			specks(img, r, 0.03, (c["accent"] as Color).lightened(0.5), rng)
		"rail_h", "rail_v":
			_paint_rail(img, r, c, rng, art == "rail_v")
		"toxic":
			ellipse(img, r, mid(r), Vector2(12, 10), (c["accent"] as Color).darkened(0.35))
			ellipse(img, r, mid(r) + Vector2(-2, -1), Vector2(6, 4), c["accent"])
			for _bubble: int in 4:
				fill(img, r, rng.randi_range(8, 22), rng.randi_range(8, 22), 2, 2, c["seam"])
		"static":
			for _bolt: int in 3:
				walk(img, r, Vector2i(0, rng.randi_range(4, r.size.y - 5)), r.size.x, Vector2i(1, 0), c["accent"], rng)
			specks(img, r, 0.02, c["seam"], rng)
		"void":
			fill(img, r, 0, 0, r.size.x, r.size.y, c["base"])
			walk(img, r, Vector2i(rng.randi_range(4, 27), 0), r.size.y * 2, Vector2i(0, 1), c["accent"], rng)
			walk(img, r, Vector2i(0, rng.randi_range(4, 27)), r.size.x, Vector2i(1, 0), (c["accent"] as Color).darkened(0.3), rng)
			specks(img, r, 0.015, c["seam"], rng)


static func _paint_rail(img: Image, r: Rect2i, c: Dictionary, rng: RandomNumberGenerator, vertical: bool) -> void:
	for i: int in range(2, r.size.x, 8):
		if vertical:
			fill(img, r, 0, i, r.size.x, 3, c["speck"])
		else:
			fill(img, r, i, 0, 3, r.size.y, c["speck"])
	for lane: int in [10, 20]:
		if vertical:
			fill(img, r, lane, 0, 2, r.size.y, c["accent"])
		else:
			fill(img, r, 0, lane, r.size.x, 2, c["accent"])
	for _spark: int in 5:
		var along: int = rng.randi_range(0, r.size.x - 1)
		var lane_pick: int = 9 if rng.randf() < 0.5 else 22
		px(img, r, lane_pick if vertical else along, along if vertical else lane_pick, c["seam"])


# ---------------------------------------------------------------- decor

static func _paint_decor_style(img: Image, r: Rect2i, art: String, c: Dictionary, rng: RandomNumberGenerator) -> void:
	var halo: Color = c["accent"]
	halo.a = HALO_ALPHA
	match art:
		"sign":
			fill(img, r, 2, 8, 28, 16, halo)
			fill(img, r, 3, 9, 26, 14, c["base"])
			frame(img, Rect2i(r.position + Vector2i(3, 9), Vector2i(26, 14)), 0, 1, c["accent"])
			for x: int in range(6, 26, 3):
				fill(img, r, x, 13 + rng.randi_range(0, 1), 2, rng.randi_range(3, 5), c["accent"])
		"cable":
			for x: int in r.size.x:
				fill(img, r, x, 12 + roundi(sin(float(x) * 0.4) * 4.0), 1, 2, c["accent"])
				fill(img, r, x, 20 + roundi(cos(float(x) * 0.3) * 3.0), 1, 2, (c["accent"] as Color).darkened(0.4))
		"vent":
			fill(img, r, 6, 6, 20, 20, c["base"])
			for y: int in range(8, 25, 3):
				fill(img, r, 8, y, 16, 1, (c["accent"] as Color).darkened(0.3))
			frame(img, Rect2i(r.position + Vector2i(6, 6), Vector2i(20, 20)), 0, 1, c["seam"])
		"plant":
			_paint_plant(img, r, c, rng)
		"debris":
			for _chunk: int in 6:
				fill(img, r, rng.randi_range(2, 26), rng.randi_range(2, 26), rng.randi_range(2, 4), rng.randi_range(2, 3), c["base"] if rng.randf() < 0.6 else c["accent"])
		"rune_decor":
			ring(img, r, mid(r), 9.0, c["accent"])
			ring(img, r, mid(r), 10.0, halo)
			fill(img, r, 14, 14, 4, 4, c["base"])
		"lamp":
			fill(img, r, 15, 10, 2, 20, c["base"])
			fill(img, r, 10, 3, 12, 8, halo)
			fill(img, r, 12, 5, 8, 4, c["accent"])


static func _paint_plant(img: Image, r: Rect2i, c: Dictionary, rng: RandomNumberGenerator) -> void:
	for stem: int in 3:
		var x: int = 10 + stem * 6
		walk(img, r, Vector2i(x, r.size.y - 2), 18, Vector2i(0, -1), c["base"], rng)
		for leaf: int in 4:
			var y: int = r.size.y - 6 - leaf * 4
			fill(img, r, x - 3 + rng.randi_range(0, 1), y, 3, 1, c["accent"])
			fill(img, r, x + 1, y - 1, 3, 1, (c["accent"] as Color).darkened(0.2))
