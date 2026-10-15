extends "res://scenes/hub/HubOverlay.gd"
## Hero pod: the same hero cards as the main menu. Click selects an unlocked hero or buys a
## locked one for credits; the hub avatar switches to the selected hero.

const HERO_CARD: PackedScene = preload("res://scenes/ui/components/HeroCard.tscn")

var _row: HBoxContainer = null
var _credits: Label = null


func build() -> void:
	set_title("КАПСУЛА ГЕРОЕВ")
	_credits = _label("", 24, Db.color("amber"))
	content.add_child(_credits)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 28)
	_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_row)


func refresh() -> void:
	_credits.text = "Кредиты: %d" % Db.i(meta, "currency")
	clear(_row)
	for hero: Variant in Db.list("heroes", "heroes"):
		var card: Button = HERO_CARD.instantiate()
		_row.add_child(card)
		var id: String = Db.s(hero, "id")
		var unlocked: bool = Db.a(meta, "unlocked_heroes").has(id)
		card.call("show_hero", hero, unlocked, id == Db.s(meta, "selected_hero"))
		if unlocked:
			card.pressed.connect(func() -> void: Signals.hero_selected.emit(id))
		else:
			card.pressed.connect(func() -> void: Signals.hero_unlock_requested.emit(id))
