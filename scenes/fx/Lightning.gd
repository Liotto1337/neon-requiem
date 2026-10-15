extends Node2D
## Animated chain lightning between hit points: a jagged Line2D textured with the code-drawn
## 4-frame strip "fx/lightning" (tiled along the bolt). Every `fx.lightning_flicker_sec` the
## path is re-jagged, the strip frame changes and a short fork may sprout, so the bolt crackles;
## sparks burst at every target and the whole bolt fades out over its duration. The jitter is
## cosmetic: a tiny local LCG, so it never touches the run RNG.

const Db = preload("res://core/Db.gd")
const Sprites = preload("res://core/Sprites.gd")
const SHEET: String = "fx/lightning"
const SPARK: String = "fx/spark"

var _points: PackedVector2Array = PackedVector2Array()
var _color: Color = Color.WHITE
var _life: float = 0.0
var _total: float = 0.2
var _flicker: float = 0.0
var _frame: int = 0
var _state: int = 1
var _bolt: Line2D = null
var _fork: Line2D = null
static var _strips: Dictionary = {}


func setup(points: PackedVector2Array, color: Color, duration_sec: float) -> void:
	_points = points
	_color = color
	_total = maxf(0.05, duration_sec)
	_life = _total
	_state = absi(hash(points)) | 1


func _ready() -> void:
	_bolt = _make_line(Db.cfg_f("fx.lightning_width"))
	_fork = _make_line(Db.cfg_f("fx.lightning_width") * 0.5)
	for index: int in range(1, _points.size()):
		var spark: AnimatedSprite2D = Sprites.make(SPARK, "default")
		spark.material = null
		spark.modulate = _color
		spark.position = _points[index]
		add_child(spark)
	_rebuild()


func _make_line(width: float) -> Line2D:
	var line: Line2D = Line2D.new()
	line.width = width
	line.default_color = _color
	line.texture_mode = Line2D.LINE_TEXTURE_TILE
	line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	line.joint_mode = Line2D.LINE_JOINT_SHARP
	add_child(line)
	return line


## Next value in [lo, hi] from a 31-bit linear congruential generator.
func _rand(lo: float, hi: float) -> float:
	_state = (_state * 1103515245 + 12345) & 0x7fffffff
	return lo + (hi - lo) * float(_state) / float(0x7fffffff)


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	modulate.a = clampf(_life / _total * 1.5, 0.0, 1.0)
	_flicker -= delta
	if _flicker <= 0.0:
		_flicker = Db.cfg_f("fx.lightning_flicker_sec")
		_rebuild()


## New jagged path through the hit points, next strip frame, maybe a fork.
func _rebuild() -> void:
	_frame = (_frame + 1) % 4
	_bolt.texture = _strip(_frame)
	_fork.texture = _bolt.texture
	var path: PackedVector2Array = PackedVector2Array()
	var step: float = Db.cfg_f("fx.lightning_step_px")
	var jag: float = Db.cfg_f("fx.lightning_jag_px")
	for index: int in range(_points.size() - 1):
		var a: Vector2 = _points[index]
		var b: Vector2 = _points[index + 1]
		var pieces: int = maxi(1, int(a.distance_to(b) / step))
		var normal: Vector2 = (b - a).normalized().orthogonal()
		for piece: int in pieces:
			var t: float = float(piece) / float(pieces)
			var wobble: float = 0.0 if piece == 0 else _rand(-jag, jag)
			path.append(a.lerp(b, t) + normal * wobble)
	path.append(_points[_points.size() - 1])
	_bolt.points = path
	_build_fork(path)


## Strip frame without the sheet's transparent side padding, so the tiles join seamlessly.
static func _strip(frame: int) -> Texture2D:
	if not _strips.has(frame):
		var cell: Texture2D = Sprites.frame_texture(SHEET, "default", frame)
		var image: Image = cell.get_image() if cell != null else null
		if image == null or image.get_used_rect().size.x == 0:
			_strips[frame] = cell
		else:
			var used: Rect2i = image.get_used_rect()
			_strips[frame] = ImageTexture.create_from_image(image.get_region(Rect2i(used.position.x, 0, used.size.x, image.get_height())))
	return _strips[frame]


func _build_fork(path: PackedVector2Array) -> void:
	_fork.clear_points()
	if path.size() < 3 or _rand(0.0, 1.0) > 0.6:
		return
	var start: int = clampi(int(_rand(1.0, float(path.size() - 1))), 1, path.size() - 2)
	var direction: Vector2 = (path[start + 1] - path[start]).normalized().rotated(_rand(-1.0, 1.0))
	var point: Vector2 = path[start]
	_fork.add_point(point)
	for _piece: int in 3:
		point += direction.rotated(_rand(-0.6, 0.6)) * Db.cfg_f("fx.lightning_step_px") * 0.6
		_fork.add_point(point)
