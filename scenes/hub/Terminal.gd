extends Node2D
## Hub terminal (portal, skill tree, workshop, hero pod, records): animated prop with a solid
## base, a name plate and an "E — action" prompt that lights up with a white outline while
## the hero stands within `radius`. Data: one entry of data/hub.json "terminals".

const Db = preload("res://core/Db.gd")
const Sprites = preload("res://core/Sprites.gd")
const BASE_RADIUS: float = 26.0
const PLATE_GAP: float = 10.0
const OUTLINE_ENERGY: float = 1.4

var data: Dictionary = {}
var _sprite: AnimatedSprite2D = null
var _plate: Label = null
var _active: bool = false


func setup(terminal: Dictionary) -> void:
	data = terminal
	_sprite = Sprites.attach(self, Db.s(terminal, "sprite"), "move", 0.0)
	var size: Vector2 = Sprites.frame_size(Db.s(terminal, "sprite"))
	_sprite.offset = -Vector2(size.x * 0.5, size.y - 8.0)
	_add_base()
	_plate = Label.new()
	_plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plate.add_theme_font_size_override("font_size", 16)
	_plate.add_theme_constant_override("outline_size", 6)
	_plate.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.05))
	_plate.size = Vector2(320.0, 26.0)
	_plate.position = Vector2(-160.0, -size.y - PLATE_GAP - 26.0)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)
	set_active(false)


func _add_base() -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = Db.layer_bit("wall")
	body.collision_mask = 0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = BASE_RADIUS
	shape.shape = circle
	shape.position = Vector2(0.0, -BASE_RADIUS * 0.5)
	body.add_child(shape)
	add_child(body)


func in_reach(point: Vector2) -> bool:
	return point.distance_to(global_position) <= Db.f(data, "radius", 100.0)


## Highlight while the hero can use it: outline + "E — prompt"; otherwise just the name.
func set_active(active: bool) -> void:
	_active = active
	if active:
		_sprite.material = Sprites.outline_material([Color(1.6, 1.6, 1.8)], 0, OUTLINE_ENERGY)
		_plate.text = "%s — %s" % [InputMapHelper.label("interact"), Db.s(data, "prompt")]
		_plate.add_theme_color_override("font_color", Db.color("amber"))
	else:
		_sprite.material = Sprites.FX_MATERIAL
		_plate.text = Db.s(data, "name")
		_plate.add_theme_color_override("font_color", Db.color("white"))


func is_active() -> bool:
	return _active
