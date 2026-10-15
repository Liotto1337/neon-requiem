extends Control
## HUD resource bar with depth and motion (HP, shield, mana, XP, boss HP):
##   * volume — dark bevelled frame, an inset groove, a vertical light-to-shade fill with a
##     specular stripe, a bright leading edge and optional unit ticks;
##   * loss — the fill eases down at once; the lost piece stays as a dimmer "ghost" chunk,
##     waits `ghost_delay`, then breaks off, falls and fades out of the HUD;
##   * gain — the incoming part lights up first, then the fill eases up to it.
## Pure display: set_values() is called by the HUD with numbers from Signals.

const Db = preload("res://core/Db.gd")
const MSEC: float = 1000.0
const TINY_CHANGE: float = 0.004
const SMALL_GAIN: float = 0.02

@export var fill_color: Color = Color(1.0, 0.18, 0.53)
@export var back_color: Color = Color(0.06, 0.03, 0.1)
@export var tick_units: float = 0.0
@export var show_text: bool = true
@export var text_size: int = 18

var _value: float = 0.0
var _maximum: float = 1.0
var _target: float = 0.0
var _shown: float = 0.0
var _gain_from: float = 0.0
var _gain_hold_until: int = 0
var _chunks: Array[Dictionary] = []
var _label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	if show_text:
		_label = Label.new()
		_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", text_size)
		_label.add_theme_constant_override("outline_size", 6)
		_label.add_theme_color_override("font_outline_color", Color(0.03, 0.01, 0.06))
		add_child(_label)


func _now() -> int:
	return Time.get_ticks_msec()


## New numbers. instant skips the motion (first fill, location load).
func set_values(value: float, maximum: float, instant: bool = false) -> void:
	_value = maxf(0.0, value)
	_maximum = maxf(0.001, maximum)
	var target: float = clampf(_value / _maximum, 0.0, 1.0)
	if _label != null:
		_label.text = "%d/%d" % [roundi(_value), roundi(_maximum)]
	if instant:
		_target = target
		_shown = target
		_chunks.clear()
		queue_redraw()
		return
	if target < _target - TINY_CHANGE:
		_add_chunk(target, maxf(_target, _shown))
	elif target > _target + SMALL_GAIN:
		_gain_from = _shown
		_gain_hold_until = _now() + int(Db.cfg_f("ui.bar_gain_delay") * MSEC)
	_target = target


func set_text(text: String) -> void:
	if _label != null:
		_label.text = text


func fraction() -> float:
	return _target


## Lost piece [low, high] as a ghost chunk; touching pending chunks merge.
func _add_chunk(low: float, high: float) -> void:
	var now: int = _now()
	for chunk: Dictionary in _chunks:
		if now < int(chunk["drop_at"]) and is_equal_approx(float(chunk["low"]), high):
			chunk["low"] = low
			return
	_chunks.append({"low": low, "high": high, "drop_at": now + int(Db.cfg_f("ui.bar_ghost_delay") * MSEC)})


func _process(delta: float) -> void:
	var now: int = _now()
	var speed: float = Db.cfg_f("ui.bar_ease_speed")
	if _target < _shown or now >= _gain_hold_until:
		_shown = lerpf(_shown, _target, clampf(speed * delta, 0.0, 1.0))
		if absf(_shown - _target) < 0.001:
			_shown = _target
	var fall: float = Db.cfg_f("ui.bar_fall_sec")
	var kept: Array[Dictionary] = []
	for chunk: Dictionary in _chunks:
		if now < int(chunk["drop_at"]) + int(fall * MSEC):
			kept.append(chunk)
	_chunks = kept
	queue_redraw()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var w: float = floorf(size.x)
	var h: float = floorf(size.y)
	draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.01, 0.04))
	draw_rect(Rect2(1, 1, w - 2, 1), back_color.lightened(0.35))
	draw_rect(Rect2(1, h - 2, w - 2, 1), Color(0.0, 0.0, 0.0))
	var inner: Rect2 = Rect2(2, 2, w - 4, h - 4)
	_draw_groove(inner)
	if _shown < _target:
		_draw_fill(inner, _shown, _target, fill_color.lightened(0.55), 0.55)
	_draw_fill(inner, 0.0, _shown, fill_color, 1.0)
	_draw_ticks(inner)
	_draw_chunks(inner)
	if _shown > 0.0:
		var edge: float = inner.position.x + floorf(inner.size.x * _shown)
		draw_rect(Rect2(edge - 2, inner.position.y, 2, inner.size.y), fill_color.lightened(0.6))


func _draw_groove(inner: Rect2) -> void:
	var rows: int = int(inner.size.y)
	for row: int in rows:
		var shade: float = 0.55 if row == 0 else (0.25 if row == 1 else 0.0)
		draw_rect(Rect2(inner.position.x, inner.position.y + row, inner.size.x, 1), back_color.darkened(shade))


## Vertical light-to-shade fill between two fractions with a specular stripe.
func _draw_fill(inner: Rect2, from: float, to: float, color: Color, alpha: float) -> void:
	var x0: float = inner.position.x + floorf(inner.size.x * from)
	var x1: float = inner.position.x + floorf(inner.size.x * to)
	if x1 <= x0:
		return
	var rows: int = int(inner.size.y)
	var stripe: int = maxi(1, roundi(float(rows) * 0.22))
	for row: int in rows:
		var t: float = float(row) / float(maxi(1, rows - 1))
		var c: Color = color.lightened((1.0 - t) * 0.32) if t < 0.5 else color.darkened((t - 0.5) * 0.7)
		if row == stripe:
			c = color.lightened(0.6)
		c.a = alpha
		draw_rect(Rect2(x0, inner.position.y + row, x1 - x0, 1), c)


func _draw_ticks(inner: Rect2) -> void:
	if tick_units <= 0.0 or _maximum / tick_units > 60.0:
		return
	var units: float = tick_units
	while units < _maximum:
		var x: float = inner.position.x + floorf(inner.size.x * units / _maximum)
		draw_rect(Rect2(x, inner.position.y + 1, 1, inner.size.y - 2), Color(0.0, 0.0, 0.0, 0.35))
		units += tick_units


## Ghost chunks: dimmer piece while waiting, then it drops, tilts and fades.
func _draw_chunks(inner: Rect2) -> void:
	var now: int = _now()
	var fall: float = maxf(0.05, Db.cfg_f("ui.bar_fall_sec"))
	for chunk: Dictionary in _chunks:
		var x0: float = inner.position.x + floorf(inner.size.x * float(chunk["low"]))
		var x1: float = inner.position.x + floorf(inner.size.x * float(chunk["high"]))
		var t: float = clampf(float(now - int(chunk["drop_at"])) / (fall * MSEC), 0.0, 1.0)
		var drop: float = t * t * Db.cfg_f("ui.bar_fall_px")
		var alpha: float = Db.cfg_f("ui.bar_ghost_alpha") * (1.0 - t)
		var c: Color = fill_color.lightened(0.15)
		c.a = alpha
		var rows: int = int(inner.size.y)
		for row: int in rows:
			var slant: float = t * float(row) * 0.6
			draw_rect(Rect2(x0 + slant, inner.position.y + row + drop, maxf(1.0, x1 - x0), 1), c)
		if t > 0.0:
			var spark: Color = fill_color.lightened(0.7)
			spark.a = alpha
			draw_rect(Rect2(x0, inner.position.y + drop - 1, maxf(1.0, x1 - x0), 1), spark)
