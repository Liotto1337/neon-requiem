extends "res://scenes/ui/components/ModalBase.gd"
## TAB overlay: player stats, abilities, passive items (stack counts), active items and the
## crafting recipes currently available. Caches everything from Signals while hidden.

const Fmt = preload("res://core/Fmt.gd")
const STAT_ROW_SCENE: PackedScene = preload("res://scenes/ui/components/StatRow.tscn")
const MODAL_ID: String = "inventory"
const SMALL_CARD: Vector2 = Vector2(250, 96)
const SHOWN_STATS: Array[String] = [
	"hp_max", "mana_max", "hp_regen", "mana_regen", "move_speed", "damage_mult", "crit_chance",
	"crit_mult", "attack_speed_mult", "cooldown_mult", "armor", "lifesteal_pct", "thorns_pct",
	"pickup_radius", "xp_mult", "currency_mult", "area_mult", "drone_damage_mult",
]

var _stats: Dictionary = {}
var _passives: Array = []
var _actives: Array = []
var _abilities: Array = []
var _recipes: Array = []

@onready var _stat_rows: VBoxContainer = $Margin/Panel/Columns/StatsCol/Stats
@onready var _ability_text: Label = $Margin/Panel/Columns/ItemsCol/Abilities
@onready var _passive_grid: GridContainer = $Margin/Panel/Columns/ItemsCol/Scroll/Passives
@onready var _active_row: HBoxContainer = $Margin/Panel/Columns/ItemsCol/Actives
@onready var _recipe_list: VBoxContainer = $Margin/Panel/Columns/CraftCol/Recipes
@onready var _recipe_hint: Label = $Margin/Panel/Columns/CraftCol/Hint


func _ready() -> void:
	modal_id = MODAL_ID
	visible = false
	Signals.inventory_toggle_requested.connect(_on_toggle)
	Signals.stats_changed.connect(_on_stats)
	Signals.items_changed.connect(_on_items)
	Signals.abilities_changed.connect(_on_abilities)
	Signals.recipes_changed.connect(_on_recipes)


func _on_toggle(open: bool) -> void:
	if open:
		_refresh()
		open_modal()
	else:
		close_modal()


func _on_stats(stats: Dictionary) -> void:
	_stats = stats
	_refresh_if_open()


func _on_abilities(abilities: Array) -> void:
	_abilities = abilities
	_refresh_if_open()


func _on_recipes(recipes: Array) -> void:
	_recipes = recipes
	_refresh_if_open()


func _on_items(passives: Array, actives: Array) -> void:
	_passives = passives
	_actives = actives
	_refresh_if_open()


func _refresh_if_open() -> void:
	if is_open():
		_refresh()


func _refresh() -> void:
	_fill_stats()
	_fill_abilities()
	_fill_items()
	_fill_recipes()


func _fill_stats() -> void:
	clear(_stat_rows)
	for key: String in SHOWN_STATS:
		var row: Node = STAT_ROW_SCENE.instantiate()
		_stat_rows.add_child(row)
		(row.get_node("Name") as Label).text = Fmt.stat_name(key)
		(row.get_node("Value") as Label).text = Fmt.stat_value(key, Db.f(_stats, key))


func _fill_abilities() -> void:
	var lines: Array[String] = []
	for entry: Variant in _abilities:
		var data: Dictionary = AbilitySystem.ability(Db.s(entry, "id"))
		var key: String = InputMapHelper.label(InputMapHelper.ability_action(Db.i(entry, "slot")))
		lines.append("[%s] %s — ур. %d" % [key, Db.s(data, "name"), Db.i(entry, "level", 1)])
	_ability_text.text = "\n".join(lines) if not lines.is_empty() else "—"


func _fill_items() -> void:
	clear(_passive_grid)
	for entry: Variant in _passives:
		var card: Node = add_card(_passive_grid)
		(card as Control).custom_minimum_size = SMALL_CARD
		card.call("show_item", Db.s(entry, "id"), Db.i(entry, "stacks", 1))
		card.call("set_compact", true)
	clear(_active_row)
	for entry: Variant in _actives:
		var card: Node = add_card(_active_row)
		(card as Control).custom_minimum_size = SMALL_CARD
		card.call("show_item", Db.s(entry, "id"), 1)
		card.call("set_compact", true)


func _fill_recipes() -> void:
	clear(_recipe_list)
	for recipe: Variant in _recipes:
		var names: Array[String] = []
		for input: Variant in Db.a(recipe, "inputs"):
			names.append(Db.s(ItemSystem.item(str(input)), "name"))
		var button: Button = Button.new()
		button.text = "%s → %s" % [" + ".join(names), Db.s(ItemSystem.item(Db.s(recipe, "output")), "name")]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(func() -> void: Signals.craft_requested.emit(Db.s(recipe, "id")))
		_recipe_list.add_child(button)
	_recipe_hint.visible = _recipes.is_empty()
