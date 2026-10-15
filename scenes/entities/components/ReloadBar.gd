extends Node2D
## Reload bar over the hero's head: a static horizontal line closed by two vertical end
## ticks, and a vertical marker that runs from the left tick to the right one while the R
## action (reload / parry / recall) recharges. Hidden when idle.

const Db = preload("res://core/Db.gd")

var color: Color = Color.WHITE
var _start_msec: int = 0
var _end_msec: int = 0


func start(duration_sec: float) -> void:
	_start_msec = TimeService.run_msec()
	_end_msec = TimeService.deadline(maxf(0.05, duration_sec))
	visible = true
	queue_redraw()


func progress() -> float:
	var span: float = maxf(1.0, float(_end_msec - _start_msec))
	return clampf(float(TimeService.run_msec() - _start_msec) / span, 0.0, 1.0)


func _process(_delta: float) -> void:
	if not visible:
		return
	if TimeService.run_msec() >= _end_msec:
		visible = false
		return
	queue_redraw()


func _draw() -> void:
	var half: float = Db.cfg_f("ui.reload_bar_width") * 0.5
	var tick: float = Db.cfg_f("ui.reload_bar_tick")
	var line: float = Db.cfg_f("ui.reload_bar_line")
	var dim: Color = Color(color.r, color.g, color.b, 0.55)
	draw_line(Vector2(-half, 0.0), Vector2(half, 0.0), dim, line)
	draw_line(Vector2(-half, -tick), Vector2(-half, tick), color, line)
	draw_line(Vector2(half, -tick), Vector2(half, tick), color, line)
	var x: float = lerpf(-half, half, progress())
	draw_line(Vector2(x, -tick * 1.4), Vector2(x, tick * 1.4), Color(2.2, 2.2, 2.2), line + 1.0)
