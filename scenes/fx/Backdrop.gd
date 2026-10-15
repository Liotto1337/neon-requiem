extends CanvasLayer
## Night backdrop behind the map (assets/tiles/backdrop.png, tiled x art.pixel_scale): far neon
## towers that scroll slower than the world (camera.backdrop_parallax), so the map edges and
## the gaps beyond the walls show depth. Lives on canvas layer -10, under everything.

const Db = preload("res://core/Db.gd")
const Sprites = preload("res://core/Sprites.gd")
const TEXTURE: Texture2D = preload("res://assets/tiles/backdrop.png")

var _rect: TextureRect = null


func _ready() -> void:
	layer = -10
	follow_viewport_enabled = false
	_rect = TextureRect.new()
	_rect.texture = TEXTURE
	_rect.stretch_mode = TextureRect.STRETCH_TILE
	_rect.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.scale = Vector2.ONE * Sprites.scale()
	add_child(_rect)


func _process(_delta: float) -> void:
	var tile: Vector2 = Vector2(TEXTURE.get_size()) * Sprites.scale()
	var view: Vector2 = get_viewport().get_visible_rect().size
	_rect.size = (view + tile * 2.0) / Sprites.scale()
	var camera: Camera2D = get_viewport().get_camera_2d()
	var origin: Vector2 = camera.get_screen_center_position() if camera != null else Vector2.ZERO
	var shift: Vector2 = origin * Db.cfg_f("camera.backdrop_parallax")
	_rect.position = -Vector2(fposmod(shift.x, tile.x), fposmod(shift.y, tile.y)) - tile * 0.5
