extends Control
## Hub: hero select / unlock, skill tree (3 branches, data/meta_tree.json), workshop (signature
## item tiers) and run start / continue. Reads meta state only from
## Signals.meta_changed and sends intents back through Signals.

const Db = preload("res://core/Db.gd")
const Fmt = preload("res://core/Fmt.gd")
const CARD_SCENE: PackedScene = preload("res://scenes/ui/components/ItemCard.tscn")
const TAB_TITLES: Array[String] = ["Герои", "Древо навыков", "Мастерская"]
const HERO_CARD_SIZE: Vector2 = Vector2(420, 230)
const NODE_HEIGHT: float = 96.0
const STATE_MAXED: String = "maxed"
const STATE_LOCKED: String = "locked"
const STATE_POOR: String = "poor"
const STATE_READY: String = "ready"

var _meta: Dictionary = {}

@onready var _currency: Label = $Margin/Rows/Header/Currency
@onready var _stats: Label = $Margin/Rows/Stats
@onready var _tabs: TabContainer = $Margin/Rows/Tabs
@onready var _hero_cards: HBoxContainer = $Margin/Rows/Tabs/Heroes/Cards
@onready var _hero_info: Label = $Margin/Rows/Tabs/Heroes/Info
@onready var _tree: HBoxContainer = $Margin/Rows/Tabs/Tree
@onready var _signature_text: Label = $Margin/Rows/Tabs/Shop/Signature/Text
@onready var _signature_button: Button = $Margin/Rows/Tabs/Shop/Signature/Upgrade
@onready var _toast: Label = $Margin/Rows/Footer/Toast
@onready var _continue: Button = $Margin/Rows/Footer/Continue
@onready var _start: Button = $Margin/Rows/Footer/Start


func _ready() -> void:
	for index: int in TAB_TITLES.size():
		_tabs.set_tab_title(index, TAB_TITLES[index])
	Signals.meta_changed.connect(_on_meta)
	Signals.run_started.connect(_on_run_started)
	Signals.toast_requested.connect(_on_toast)
	_start.pressed.connect(_on_start)
	_continue.pressed.connect(func() -> void: Signals.run_continue_requested.emit())
	_signature_button.pressed.connect(func() -> void: Signals.starting_item_upgrade_requested.emit(Db.s(_meta, "selected_hero")))
	_toast.text = ""
	MetaState.emit_all()


func _on_meta(meta: Dictionary) -> void:
	_meta = meta
	_currency.text = "Кредиты: %d" % Db.i(meta, "currency")
	var stats: Dictionary = Db.d(meta, "stats")
	_stats.text = "Забегов: %d · Побед: %d · Лучшая петля: %d · Лучшее время: %s" % [
		Db.i(stats, "runs"), Db.i(stats, "wins"), Db.i(stats, "best_loop"), Fmt.clock(Db.f(stats, "best_time_sec")),
	]
	_continue.visible = bool(meta.get("has_run_save", false))
	_refresh_heroes()
	_refresh_tree()
	_refresh_shop()


func _on_run_started(_summary: Dictionary) -> void:
	get_tree().change_scene_to_file(Db.cfg_s("scenes.run"))


func _on_start() -> void:
	Signals.run_start_requested.emit(Db.s(_meta, "selected_hero"))


func _on_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tween: Tween = _toast.create_tween()
	tween.tween_interval(Db.cfg_f("ui.toast_sec"))
	tween.tween_property(_toast, "modulate:a", 0.0, Db.cfg_f("ui.toast_sec") * 0.3)


## Removes children safely even when one of them is the button emitting right now.
func _clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


# ---------------------------------------------------------------- heroes

func _refresh_heroes() -> void:
	_clear(_hero_cards)
	for hero: Variant in Db.list("heroes", "heroes"):
		_hero_card(hero)
	var selected: Dictionary = Db.entry("heroes", "heroes", Db.s(_meta, "selected_hero"))
	var abilities: Array[String] = []
	for id: Variant in Db.a(selected, "abilities"):
		abilities.append(Db.s(AbilitySystem.ability(str(id)), "name"))
	_hero_info.text = "Выбран: %s (%s). Способности: %s. Перед забегом выберете 2 из 3 стартовых предметов." % [
		Db.s(selected, "name"), Db.s(selected, "class_name"), ", ".join(abilities),
	]


