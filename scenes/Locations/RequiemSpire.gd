extends "res://scenes/Locations/LocationBase.gd"
## Requiem Spire: the final boss arena. A marble circle ringed by white pillars, void cracks
## as hazards and slow purple light beams sweeping from the centre.

var _beams: Array = []


func _on_ready_flavor() -> void:
	var flavor: Dictionary = Db.d(config, "flavor")
	var center: Vector2 = bounds().get_center() - global_position
	for index: int in Db.i(flavor, "beam_count"):
		var beam: Line2D = Line2D.new()
		beam.width = Db.f(flavor, "beam_width")
		beam.default_color = Db.glow(Db.s(flavor, "beam_color", "purple"))
		beam.antialiased = false
		beam.z_index = -1
		beam.position = center
		beam.points = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT * Db.f(flavor, "beam_length_px")])
		beam.rotation = TAU * float(index) / float(maxi(1, Db.i(flavor, "beam_count")))
		add_child(beam)
		_beams.append(beam)


func _tick_flavor(_now: int, delta: float) -> void:
	var spin: float = Db.f(Db.d(config, "flavor"), "beam_speed") * delta
	for beam: Variant in _beams:
		(beam as Line2D).rotation += spin
