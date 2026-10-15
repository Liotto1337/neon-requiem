extends RefCounted
## Procedural neon shapes for effects (rings, zones, telegraphs, beams) and the shared glow
## setup. Entities, pickups and projectiles use code-drawn sprites (core/Sprites.gd).

const Db = preload("res://core/Db.gd")
const TRIANGLE_POINTS: int = 3
const DIAMOND_POINTS: int = 4
const HEX_POINTS: int = 6
const STAR_POINTS: int = 10
const STAR_INNER: float = 0.45
const SQUARE_HALF: float = 0.42
const BOLT_WIDTH: float = 0.35
const BODY_NAME: String = "Body"


## Outline points for a shape that fits a `size` x `size` box centred on the origin.
static func points(shape: String, size: float) -> PackedVector2Array:
	var r: float = size * 0.5
	match shape:
		"square":
			var h: float = size * SQUARE_HALF
			return snap(PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]))
		"diamond":
			return regular(DIAMOND_POINTS, r, 0.0)
		"triangle":
			return regular(TRIANGLE_POINTS, r, 0.0)
		"hex":
			return regular(HEX_POINTS, r, PI / HEX_POINTS)
		"star":
			return star(r)
		"bolt":
			return snap(PackedVector2Array([Vector2(r, 0), Vector2(0, r * BOLT_WIDTH), Vector2(-r, 0), Vector2(0, -r * BOLT_WIDTH)]))
	return regular(Db.cfg_i("art.circle_segments"), r, 0.0)


static func regular(count: int, radius: float, phase: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in count:
		out.append(Vector2.RIGHT.rotated(phase + TAU * float(i) / float(count)) * radius)
	return snap(out)


static func star(radius: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in STAR_POINTS:
		var length: float = radius if i % 2 == 0 else radius * STAR_INNER
		out.append(Vector2.UP.rotated(TAU * float(i) / float(STAR_POINTS)) * length)
	return snap(out)


## Rounds every vertex to the art pixel grid so edges read as pixel art.
static func snap(source: PackedVector2Array) -> PackedVector2Array:
	var px: float = maxf(1.0, Db.cfg_f("art.pixel_px"))
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in source:
		out.append(Vector2(roundf(p.x / px) * px, roundf(p.y / px) * px))
	return out


## Replaces the "Body" child of `parent` with fill + glowing rim + core. Returns the body.
static func build_body(parent: Node2D, shape: String, size: float, color_name: String) -> Node2D:
	var old: Node = parent.get_node_or_null(BODY_NAME)
	if old != null:
		old.free()
	var body: Node2D = Node2D.new()
	body.name = BODY_NAME
	var outline: PackedVector2Array = points(shape, size)
	body.add_child(_fill(outline, color_name))
	body.add_child(rim(outline, color_name, Db.cfg_f("art.edge_width")))
	body.add_child(_core(shape, size, color_name))
	parent.add_child(body)
	return body


static func _fill(outline: PackedVector2Array, color_name: String) -> Polygon2D:
	var poly: Polygon2D = Polygon2D.new()
	poly.polygon = outline
	var base: Color = Db.color(color_name).darkened(Db.cfg_f("art.fill_darken"))
	base.a = Db.cfg_f("art.fill_alpha")
	poly.color = base
	return poly


static func rim(outline: PackedVector2Array, color_name: String, width: float) -> Line2D:
	var line: Line2D = Line2D.new()
	line.points = outline
	line.closed = true
	line.width = width
	line.default_color = Db.glow(color_name)
	line.joint_mode = Line2D.LINE_JOINT_SHARP
	line.antialiased = false
	return line


static func _core(shape: String, size: float, color_name: String) -> Polygon2D:
	var poly: Polygon2D = Polygon2D.new()
	poly.polygon = points(shape, maxf(Db.cfg_f("art.pixel_px") * 2.0, size * Db.cfg_f("art.core_scale")))
	poly.color = Db.glow(color_name)
	return poly


## Closed ring polyline used for telegraphs, blasts and zones.
static func ring(radius: float, color: Color, width: float) -> Line2D:
	var line: Line2D = Line2D.new()
	line.points = regular(maxi(Db.cfg_i("art.circle_segments") * 2, 8), radius, 0.0)
	line.closed = true
	line.width = width
	line.default_color = color
	line.antialiased = false
	return line


## WorldEnvironment glow shared by the run, the hub and the main menu (data/config.json "glow").
static func configure_glow(env: Environment) -> void:
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_hdr_threshold = Db.cfg_f("glow.threshold")
	env.glow_intensity = Db.cfg_f("glow.intensity")
	env.glow_strength = Db.cfg_f("glow.strength")
	env.glow_bloom = Db.cfg_f("glow.bloom")
	env.glow_blend_mode = Db.cfg_i("glow.blend_mode") as Environment.GlowBlendMode
