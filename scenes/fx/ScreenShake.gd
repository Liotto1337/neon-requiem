extends Camera2D
## Run camera: follows the target smoothly, clamps to the location bounds and shakes on
## Signals.screen_shake_requested. The jitter is a time-based wobble, so cosmetic shake never
## draws from the run RNG.

const Db = preload("res://core/Db.gd")
const WOBBLE_X: float = 71.0
const WOBBLE_Y: float = 53.0
const MSEC: float = 1000.0

var target: Node2D = null
var _strength: float = 0.0
var _shake_left: float = 0.0


func _ready() -> void:
	Signals.screen_shake_requested.connect(shake)


func set_bounds(bounds: Rect2) -> void:
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.end.x)
	limit_bottom = int(bounds.end.y)


func snap_to_target() -> void:
	if target != null and is_instance_valid(target):
		global_position = target.global_position
		reset_smoothing()


func shake(strength: float, duration_sec: float) -> void:
	_strength = minf(Db.cfg_f("camera.max_shake_px"), maxf(_strength, strength))
	_shake_left = maxf(_shake_left, duration_sec)


func _process(delta: float) -> void:
	if target != null and is_instance_valid(target):
		global_position = global_position.lerp(target.global_position, clampf(Db.cfg_f("camera.follow_speed") * delta, 0.0, 1.0))
	if _shake_left <= 0.0:
		offset = Vector2.ZERO
		return
	_shake_left -= delta
	var t: float = float(Time.get_ticks_msec()) / MSEC
	offset = Vector2(sin(t * WOBBLE_X), cos(t * WOBBLE_Y)) * _strength
	_strength = maxf(0.0, _strength - Db.cfg_f("camera.shake_decay") * delta * _strength)
