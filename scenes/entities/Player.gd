extends CharacterBody2D
## Player hero: WASD movement, mouse aim, input dispatch to the attack and ability components,
## dash / blink movement, i-frames, contact damage polling, the sprite animator and the reload
## bar. Talks to the run only through GameState methods and Signals; the Run calls setup()
## and set_bounds().

const Db = preload("res://core/Db.gd")
const Sprites = preload("res://core/Sprites.gd")
const MSEC: float = 1000.0
const FLASH_ENERGY: float = 3.0
const IFRAME_ALPHA: float = 0.55
const SHADOW_ALPHA: float = 0.5
const SHADOW_SCALE: float = 1.4
const SHADOW_DROP: float = 22.0

var hero: Dictionary = {}
var aim_position: Vector2 = Vector2.ZERO
var _bounds: Rect2 = Rect2()
var _dash_until_msec: int = 0
var _dash_velocity: Vector2 = Vector2.ZERO
var _iframes_until_msec: int = 0
var _contact_ready_msec: int = 0
var _flash_until_msec: int = 0
var _input_enabled: bool = true
var _last_level: int = 0

@onready var _visual: Node2D = $Visual
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _attack: Node = $Attack
@onready var _caster: Node = $Caster
@onready var orbit_root: Node2D = $Orbit
@onready var animator: Node = $Animator
@onready var _reload_bar: Node2D = $ReloadBar


func setup(hero_id: String) -> void:
	hero = Db.entry("heroes", "heroes", hero_id)
	_add_shadow()
	animator.call("setup", self, _visual, Db.s(hero, "id"))
	_reload_bar.set("color", Db.glow(Db.s(hero, "color", "cyan")))
	_reload_bar.position = Vector2(0.0, -Db.cfg_f("ui.reload_bar_offset"))
	_reload_bar.visible = false
	_last_level = Db.i(GameState.resources, "level")
	if not Signals.resources_changed.is_connected(_on_resources):
		Signals.resources_changed.connect(_on_resources)
	_attack.call("setup", self, hero)
	_caster.call("setup", self)


func _add_shadow() -> void:
	var shadow: AnimatedSprite2D = Sprites.make("fx/shadow")
	shadow.name = "Shadow"
	shadow.scale = Vector2.ONE * SHADOW_SCALE
	shadow.position = Vector2(0.0, SHADOW_DROP)
	shadow.modulate.a = SHADOW_ALPHA
	_visual.add_child(shadow)


## Sprite + reload bar feedback. kind: attack | cast | levelup | hurt | reload.
## anim_sec stretches the reload clip (0 = native); bar_sec > 0 shows the reload bar.
func animate(kind: String, anim_sec: float = 0.0, bar_sec: float = 0.0) -> void:
	animator.call("play", kind, anim_sec)
	if bar_sec > 0.0:
		_reload_bar.call("start", bar_sec)


func _on_resources(resources: Dictionary) -> void:
	var level: int = Db.i(resources, "level")
	if level > _last_level and _last_level > 0:
		animate("levelup")
	_last_level = level


func set_bounds(bounds: Rect2) -> void:
	_bounds = bounds


func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	velocity = Vector2.ZERO


func hero_class() -> String:
	return Db.s(hero, "class")


func _physics_process(_delta: float) -> void:
	aim_position = get_global_mouse_position()
	_move()
	if _input_enabled:
		_handle_actions()
	_poll_contact()
	_update_visuals()


func _move() -> void:
	if TimeService.run_msec() < _dash_until_msec:
		velocity = _dash_velocity
	elif _input_enabled:
		var input: Vector2 = Input.get_vector("move_wasd_left", "move_wasd_right", "move_wasd_up", "move_wasd_down")
		velocity = input * GameState.stat("move_speed")
	move_and_slide()
	if _bounds.has_area():
		global_position = global_position.clamp(_bounds.position, _bounds.end)


func _handle_actions() -> void:
	if Input.is_action_pressed("attack_lmb"):
		_attack.call("primary", aim_position)
	if Input.is_action_just_pressed("attack_rmb"):
		_attack.call("empowered", aim_position)
	if Input.is_action_just_pressed("reload_r"):
		_attack.call("class_action", aim_position)
	for slot: int in Db.i(GameState.slot_limits, "abilities"):
		if Input.is_action_just_pressed(InputMapHelper.ability_action(slot)):
			_caster.call("cast_ability", slot, aim_position)
	for slot: int in Db.i(GameState.slot_limits, "active_items"):
		if Input.is_action_just_pressed(InputMapHelper.item_action(slot)):
			_caster.call("use_item", slot, aim_position)


