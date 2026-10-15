extends RefCounted
## Code-drawn sprite sheets (tools/art/build_art.py) described by data/sprites.json:
## texture, frame size, pivot and clips. Builds and caches SpriteFrames per sprite id and
## makes AnimatedSprite2D nodes whose pivot sits on the parent's origin. Icons live in
## res://assets/icons/<kind>/<id>.png. All sprites share the SpriteFx shader material.

const Db = preload("res://core/Db.gd")
const TABLE: String = "sprites"
const ICON_DIR: String = "res://assets/icons/%s/%s.png"
const FX_MATERIAL: Material = preload("res://scenes/fx/sprite_fx.tres")
const OUTLINE_MATERIAL: Material = preload("res://scenes/fx/sprite_fx_outline.tres")

static var _frames: Dictionary = {}
static var _icons: Dictionary = {}


static func has(sprite_id: String) -> bool:
	return Db.table(TABLE).has(sprite_id)


static func entry(sprite_id: String) -> Dictionary:
	return Db.d(Db.table(TABLE), sprite_id)


## Frame size in pixels (Vector2.ZERO for an unknown id).
static func frame_size(sprite_id: String) -> Vector2:
	var size: Array = Db.a(entry(sprite_id), "frame")
	return Vector2(Db.num(size[0]), Db.num(size[1])) if size.size() == 2 else Vector2.ZERO


static func frames(sprite_id: String) -> SpriteFrames:
	if _frames.has(sprite_id):
		return _frames[sprite_id]
	var info: Dictionary = entry(sprite_id)
	var built: SpriteFrames = SpriteFrames.new()
	var texture: Texture2D = load(Db.s(info, "texture")) if ResourceLoader.exists(Db.s(info, "texture")) else null
	if texture == null:
		push_error("Sprites: missing sheet for '%s'" % sprite_id)
		_frames[sprite_id] = built
		return built
	built.remove_animation("default")
	var clips: Dictionary = Db.d(info, "clips")
	for clip_name: Variant in clips.keys():
		_add_clip(built, str(clip_name), Db.d(clips, str(clip_name)), texture, info)
	_frames[sprite_id] = built
	return built


static func _add_clip(built: SpriteFrames, clip_name: String, clip: Dictionary, texture: Texture2D, info: Dictionary) -> void:
	built.add_animation(clip_name)
	built.set_animation_speed(clip_name, Db.f(clip, "fps", 8.0))
	built.set_animation_loop(clip_name, bool(clip.get("loop", true)))
	var size: Vector2 = Vector2(Db.num(Db.a(info, "frame")[0]), Db.num(Db.a(info, "frame")[1]))
	var columns: int = maxi(1, Db.i(info, "columns", 1))
	for index: Variant in Db.a(clip, "frames"):
		var cell: int = int(Db.num(index))
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(Vector2(cell % columns, floori(float(cell) / float(columns))) * size, size)
		built.add_frame(clip_name, atlas)


## New AnimatedSprite2D playing `clip` (first clip when empty), pivot on the node origin.
static func make(sprite_id: String, clip: String = "") -> AnimatedSprite2D:
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.name = "Body"
	sprite.sprite_frames = frames(sprite_id)
	sprite.centered = false
	var pivot: Array = Db.a(entry(sprite_id), "pivot")
	if pivot.size() == 2:
		sprite.offset = -Vector2(Db.num(pivot[0]), Db.num(pivot[1]))
	sprite.material = FX_MATERIAL
	var names: PackedStringArray = sprite.sprite_frames.get_animation_names()
	if clip != "" and sprite.sprite_frames.has_animation(clip):
		sprite.play(clip)
	elif not names.is_empty():
		sprite.play(names[0])
	return sprite


## Replaces the "Body" child of `parent` with a sprite; random start frame for crowds.
static func attach(parent: Node2D, sprite_id: String, clip: String = "", random_start: float = -1.0) -> AnimatedSprite2D:
	var old: Node = parent.get_node_or_null("Body")
	if old != null:
		old.free()
	var sprite: AnimatedSprite2D = make(sprite_id, clip)
	parent.add_child(sprite)
	if random_start >= 0.0 and sprite.sprite_frames.get_frame_count(sprite.animation) > 0:
		sprite.frame = int(random_start * float(sprite.sprite_frames.get_frame_count(sprite.animation))) % sprite.sprite_frames.get_frame_count(sprite.animation)
	return sprite


## Outline material for elites and bosses: mode 0 single, 1 dual, 2 rainbow.
static func outline_material(colors: Array, mode: int, energy: float) -> ShaderMaterial:
	var material: ShaderMaterial = (OUTLINE_MATERIAL as ShaderMaterial).duplicate()
	material.set_shader_parameter("outline_mode", mode)
	material.set_shader_parameter("color_a", colors[0] if not colors.is_empty() else Color.WHITE)
	material.set_shader_parameter("color_b", colors[1] if colors.size() > 1 else (colors[0] if not colors.is_empty() else Color.WHITE))
	material.set_shader_parameter("outline_energy", energy)
	return material


static func icon(kind: String, icon_id: String) -> Texture2D:
	var key: String = kind + "/" + icon_id
	if not _icons.has(key):
		var path: String = ICON_DIR % [kind, icon_id]
		_icons[key] = load(path) if ResourceLoader.exists(path) else null
	return _icons[key]
