extends Area2D
## Collectable: xp shard, credits, heal orb or a location powerup. Drifts to the player inside
## the pickup radius (or always after a magnet), applies itself through GameState on touch.

const Db = preload("res://core/Db.gd")
const Sprites = preload("res://core/Sprites.gd")
const KIND_XP: String = "xp"
const KIND_CURRENCY: String = "currency"
const KIND_HEAL: String = "heal"
const KIND_POWERUP: String = "powerup"
const BOB_PX: float = 2.0
const BOB_SPEED: float = 4.0

var kind: String = KIND_XP
var value: float = 0.0
var extra: Dictionary = {}
var target: Node2D = null
var _speed: float = 0.0
var _magnet: bool = false
var _collected: bool = false

@onready var _collision: CollisionShape2D = $Collision
@onready var _visual: Node2D = $Visual


func setup(pickup_kind: String, amount: float, data: Dictionary, target_node: Node2D) -> void:
	kind = pickup_kind
	value = amount
	extra = data
	target = target_node


func _ready() -> void:
	var size: float = Db.f(Db.cfg_d("pickups.sizes"), kind)
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = size
	_collision.shape = shape
	collision_layer = Db.layer_bit("pickup")
	collision_mask = Db.layer_bit("player")
	Sprites.attach(_visual, _sprite_id(), "default", float(get_instance_id() % 11) / 11.0)
	body_entered.connect(_on_body_entered)
	Signals.magnet_requested.connect(_on_magnet)


func _sprite_id() -> String:
	if kind == KIND_POWERUP:
		return "fx/" + Db.s(extra, "id", "power_heal")
	return "fx/" + kind


func is_magnetic() -> bool:
	return kind != KIND_POWERUP


func _on_magnet() -> void:
	if is_magnetic():
		_magnet = true


func _physics_process(delta: float) -> void:
	_visual.position.y = sin(float(TimeService.run_msec()) * 0.001 * BOB_SPEED + float(get_instance_id() % 7)) * BOB_PX
	if _collected or target == null or not is_instance_valid(target) or not is_magnetic():
		return
	var to_target: Vector2 = target.global_position - global_position
	if not _magnet and to_target.length() > GameState.stat("pickup_radius"):
		_speed = 0.0
		return
	_speed = minf(Db.cfg_f("pickups.magnet_speed"), _speed + Db.cfg_f("pickups.magnet_accel") * delta)
	global_position += to_target.normalized() * minf(_speed * delta, to_target.length())


func _on_body_entered(body: Node2D) -> void:
	if _collected or body != target:
		return
	_collected = true
	GameState.collect_pickup(kind, value, extra)
	queue_free()
