extends PanelContainer
## HUD slot for one ability or active item: glyph, key label, level, cooldown overlay.
## Only displays what the HUD hands it; the cooldown runs on the run clock.

const Db = preload("res://core/Db.gd")
const EMPTY_GLYPH: String = "·"
const ULTIMATE_MARK: String = "УЛЬТ"
const FAIL_FLASH_SEC: float = 0.25
const MSEC: float = 1000.0

var _cooldown_end_msec: int = 0
var _cooldown_total: float = 0.0
var _flash_until_msec: int = 0
var _style: StyleBoxFlat = null

@onready var _glyph: Label = $Glyph
@onready var _key: Label = $Key
@onready var _level: Label = $Level
@onready var _cooldown: ProgressBar = $Cooldown
@onready var _cd_text: Label = $CdText


func _ready() -> void:
	var size_px: float = Db.cfg_f("ui.slot_size")
	custom_minimum_size = Vector2(size_px, size_px)
	_style = (get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	add_theme_stylebox_override("panel", _style)
	show_empty()


func set_key(text: String) -> void:
	_key.text = text


func show_empty() -> void:
	_glyph.text = EMPTY_GLYPH
	_level.text = ""
	tooltip_text = ""
	_set_color(Db.color("dim"))


## entry: {id, level} from GameState.abilities.
func show_ability(entry: Dictionary) -> void:
	var data: Dictionary = AbilitySystem.ability(Db.s(entry, "id"))
	var level: int = Db.i(entry, "level", 1)
	var ultimate: bool = level >= AbilitySystem.max_level()
	_glyph.text = Db.s(Db.d(data, "icon"), "glyph", "?")
	_level.text = ULTIMATE_MARK if ultimate else str(level)
	tooltip_text = "%s (ур. %d)\n%s%s" % [Db.s(data, "name"), level, Db.s(data, "desc"), ("\n" + Db.s(data, "ultimate_desc")) if ultimate else ""]
	_set_color(Db.color(Db.s(data, "color", "white")))


func show_item(item_id: String) -> void:
	var data: Dictionary = ItemSystem.item(item_id)
	_glyph.text = Db.s(data, "glyph", "?")
	_level.text = ""
	tooltip_text = "%s\n%s" % [Db.s(data, "name"), Db.s(data, "desc")]
	_set_color(Db.color(Db.s(ItemSystem.rarity_of(item_id), "color", "white")))


func _set_color(color: Color) -> void:
	_glyph.add_theme_color_override("font_color", color)
	if _style != null:
		_style.border_color = color


func start_cooldown(duration_sec: float) -> void:
	_cooldown_total = maxf(0.01, duration_sec)
	_cooldown_end_msec = TimeService.deadline(duration_sec)


func flash_fail() -> void:
	_flash_until_msec = TimeService.deadline(FAIL_FLASH_SEC)


func _process(_delta: float) -> void:
	var left: float = TimeService.until_sec(_cooldown_end_msec)
	_cooldown.value = clampf(left / _cooldown_total, 0.0, 1.0) * _cooldown.max_value if _cooldown_total > 0.0 else 0.0
	_cd_text.text = String.num(left, 1) if left > 0.0 else ""
	modulate = Db.color("red") if TimeService.run_msec() < _flash_until_msec else Color.WHITE
