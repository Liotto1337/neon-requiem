extends "res://scenes/Locations/LocationBase.gd"
## Data Core: server rack rows, cyan-dominant plates, glowing floor tiles that pulse with the
## core's clock, static-field hazards.


func _tick_flavor(now: int, _delta: float) -> void:
	var flavor: Dictionary = Db.d(config, "flavor")
	var t: float = float(now) / MSEC
	# Dims between 1 - depth and 1: modulate above 1 is the SpriteFx hit flash.
	var level: float = 1.0 - Db.f(flavor, "pulse_depth") * (0.5 + 0.5 * sin(t * Db.f(flavor, "pulse_speed")))
	floor_layer.modulate = Color(floor_tint.r * level, floor_tint.g * level, floor_tint.b * level)
