extends Node2D
## Weapon held in the hand, Soul Knight style: a separate sprite (data/sprites.json
## "weapons/<id>") placed at the owner's hand for its facing, rotated to the owner's
## `aim_position`, mirrored vertically when aiming left and drawn behind the body when facing
## up. Shots leave muzzle_global() — the barrel / blade tip / staff orb. Melee swings rotate
## the blade through an arc around the aim.

const Db = preload("res://core/Db.gd")
const Sprites = preload("res://core/Sprites.gd")
const DEFAULT_HANDS: Dictionary = {"side": [2, 3], "down": [3, 3], "up": [-3, 1]}

var weapon_id: String = ""
var sprite: AnimatedSprite2D = null
var _owner: Node2D = null
var _hands: Dictionary = DEFAULT_HANDS
var _swing: float = 0.0
var _tween: Tween = null


func setup(owner_node: Node2D, sheet_id: String, hands: Dictionary = {}) -> void:
	_owner = owner_node
	weapon_id = sheet_id
	_hands = hands if not hands.is_empty() else DEFAULT_HANDS
	if sprite != null:
		sprite.free()
	sprite = Sprites.make(sheet_id, "idle")
	add_child(sprite)
	sprite.animation_finished.connect(func() -> void: _idle())


func _idle() -> void:
	if sprite != null and sprite.sprite_frames.has_animation(&"idle"):
		sprite.play(&"idle")


## Plays a weapon clip ("fire", "reload", "slash", "parry", "cast") when the sheet has it.
func play(clip: String) -> void:
	if sprite != null and sprite.sprite_frames.has_animation(StringName(clip)):
		sprite.play(StringName(clip))
		sprite.frame = 0


## Melee arc: from -half_deg to +half_deg around the aim over `seconds`.
func swing(half_deg: float, seconds: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_swing = deg_to_rad(-half_deg)
	_tween = create_tween()
	_tween.tween_property(self, "_swing", deg_to_rad(half_deg), maxf(0.05, seconds)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "_swing", 0.0, maxf(0.05, seconds) * 0.6)


func aim_direction() -> Vector2:
	if _owner == null:
		return Vector2.RIGHT
	var aim: Vector2 = _owner.get("aim_position") - _owner.global_position
	return aim.normalized() if aim.length_squared() > 1.0 else Vector2.RIGHT


func _process(_delta: float) -> void:
	if _owner == null or sprite == null:
		return
	var direction: Vector2 = aim_direction()
	var facing: String = Sprites.facing(direction)
	var hand: Array = _hands.get(facing, DEFAULT_HANDS[facing])
	var offset: Vector2 = Vector2(float(hand[0]), float(hand[1])) * Sprites.scale()
	if direction.x < 0.0:
		offset.x = -offset.x
	position = offset
	var left: bool = direction.x < 0.0
	scale = Vector2(1.0, -1.0 if left else 1.0)
	rotation = direction.angle() + (_swing if not left else -_swing)
	z_index = -1 if facing == "up" else 1


## World position the shots leave from.
func muzzle_global() -> Vector2:
	return to_global(Sprites.point(weapon_id, "muzzle")) if weapon_id != "" else global_position
