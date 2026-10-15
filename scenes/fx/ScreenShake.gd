extends Camera2D
## Run camera. Follows the hero with frame-rate independent smoothing and leads towards the
## aim: while the mouse moves, the view slides towards the cursor (screen offset x aim_lead,
## at most aim_max_px). When the cursor rests for aim_idle_sec, or the game is paused by a
## modal (level-up, draft, inventory), it eases back onto the hero. Clamped to the location
## bounds; shakes on Signals.screen_shake_requested through `offset`, so shake never fights
## the follow. The wobble is time-based and never draws from the run RNG.

const Db = preload("res://core/Db.gd")
const WOBBLE_X: float = 71.0
const WOBBLE_Y: float = 53.0
const MSEC: float = 1000.0

var target: Node2D = null
var look: Vector2 = Vector2.ZERO
var _strength: float = 0.0
var _shake_left: float = 0.0
var _last_aim_msec: int = -100000


func _ready() -> void:
	Signals.screen_shake_requested.connect(shake)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > Db.cfg_f("camera.aim_motion_px"):
		_last_aim_msec = Time.get_ticks_msec()


func set_bounds(bounds: Rect2) -> void:
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.end.x)
	limit_bottom = int(bounds.end.y)


func snap_to_target() -> void:
	if target != null and is_instance_valid(target):
		look = Vector2.ZERO
		global_position = target.global_position
		reset_smoothing()


func shake(strength: float, duration_sec: float) -> void:
	_strength = minf(Db.cfg_f("camera.max_shake_px"), maxf(_strength, strength))
	_shake_left = maxf(_shake_left, duration_sec)


## True while the cursor moved recently and no modal pauses the run.
func aiming() -> bool:
	return not get_tree().paused and Time.get_ticks_msec() - _last_aim_msec < int(Db.cfg_f("camera.aim_idle_sec") * MSEC)


## Desired look-ahead: cursor offset from the screen centre, scaled and clamped.
func _aim_look() -> Vector2:
	var viewport: Viewport = get_viewport()
	var half: Vector2 = viewport.get_visible_rect().size * 0.5
	var cursor: Vector2 = viewport.get_mouse_position() - half
	return (cursor * Db.cfg_f("camera.aim_lead")).limit_length(Db.cfg_f("camera.aim_max_px"))


func _process(delta: float) -> void:
	if target != null and is_instance_valid(target):
		var aim: bool = aiming()
		var goal: Vector2 = _aim_look() if aim else Vector2.ZERO
		var rate: float = Db.cfg_f("camera.lead_rate") if aim else Db.cfg_f("camera.recenter_rate")
		look = look.lerp(goal, 1.0 - exp(-rate * delta))
		var follow: float = 1.0 - exp(-Db.cfg_f("camera.follow_rate") * delta)
		global_position = global_position.lerp(target.global_position + look, follow)
	_apply_shake(delta)


func _apply_shake(delta: float) -> void:
	if _shake_left <= 0.0:
		offset = Vector2.ZERO
		return
	_shake_left -= delta
	var t: float = float(Time.get_ticks_msec()) / MSEC
	offset = Vector2(sin(t * WOBBLE_X), cos(t * WOBBLE_Y)) * _strength
	_strength = maxf(0.0, _strength - Db.cfg_f("camera.shake_decay") * delta * _strength)
