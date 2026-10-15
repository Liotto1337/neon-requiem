extends Node
## Hero sprite state machine over the code-drawn sheet "heroes/<id>" (data/sprites.json).
## One-shots by priority: hurt > levelup > cast > attack. The R action (reload / parry /
## recall) plays "reload" standing or "reload_run" while moving, stretched to its duration.
## Otherwise run / idle. Every clip has a side / down / up version picked from the aim
## direction (side is mirrored for the left). Player.animate() feeds it.

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
var facing: String = "side"


func setup(player: CharacterBody2D, visual: Node2D, hero_id: String) -> void:
	_player = player
	sprite = Sprites.attach(visual, "heroes/" + hero_id, "idle_side")
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
	sprite.play(Sprites.clip_for(sprite, kind, facing))
	sprite.frame = 0


func reloading() -> bool:
	return TimeService.run_msec() < _reload_until_msec


func _clip_length(clip: StringName) -> float:
	var frames: SpriteFrames = sprite.sprite_frames
	var clip_name: StringName = Sprites.clip_for(sprite, String(clip), facing)
	if not frames.has_animation(clip_name):
		return 1.0
	return float(frames.get_frame_count(clip_name)) / maxf(1.0, frames.get_animation_speed(clip_name))


func _on_finished() -> void:
	_one_shot = ""


func _process(_delta: float) -> void:
	if sprite == null or _player == null:
		return
	var aim: Vector2 = (_player.get("aim_position") as Vector2) - _player.global_position
	var new_facing: String = Sprites.facing(aim)
	sprite.flip_h = new_facing == "side" and aim.x < 0.0
	if new_facing != facing:
		facing = new_facing
		_refacing()
	if _one_shot != "":
		return
	var moving: bool = _player.velocity.length() > MOVE_THRESHOLD
	if reloading():
		_loop(CLIP_RELOAD_RUN if moving else CLIP_RELOAD, _reload_speed)
	else:
		_loop(CLIP_RUN if moving else CLIP_IDLE, 1.0)


## Same clip, new facing: keep the frame and progress.
func _refacing() -> void:
	var base: String = String(sprite.animation).trim_suffix("_side").trim_suffix("_down").trim_suffix("_up")
	var keep: int = sprite.frame
	var progress: float = sprite.frame_progress
	sprite.play(Sprites.clip_for(sprite, base, facing))
	sprite.set_frame_and_progress(mini(keep, sprite.sprite_frames.get_frame_count(sprite.animation) - 1), progress)


## Keeps a base clip running; switching between reload and reload_run keeps the frame.
func _loop(clip: StringName, speed: float) -> void:
	sprite.speed_scale = speed
	var clip_name: StringName = Sprites.clip_for(sprite, String(clip), facing)
	if sprite.animation == clip_name and sprite.is_playing():
		return
	var keep: int = sprite.frame if String(sprite.animation).begins_with("reload") else 0
	sprite.play(clip_name)
	sprite.frame = mini(keep, sprite.sprite_frames.get_frame_count(clip_name) - 1)
