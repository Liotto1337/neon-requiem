extends "res://scenes/hub/HubOverlay.gd"
## Portal choice when a saved run exists: continue it or start a new one with the selected
## hero (the saved run is dropped). Without a save the Hub starts the run directly.

var _info: Label = null


func build() -> void:
	set_title("ПОРТАЛ")
	_info = _label("", 24, Db.color("white"))
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(_info)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	content.add_child(row)
	var resume: Button = Button.new()
	resume.text = "Продолжить забег"
	resume.custom_minimum_size = Vector2(360.0, 72.0)
	resume.pressed.connect(func() -> void: Signals.run_continue_requested.emit())
	row.add_child(resume)
	var fresh: Button = Button.new()
	fresh.text = "Новый забег"
	fresh.custom_minimum_size = Vector2(360.0, 72.0)
	fresh.pressed.connect(func() -> void: Signals.run_start_requested.emit(Db.s(meta, "selected_hero")))
	row.add_child(fresh)


func refresh() -> void:
	var hero: Dictionary = Db.entry("heroes", "heroes", Db.s(meta, "selected_hero"))
	_info.text = "Есть сохранённый забег.\nНовый забег за «%s» сотрёт сохранение." % Db.s(hero, "name")