## Dash along `direction` for `distance` px over `duration` s; optional i-frames.
func start_dash(direction: Vector2, distance: float, duration: float, iframes: bool) -> void:
	var safe_duration: float = maxf(0.01, duration)
	_dash_velocity = direction.normalized() * distance / safe_duration
	_dash_until_msec = TimeService.deadline(safe_duration)
	if iframes:
		grant_iframes(safe_duration)


## Instant move towards `point`, at most `max_range` px, stopping at walls.
func blink_to(point: Vector2, max_range: float) -> Vector2:
	var offset: Vector2 = (point - global_position).limit_length(max_range)
	var collision: KinematicCollision2D = move_and_collide(offset, true)
	if collision != null:
		offset = collision.get_travel()
	global_position += offset
	if _bounds.has_area():
		global_position = global_position.clamp(_bounds.position, _bounds.end)
	return global_position


func grant_iframes(seconds: float) -> void:
	_iframes_until_msec = maxi(_iframes_until_msec, TimeService.deadline(seconds))


func has_iframes() -> bool:
	return TimeService.run_msec() < _iframes_until_msec


## Incoming hit from enemy projectiles, blasts, lasers, hazards and contact.
func receive_hit(hit: Dictionary) -> Dictionary:
	if has_iframes():
		return {}
	if bool(_attack.call("try_parry", hit)):
		return {}
	var result: Dictionary = GameState.damage_player(hit)
	if result.is_empty():
		return {}
	grant_iframes(Db.cfg_f("player.hit_iframes_sec"))
	_flash_until_msec = TimeService.deadline(Db.cfg_f("player.flash_sec"))
	Signals.screen_shake_requested.emit(Db.cfg_f("player.hurt_shake"), Db.cfg_f("player.hurt_shake_sec"))
	animate("hurt")
	_answer_attacker(hit.get("attacker"), result)
	return result


## Thorns back to the attacker and the vampiric callback for elites.
func _answer_attacker(attacker: Variant, result: Dictionary) -> void:
	if not attacker is Node2D or not is_instance_valid(attacker):
		return
	var node: Node2D = attacker
	if node.has_method("on_damage_dealt"):
		node.call("on_damage_dealt", Db.f(result, "hp_damage"))
	if Db.f(result, "thorns") > 0.0 and node.has_method("receive_hit") and bool(result.get("contact", false)):
		node.call("receive_hit", {"damage": Db.f(result, "thorns"), "faction": "player", "source": "thorns"})


func _poll_contact() -> void:
	var now: int = TimeService.run_msec()
	if now < _contact_ready_msec:
		return
	for body: Node2D in _hurtbox.get_overlapping_bodies():
		if body.has_method("contact_hit") and not bool(body.call("is_dead")):
			var hit: Dictionary = body.call("contact_hit")
			_contact_ready_msec = now + int(Db.cfg_f("player.contact_cooldown_sec") * MSEC)
			_receive_contact(hit)
			return


func _receive_contact(hit: Dictionary) -> void:
	if has_iframes() or bool(_attack.call("try_parry", hit)):
		return
	var result: Dictionary = GameState.damage_player(hit)
	if result.is_empty():
		return
	result["contact"] = true
	grant_iframes(Db.cfg_f("player.hit_iframes_sec"))
	_flash_until_msec = TimeService.deadline(Db.cfg_f("player.flash_sec"))
	animate("hurt")
	Signals.screen_shake_requested.emit(Db.cfg_f("player.hurt_shake"), Db.cfg_f("player.hurt_shake_sec"))
	_answer_attacker(hit.get("attacker"), result)


func _update_visuals() -> void:
	var now: int = TimeService.run_msec()
	var body: CanvasItem = animator.get("sprite")
	if body == null:
		return
	if now < _flash_until_msec:
		body.modulate = Color(FLASH_ENERGY, FLASH_ENERGY, FLASH_ENERGY)
	else:
		body.modulate = Color(1.0, 1.0, 1.0, IFRAME_ALPHA if has_iframes() else 1.0)
