extends "res://scenes/hub/HubOverlay.gd"
## Workshop: upgrades the selected hero's signature starting item (tiers 1..5, power x1.0 ..
## x2.0, prices in data/items.json "signature_upgrade_costs").

const ICON_SIZE: float = 128.0

var _icon: TextureRect = null
var _name: Label = null
var _tier: Label = null
var _desc: Label = null
var _button: Button = null


func build() -> void:
	set_title("МАСТЕРСКАЯ")
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(row)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.custom_minimum_size = Vector2(640.0, 0.0)
	column.add_theme_constant_override("separation", 12)
	row.add_child(column)
	_name = _label("", 32, Db.color("amber"))
	_tier = _label("", 22, Db.color("lime"))
	_desc = _label("", 18, Db.color("white"))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button = Button.new()
	_button.custom_minimum_size = Vector2(360.0, 64.0)
	_button.pressed.connect(func() -> void: Signals.starting_item_upgrade_requested.emit(Db.s(meta, "selected_hero")))
	for child: Control in [_name, _tier, _desc, _button]:
		column.add_child(child)


func refresh() -> void:
	var hero: Dictionary = Db.entry("heroes", "heroes", Db.s(meta, "selected_hero"))
	var item_id: String = Db.s(hero, "signature_item")
	var item: Dictionary = ItemSystem.item(item_id)
	var tier: int = Db.i(Db.d(meta, "starting_item_tiers"), Db.s(hero, "id"), 1)
	var costs: Array = Db.a(Db.table("items"), "signature_upgrade_costs")
	var maxed: bool = tier - 1 >= costs.size()
	_icon.texture = Sprites.icon("items", item_id)
	_name.text = "%s · %s" % [Db.s(item, "name"), Db.s(hero, "name")]
	_tier.text = "Уровень %s  %d/%d · сила ×%s" % ["◆".repeat(tier) + "◇".repeat(costs.size() + 1 - tier), tier, costs.size() + 1, String.num(ItemSystem.signature_mult(tier), 2)]
	_desc.text = Db.s(item, "desc")
	var price: int = int(Db.num(costs[mini(tier - 1, costs.size() - 1)]))
	_button.text = "Максимум" if maxed else "Улучшить за %d (кредиты: %d)" % [price, Db.i(meta, "currency")]
	_button.disabled = maxed or Db.i(meta, "currency") < price
