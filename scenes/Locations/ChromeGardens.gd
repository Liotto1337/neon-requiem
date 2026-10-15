extends "res://scenes/Locations/LocationBase.gd"
## Chrome Gardens: overgrown chrome pillars, lime / magenta flora and thorn-vine hazard
## patches whose glow sways like breathing plants.


func _tick_flavor(now: int, _delta: float) -> void:
	var flavor: Dictionary = Db.d(config, "flavor")
	var t: float = float(now) / MSEC
	var sway: float = Db.f(flavor, "sway_depth") * sin(t * Db.f(flavor, "sway_speed"))
	# Greener, then pinker; every channel stays <= 1 (above 1 is the SpriteFx hit flash).
	var green: float = maxf(sway, 0.0)
	decor_layer.modulate = Color(1.0 - green, 1.0 - maxf(-sway, 0.0), 1.0 - green)
