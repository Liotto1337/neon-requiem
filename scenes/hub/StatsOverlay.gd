extends "res://scenes/hub/HubOverlay.gd"
## Records board: lifetime stats from MetaState (runs, wins, best loop, best time) and the
## progress summary (heroes, skill tree levels).

var _rows: Label = null


func build() -> void:
	set_title("ТАБЛО РЕКОРДОВ")
	_rows = _label("", 28, Db.color("white"))
	_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rows.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rows.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_rows)


func refresh() -> void:
	var stats: Dictionary = Db.d(meta, "stats")
	var levels: int = 0
	for value: Variant in Db.d(meta, "meta_tree_nodes").values():
		levels += int(Db.num(value))
	_rows.text = "\n".join(PackedStringArray([
		"Забегов: %d" % Db.i(stats, "runs"),
		"Побед: %d" % Db.i(stats, "wins"),
		"Лучшая петля: %d" % Db.i(stats, "best_loop"),
		"Лучшее время: %s" % Fmt.clock(Db.f(stats, "best_time_sec")),
		"Открыто героев: %d из %d" % [Db.a(meta, "unlocked_heroes").size(), Db.list("heroes", "heroes").size()],
		"Уровней древа: %d" % levels,
		"Кредиты в банке: %d" % Db.i(meta, "currency"),
	]))
