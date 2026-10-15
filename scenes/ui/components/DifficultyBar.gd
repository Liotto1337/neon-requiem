extends Control
## Risk of Rain 2 style difficulty strip under the run timer: coloured segments named by
## data/difficulty.json "names" (2 threat tiers each, the last one endless) scroll left under
## a fixed "now" marker; a tick per threat tier, past segments dimmed, the current one lit.

const Db = preload("res://core/Db.gd")
const DIM: float = 0.55
const TEXT_SIZE: int = 13

var position_tiers: float = 0.0
var _font: Font = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_font = get_theme_default_font()


## pos = threat tier + progress to the next tier (0..1).
func set_position_tiers(pos: float) -> void:
	position_tiers = maxf(0.0, pos)
	queue_redraw()


func current_index() -> int:
	var names: Array = Db.a(Db.table("difficulty"), "names")
	var index: int = 0
	for i: int in names.size():
		if position_tiers >= Db.f(names[i], "from_tier"):
			index = i
	return index


func current_name() -> String:
	return Db.s(Db.a(Db.table("difficulty"), "names")[current_index()], "name")


func current_color() -> Color:
	return Db.color(Db.s(Db.a(Db.table("difficulty"), "names")[current_index()], "color"))


func _tier_x(tier: float) -> float:
	var marker: float = floorf(size.x * Db.cfg_f("ui.difficulty_marker"))
	return marker + (tier - position_tiers) * Db.cfg_f("ui.difficulty_px_per_tier")


func _draw() -> void:
	var w: float = floorf(size.x)
	var h: float = floorf(size.y)
	draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.01, 0.04))
	var names: Array = Db.a(Db.table("difficulty"), "names")
	var current: int = current_index()
	for i: int in names.size():
		var start: float = _tier_x(Db.f(names[i], "from_tier"))
		var end: float = _tier_x(Db.f(names[i + 1], "from_tier")) if i + 1 < names.size() else w + 4.0
		if end < 0.0 or start > w:
			continue
		_draw_segment(names[i], Rect2(start, 1, end - start, h - 2), i < current, i == current)
	_draw_ticks(h)
	_draw_marker(h)
	draw_rect(Rect2(0, 0, w, h), Color(0.94, 0.94, 1.0, 0.35), false, 1.0)


func _draw_segment(entry: Dictionary, rect: Rect2, past: bool, current: bool) -> void:
	var base: Color = Db.color(Db.s(entry, "color"))
	var fill: Color = base.darkened(DIM) if past else base
	var rows: int = int(rect.size.y)
	for row: int in rows:
		var t: float = float(row) / float(maxi(1, rows - 1))
		var c: Color = fill.lightened(0.25 * (1.0 - t)) if t < 0.4 else fill.darkened(0.3 * (t - 0.4))
		draw_rect(Rect2(rect.position.x, rect.position.y + row, rect.size.x, 1), c)
	draw_rect(Rect2(rect.position.x, rect.position.y, 1, rect.size.y), Color(0.0, 0.0, 0.0, 0.7))
	if current:
		draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 1), base.lightened(0.6))
	var text_color: Color = Db.color(Db.s(entry, "text", "#0b0714")) if Db.s(entry, "text") != "" else Color(0.04, 0.02, 0.07)
	if past:
		text_color.a = 0.55
	var label: String = Db.s(entry, "name")
	var text_w: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
	var visible_from: float = maxf(rect.position.x, 4.0)
	var visible_to: float = minf(rect.end.x, size.x - 4.0)
	var x: float = clampf(rect.position.x + (rect.size.x - text_w) * 0.5, visible_from, maxf(visible_from, visible_to - text_w))
	draw_string(_font, Vector2(floorf(x), floorf(rect.position.y + rect.size.y * 0.5 + TEXT_SIZE * 0.36)), label, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, text_color)


func _draw_ticks(h: float) -> void:
	var first: int = maxi(0, floori(position_tiers) - 6)
	for tier: int in range(first, first + 16):
		var x: float = floorf(_tier_x(float(tier)))
		if x >= 0.0 and x <= size.x:
			draw_rect(Rect2(x, h - 5, 1, 4), Color(0.0, 0.0, 0.0, 0.6))
			draw_rect(Rect2(x, 1, 1, 3), Color(1.0, 1.0, 1.0, 0.35))


func _draw_marker(h: float) -> void:
	var x: float = floorf(size.x * Db.cfg_f("ui.difficulty_marker"))
	draw_rect(Rect2(x - 1, 0, 3, h), Color(0.02, 0.01, 0.04))
	draw_rect(Rect2(x, 0, 1, h), Color(2.0, 2.0, 2.0))
	draw_colored_polygon(PackedVector2Array([Vector2(x - 4, 0), Vector2(x + 5, 0), Vector2(x + 0.5, 5)]), Color(1.6, 1.6, 1.6))
