extends Area2D
## Collectable: xp shard, credits, heal orb or a location powerup. Drifts to the player inside
## the pickup radius (or always after a magnet), applies itself through GameState on touch.

const Db = preload("res://core/Db.gd")
const Neon = preload("res://core/Neon.gd")
const KIND_XP: String = "xp"
const KIND_CURRENCY: String = "currency"
const KIND_HEAL: String = "heal"
const KIND_POWERUP: String = "powerup"
const SHAPES: Dictionary = {"xp": "diamond", "currency": "square", "heal": "hex", "powerup": "star"}

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
	Neon.build_body(_visual, str(SHAPES.get(kind, "diamond")), size, _color_name())
	body_entered.connect(_on_body_entered)
	Signals.magnet_requested.connect(_on_magnet)


func _color_name() -> String:
	if kind == KIND_POWERUP:
		return Db.s(Db.entry("locations", "powerups", Db.s(extra, "id")), "color", "white")
	return Db.s(Db.cfg_d("pickups.colors"), kind, "white")


func is_magnetic() -> bool:
	return kind != KIND_POWERUP


func _on_magnet() -> void:
	if is_magnetic():
		_magnet = true


func _physics_process(delta: float) -> void:
	_visual.rotation += Db.cfg_f("pickups.spin_speed") * delta
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
