extends Node
## Hero sprite state machine over the code-drawn sheet "heroes/<id>" (data/sprites.json).
## One-shots by priority: hurt > levelup > cast > attack. The R action (reload / parry /
## recall) plays "reload" standing or "reload_run" while moving, stretched to its duration.
## Otherwise run / idle. The sprite faces the aim side. Player.animate() feeds it.

const Sprites = preload("res://core/Sprites.gd")
const MSEC: float = 1000.0
const MOVE_THRESHOLD: float = 24.0
const PRIORITY: Dictionary = {"attack": 1, "cast": 2, "levelup": 3, "hurt": 4}
const CLIP_IDLE: StringName = &"idle"
const CLIP_RUN: StringName = &"run"
const CLIP_RELOAD: StringName = &"reload"
const CLIP_RELOAD_RUN: StringName = &"reload_run"

var sprite: AnimatedSprite2D = null
var _player: CharacterBody2D = null
var _one_shot: String = ""
var _reload_until_msec: int = 0
var _reload_speed: float = 1.0


func setup(player: CharacterBody2D, visual: Node2D, hero_id: String) -> void:
	_player = player
	sprite = Sprites.attach(visual, "heroes/" + hero_id, String(CLIP_IDLE))
	sprite.animation_finished.connect(_on_finished)


## kind: attack | cast | levelup | hurt | reload. duration_sec stretches "reload" (0 = native).
func play(kind: String, duration_sec: float = 0.0) -> void:
	if sprite == null:
		return
	if kind == String(CLIP_RELOAD):
		var native: float = _clip_length(CLIP_RELOAD)
		var seconds: float = duration_sec if duration_sec > 0.0 else native
		_reload_until_msec = TimeService.deadline(seconds)
		_reload_speed = native / maxf(0.05, seconds)
		if _one_shot == "attack" or _one_shot == "cast":
			_one_shot = ""
		return
	if not PRIORITY.has(kind) or (_one_shot != "" and int(PRIORITY[_one_shot]) > int(PRIORITY[kind])):
		return
	_one_shot = kind
	sprite.speed_scale = 1.0
	sprite.play(StringName(kind))
	sprite.frame = 0


func reloading() -> bool:
	return TimeService.run_msec() < _reload_until_msec


func _clip_length(clip: StringName) -> float:
	var frames: SpriteFrames = sprite.sprite_frames
	if not frames.has_animation(clip):
		return 1.0
	return float(frames.get_frame_count(clip)) / maxf(1.0, frames.get_animation_speed(clip))


func _on_finished() -> void:
	_one_shot = ""


func _process(_delta: float) -> void:
	if sprite == null or _player == null:
		return
	sprite.flip_h = (_player.get("aim_position") as Vector2).x < _player.global_position.x
	if _one_shot != "":
		return
	var moving: bool = _player.velocity.length() > MOVE_THRESHOLD
	if reloading():
		_loop(CLIP_RELOAD_RUN if moving else CLIP_RELOAD, _reload_speed)
	else:
		_loop(CLIP_RUN if moving else CLIP_IDLE, 1.0)


## Keeps a base clip running; switching between reload and reload_run keeps the frame.
func _loop(clip: StringName, speed: float) -> void:
	sprite.speed_scale = speed
	if sprite.animation == clip and sprite.is_playing():
		return
	var keep: int = sprite.frame if (sprite.animation == CLIP_RELOAD or sprite.animation == CLIP_RELOAD_RUN) else 0
	sprite.play(clip)
	sprite.frame = mini(keep, sprite.sprite_frames.get_frame_count(clip) - 1)
