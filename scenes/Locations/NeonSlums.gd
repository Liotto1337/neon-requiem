extends "res://scenes/Locations/LocationBase.gd"
## Neon Slums: tight alleys between brick blocks, toxic puddles, cyan / magenta signs that
## flicker like dying neon tubes.


func _tick_flavor(now: int, _delta: float) -> void:
	var flavor: Dictionary = Db.d(config, "flavor")
	var t: float = float(now) / MSEC
	var speed: float = Db.f(flavor, "flicker_speed")
	var wave: float = absf(sin(t * speed) * sin(t * speed * Db.f(flavor, "flicker_offset")))
	var level: float = 1.0 - Db.f(flavor, "flicker_depth") * wave
	decor_layer.modulate = Color(level, level, level)
