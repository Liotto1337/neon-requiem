extends Button
## Card for an item, an ability, a level-up option or a hero. Border colour = rarity / ability
## colour; items and abilities show their code-drawn icon. Pure display: the owner connects
## `pressed` and passes data in.

const Db = preload("res://core/Db.gd")
const Sprites = preload("res://core/Sprites.gd")

var payload: Dictionary = {}
var _style_normal: StyleBoxFlat = null
var _style_hover: StyleBoxFlat = null
var _accent: Color = Color.WHITE
var _selected: bool = false

@onready var _icon: TextureRect = $Margin/Columns/Icon
@onready var _title: Label = $Margin/Columns/Rows/Title
@onready var _tag: Label = $Margin/Columns/Rows/Tag
@onready var _desc: Label = $Margin/Columns/Rows/Desc


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(Db.cfg_f("ui.card_width"), Db.cfg_f("ui.card_height"))
	_style_normal = (get_theme_stylebox("normal") as StyleBoxFlat).duplicate()
	_style_hover = (get_theme_stylebox("hover") as StyleBoxFlat).duplicate()
	add_theme_stylebox_override("normal", _style_normal)
	add_theme_stylebox_override("hover", _style_hover)
	add_theme_stylebox_override("pressed", _style_hover)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_apply_accent()


## Generic card: title, small tag line, description, accent colour name.
func show_custom(title: String, tag: String, desc: String, color_name: String) -> void:
	_title.text = title
	_tag.text = tag
	_desc.text = desc
	_accent = Db.color(color_name)
	set_icon(null)
	_apply_accent()


## Icon on the left of the text (null hides it). size_px resizes the icon box.
func set_icon(texture: Texture2D, size_px: float = 64.0) -> void:
	_icon.texture = texture
	_icon.visible = texture != null
	_icon.custom_minimum_size = Vector2(size_px, size_px)


func show_item(item_id: String, stacks: int) -> void:
	var data: Dictionary = ItemSystem.item(item_id)
	var rarity: Dictionary = ItemSystem.rarity_of(item_id)
	var kind: String = "активный" if ItemSystem.is_active(item_id) else "пассивный"
	var stack_text: String = "  ×%d" % stacks if stacks > 1 else ""
	show_custom(Db.s(data, "name") + stack_text, "%s · %s" % [Db.s(rarity, "name"), kind], Db.s(data, "desc"), Db.s(rarity, "color", "white"))
	set_icon(Sprites.icon("items", item_id))
	payload = {"kind": "item", "id": item_id}


func show_ability(ability_id: String, level: int, upgrade: bool) -> void:
	var data: Dictionary = AbilitySystem.ability(ability_id)
	var ultimate: bool = level >= AbilitySystem.max_level()
	var tag: String = ("Улучшение → ур. %d" if upgrade else "Новая способность · ур. %d") % level
	var desc: String = Db.s(data, "ultimate_desc") if ultimate else Db.s(data, "desc")
	show_custom(Db.s(data, "name"), tag, desc, Db.s(data, "color", "white"))
	set_icon(Sprites.icon("abilities", ability_id))
	payload = {"kind": "ability", "id": ability_id}


## Level-up option from GameState: {kind, id, level} or {kind: "currency", amount}.
func show_option(option: Dictionary) -> void:
	match Db.s(option, "kind"):
		"new_ability":
			show_ability(Db.s(option, "id"), Db.i(option, "level", 1), false)
		"upgrade_ability":
			show_ability(Db.s(option, "id"), Db.i(option, "level", 1), true)
		"item":
			show_item(Db.s(option, "id"), 1)
		_:
			show_custom("Кредиты", "Запасной вариант", "+%d кредитов забега" % Db.i(option, "amount"), "amber")
	payload = option


## Compact cards (inventory) show title and tag; the description moves to the tooltip.
func set_compact(compact: bool) -> void:
	_desc.visible = not compact
	_icon.custom_minimum_size = Vector2(48, 48) if compact else Vector2(64, 64)
	tooltip_text = _desc.text if compact else ""


func set_selected(selected: bool) -> void:
	_selected = selected
	_apply_accent()


func _apply_accent() -> void:
	if _style_normal == null:
		return
	_style_normal.border_color = _accent
	_style_hover.border_color = _accent.lightened(0.3)
	_style_normal.bg_color = _accent.darkened(0.6) if _selected else Db.color("dark")
	_title.add_theme_color_override("font_color", _accent)