func _hero_card(hero: Dictionary) -> void:
	var card: Button = CARD_SCENE.instantiate()
	card.custom_minimum_size = HERO_CARD_SIZE
	_hero_cards.add_child(card)
	var id: String = Db.s(hero, "id")
	var unlocked: bool = Db.a(_meta, "unlocked_heroes").has(id)
	var status: String = "ВЫБРАН" if id == Db.s(_meta, "selected_hero") else ("Нажмите, чтобы выбрать" if unlocked else "Открыть за %d кредитов" % Db.i(hero, "unlock_cost"))
	card.call("show_custom", Db.s(hero, "name"), "%s · %s" % [Db.s(hero, "class_name"), status], Db.s(hero, "desc"), Db.s(hero, "color", "white") if unlocked else "dim")
	card.call("set_selected", id == Db.s(_meta, "selected_hero"))
	if unlocked:
		card.pressed.connect(func() -> void: Signals.hero_selected.emit(id))
	else:
		card.pressed.connect(func() -> void: Signals.hero_unlock_requested.emit(id))


# ---------------------------------------------------------------- skill tree

func _refresh_tree() -> void:
	_clear(_tree)
	for branch: Variant in Db.list("meta_tree", "branches"):
		_tree.add_child(_tree_column(branch))


func _tree_column(branch: Dictionary) -> Control:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var title: Label = Label.new()
	title.text = Db.s(branch, "name").to_upper()
	title.add_theme_color_override("font_color", Db.color(Db.s(branch, "color", "white")))
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)
	for node: Variant in Db.list("meta_tree", "nodes"):
		if Db.s(node, "branch") == Db.s(branch, "id"):
			column.add_child(_node_button(node))
	return scroll


func _node_button(node: Dictionary) -> Button:
	var id: String = Db.s(node, "id")
	var level: int = Db.i(Db.d(_meta, "meta_tree_nodes"), id)
	var state: String = _node_state(node, level)
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(Db.cfg_f("ui.node_button_width"), NODE_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var cost_text: String = "МАКС" if state == STATE_MAXED else ("Закрыт: нужен предыдущий узел" if state == STATE_LOCKED else "Цена: %d" % _node_cost(node, level))
	button.text = "%s  [%d/%d]\n%s\n%s" % [Db.s(node, "name"), level, Db.i(node, "max_level"), Db.s(node, "desc"), cost_text]
	button.disabled = state != STATE_READY
	button.modulate = Db.color("lime") if state == STATE_MAXED else Color.WHITE
	button.pressed.connect(func() -> void: Signals.meta_node_purchase_requested.emit(id))
	return button


func _node_cost(node: Dictionary, level: int) -> int:
	var costs: Array = Db.a(node, "costs")
	return int(Db.num(costs[level])) if level < costs.size() else 0


func _node_state(node: Dictionary, level: int) -> String:
	if level >= Db.i(node, "max_level"):
		return STATE_MAXED
	var requires: Array = Db.a(node, "requires")
	var open: bool = requires.is_empty()
	for id: Variant in requires:
		open = open or Db.i(Db.d(_meta, "meta_tree_nodes"), str(id)) > 0
	if not open:
		return STATE_LOCKED
	return STATE_READY if Db.i(_meta, "currency") >= _node_cost(node, level) else STATE_POOR


# ---------------------------------------------------------------- workshop

func _refresh_shop() -> void:
	var hero: Dictionary = Db.entry("heroes", "heroes", Db.s(_meta, "selected_hero"))
	var item: Dictionary = ItemSystem.item(Db.s(hero, "signature_item"))
	var tier: int = Db.i(Db.d(_meta, "starting_item_tiers"), Db.s(hero, "id"), 1)
	var costs: Array = Db.a(Db.table("items"), "signature_upgrade_costs")
	var maxed: bool = tier - 1 >= costs.size()
	_signature_text.text = "%s — «%s», уровень %d/%d (сила ×%s). %s" % [
		Db.s(hero, "name"), Db.s(item, "name"), tier, costs.size() + 1, String.num(ItemSystem.signature_mult(tier), 2), Db.s(item, "desc"),
	]
	_signature_button.text = "Максимум" if maxed else "Улучшить за %d" % int(Db.num(costs[tier - 1]))
	_signature_button.disabled = maxed or Db.i(_meta, "currency") < int(Db.num(costs[mini(tier - 1, costs.size() - 1)]))
