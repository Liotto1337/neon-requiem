extends "res://scenes/entities/Enemy.gd"
## Enemy with 1..3 elite modifiers from data/elites.json. Stat changes (HP, berserk damage
## and speed, shield) happen in setup(); the EliteModifier child owns the outline glow,
## aura pulses, antiheal, vampiric heals and the explosive death blast.

@onready var modifier: Node2D = $EliteModifier


func setup(config: Dictionary, target_node: Node2D, tier_scaling: Dictionary, elite_mods: Array) -> void:
	super.setup(config, target_node, tier_scaling, elite_mods)
	is_elite = true
	size_px *= Db.f(Db.d(Db.table("elites"), "base"), "size_mult", 1.0)
	var hp_mult: float = 1.0
	var shield_mult: float = 0.0
	for mod_id: Variant in mods:
		var mod: Dictionary = Db.entry("elites", "modifiers", str(mod_id))
		var effect: Dictionary = Db.d(mod, "effect")
		hp_mult *= Db.f(mod, "hp_mult", 1.0)
		damage_factor *= Db.f(effect, "damage_mult", 1.0)
		speed_factor *= Db.f(effect, "speed_mult", 1.0)
		shield_mult += Db.f(effect, "shield_hp_mult")
	hp_max *= hp_mult
	hp = hp_max
	shield = hp_max * shield_mult


func _ready() -> void:
	super._ready()
	modifier.call("attach", self, mods)
	show_hp_bar()


func hit_extras() -> Dictionary:
	var out: Dictionary = super.hit_extras()
	out.merge(modifier.call("hit_effects"), true)
	return out


func _on_death() -> void:
	modifier.call("on_enemy_died", self)


func on_damage_dealt(amount: float) -> void:
	modifier.call("on_damage_dealt", amount)
