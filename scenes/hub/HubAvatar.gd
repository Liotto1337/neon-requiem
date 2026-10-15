extends CharacterBody2D
## The selected hero walking around the hub: WASD movement with the hero's base speed, the
## same HeroAnimator as in a run (idle / run, faces the walking direction), a drop shadow.
## No combat: the hub only needs movement, facing and the "cast" pose for interactions.

const Db = preload("res://core/Db.gd")
const Sprites = preload("res://core/Sprites.gd")
const FACING_REACH: float = 100.0
const SHADOW_ALPHA: float = 0.5
const SHADOW_SCALE: float = 1.4
const SHADOW_DROP: float = 22.0

var aim_position: Vector2 = Vector2.ZERO
var input_enabled: bool = true
var _speed: float = 250.0
var _facing: Vector2 = Vector2.RIGHT

@onready var _visual: Node2D = $Visual
@onready var animator: Node = $Animator


func setup(hero_id: String) -> void:
	var hero: Dictionary = Db.entry("heroes", "heroes", hero_id)
	_speed = Db.f(Db.d(hero, "stats"), "move_speed", 250.0)
	for child: Node in _visual.get_children():
		child.free()
	var shadow: AnimatedSprite2D = Sprites.make("fx/shadow")
	shadow.name = "Shadow"
	shadow.scale = Vector2.ONE * SHADOW_SCALE
	shadow.position = Vector2(0.0, SHADOW_DROP)
	shadow.modulate.a = SHADOW_ALPHA
	_visual.add_child(shadow)
	animator.call("setup", self, _visual, hero_id)


func _physics_process(_delta: float) -> void:
	var input: Vector2 = Vector2.ZERO
	if input_enabled:
		input = Input.get_vector("move_wasd_left", "move_wasd_right", "move_wasd_up", "move_wasd_down")
	velocity = input * _speed
	if input.x != 0.0:
		_facing = Vector2(signf(input.x), 0.0)
	aim_position = global_position + _facing * FACING_REACH
	move_and_slide()


func play(kind: String) -> void:
	animator.call("play", kind)
