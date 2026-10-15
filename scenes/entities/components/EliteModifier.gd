extends Node2D
## Elite modifier component: paints the outline glow (one colour per modifier, two colours for
## two modifiers, rainbow for three+), pulses the damage aura, applies antiheal near the
## player, heals the elite on hits (vampiric) and leaves a blast on death (explosive).

const Db = preload("res://core/Db.gd")
const ShotFactory = preload("res://scenes/entities/components/ShotFactory.gd")
const MSEC: float = 1000.0
const PERCENT: float = 100.0
const MODE_SINGLE: int = 0
const MODE_DUAL: int = 1
const MODE_RAINBOW: int = 2
const RING_INSET: float = 0.4

var _enemy: Node2D = null
var _mods: Array = []
var _effects: Dictionary = {}
var _next_pulse_msec: int = 0


func attach(enemy: Node2D, mods: Array) -> void:
	_enemy = enemy
	_mods = mods.duplicate()
	var colors: Array = []
	for id: Variant in _mods:
		var mod: Dictionary = Db.entry("elites", "modifiers", str(id))
		_effects[str(id)] = Db.d(mod, "effect")
		colors.append(Db.glow(Db.s(mod, "color", "white")))
	apply_outline(enemy.get("outline_fx"), colors, float(enemy.get("size_px")))


## Configures the shared EliteOutline shader on `rect` for the given glow colours.
static func apply_outline(rect: ColorRect, colors: Array, size_px: float) -> void:
	if rect == null or colors.is_empty():
		return
	var pad: float = Db.cfg_f("art.outline_pad_px")
	var side: float = size_px + pad * 2.0
	rect.size = Vector2(side, side)
	rect.position = -rect.size * 0.5
	var shader_material: ShaderMaterial = (rect.material as ShaderMaterial).duplicate()
	rect.material = shader_material
	var rainbow_from: int = Db.i(Db.d(Db.table("elites"), "base"), "rainbow_from")
	var mode: int = MODE_RAINBOW if colors.size() >= rainbow_from else (MODE_DUAL if colors.size() == 2 else MODE_SINGLE)
	shader_material.set_shader_parameter("color_a", colors[0])
	shader_material.set_shader_parameter("color_b", colors[1] if colors.size() > 1 else colors[0])
	shader_material.set_shader_parameter("mode", mode)
	shader_material.set_shader_parameter("ring_radius", (size_px * 0.5 + pad * RING_INSET) / side)
	shader_material.set_shader_parameter("thickness", Db.cfg_f("art.outline_thickness"))
	shader_material.set_shader_parameter("pixel_steps", Db.cfg_f("art.outline_pixel_steps"))
	shader_material.set_shader_parameter("energy", Db.cfg_f("glow.hdr_energy") * Db.f(Db.d(Db.table("elites"), "base"), "outline_boost", 1.0))
	rect.visible = true


func outline_mode() -> int:
	var rect: ColorRect = _enemy.get("outline_fx")
	return int((rect.material as ShaderMaterial).get_shader_parameter("mode"))


func has_mod(mod_id: String) -> bool:
	return _effects.has(mod_id)


func _physics_process(_delta: float) -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return
	var now: int = TimeService.run_msec()
	if now < _next_pulse_msec:
		return
	_next_pulse_msec = now + int(_pulse_interval() * MSEC)
	if _effects.has("aura"):
		_pulse_aura(_effects["aura"])
	if _effects.has("antiheal"):
		_antiheal_proximity(_effects["antiheal"])


func _pulse_interval() -> float:
	if _effects.has("aura"):
		return Db.f(_effects["aura"], "pulse_sec")
	if _effects.has("antiheal"):
		return Db.f(_effects["antiheal"], "aura_refresh_sec")
	return INF


func _pulse_aura(effect: Dictionary) -> void:
	var mult: float = 1.0 + Db.f(effect, "damage_pct") / PERCENT
	for body: Variant in ShotFactory.enemies_near(get_world_2d(), _enemy.global_position, Db.f(effect, "radius")):
		if body != _enemy and (body as Node).has_method("apply_aura"):
			body.call("apply_aura", mult, Db.f(effect, "buff_sec"))


func _antiheal_proximity(effect: Dictionary) -> void:
	var target: Variant = _enemy.get("target")
	if not target is Node2D or not is_instance_valid(target):
		return
	if (target as Node2D).global_position.distance_to(_enemy.global_position) <= Db.f(effect, "aura_radius"):
		GameState.apply_antiheal(Db.f(effect, "aura_refresh_sec") * 2.0)


## Extra fields for this elite's hits.
func hit_effects() -> Dictionary:
	if _effects.has("antiheal"):
		return {"antiheal_sec": Db.f(_effects["antiheal"], "antiheal_sec")}
	return {}


func on_damage_dealt(amount: float) -> void:
	if _effects.has("vampiric") and _enemy != null and is_instance_valid(_enemy):
		_enemy.call("heal", amount * Db.f(_effects["vampiric"], "heal_mult"))


## Called by EliteEnemy when it dies: explosive elites leave a delayed blast.
func on_enemy_died(enemy: Node2D) -> void:
	if not _effects.has("explosive"):
		return
	var effect: Dictionary = _effects["explosive"]
	var scaled: float = Db.f(effect, "damage") * Db.f(enemy.get("scaling"), "damage", 1.0)
	Signals.projectile_requested.emit(ShotFactory.enemy_blast(enemy.global_position, scaled, Db.f(effect, "radius"), Db.f(effect, "fuse"), "yellow", {"source": "explosive"}))
