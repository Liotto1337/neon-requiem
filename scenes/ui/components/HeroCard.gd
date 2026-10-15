extends Button
## Hero card for the main menu and the hub hero pod: the hero's animated sprite (idle, runs
## on hover) at 2x, name, class, status (selected / unlock price), description and the icons
## of the three starting abilities. Pure display: the owner connects `pressed`.

const Db = preload("res://core/Db.gd")
const Sprites = preload("res://core/Sprites.gd")
const PORTRAIT_SCALE: float = 2.0
const PORTRAIT_HEIGHT: float = 210.0
const ICON_SIZE: float = 44.0

var hero_id: String = ""
var _sprite: AnimatedSprite2D = null
var _style: StyleBoxFlat = null
var _accent: Color = Color.WHITE

@onready var _portrait: Control = $Margin/Rows/Portrait
@onready var _name: Label = $Margin/Rows/Name
@onready var _class: Label = $Margin/Rows/Class
@onready var _status: Label = $Margin/Rows/Status
@onready var _desc: Label = $Margin/Rows/Desc
@onready var _abilities: HBoxContainer = $Margin/Rows/Abilities


func _ready() -> void:
	_style = (get_theme_stylebox("normal") as StyleBoxFlat).duplicate()
	add_theme_stylebox_override("normal", _style)
	add_theme_stylebox_override("hover", _style)
	add_theme_stylebox_override("pressed", _style)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_portrait.custom_minimum_size = Vector2(0.0, PORTRAIT_HEIGHT)
	_portrait.resized.connect(_place_sprite)
	mouse_entered.connect(func() -> void: _play("run"))
	mouse_exited.connect(func() -> void: _play("idle"))


## unlocked / selected drive the status line, the colours and the dimmed portrait.
func show_hero(hero: Dictionary, unlocked: bool, selected: bool) -> void:
	hero_id = Db.s(hero, "id")
	_accent = Db.color(Db.s(hero, "color", "white"))
	_name.text = Db.s(hero, "name").to_upper()
	_class.text = Db.s(hero, "class_name")
	_desc.text = Db.s(hero, "desc")
	_status.text = "ВЫБРАН" if selected else ("Нажмите, чтобы выбрать" if unlocked else "Открыть за %d кредитов" % Db.i(hero, "unlock_cost"))
	_name.add_theme_color_override("font_color", _accent if unlocked else Db.color("dim"))
	_status.add_theme_color_override("font_color", Db.color("lime") if selected else (Db.color("white") if unlocked else Db.color("amber")))
	_style.border_color = _accent if selected else (_accent.darkened(0.45) if unlocked else Db.color("dim"))
	_style.set_border_width_all(4 if selected else 2)
	_style.bg_color = _accent.darkened(0.82) if selected else Db.color("dark")
	_build_sprite(unlocked)
	_build_abilities(hero)


func _build_sprite(unlocked: bool) -> void:
	if _sprite != null:
		_sprite.free()
	_sprite = Sprites.make("heroes/" + hero_id, "idle")
	_sprite.scale = Vector2.ONE * PORTRAIT_SCALE
	_sprite.modulate = Color.WHITE if unlocked else Color(0.25, 0.22, 0.32)
	_portrait.add_child(_sprite)
	_place_sprite()


func _place_sprite() -> void:
	if _sprite != null:
		_sprite.position = Vector2(roundf(_portrait.size.x * 0.5), roundf(PORTRAIT_HEIGHT * 0.62))


func _build_abilities(hero: Dictionary) -> void:
	for child: Node in _abilities.get_children():
		child.free()
	for id: Variant in Db.a(hero, "abilities"):
		var ability_icon: TextureRect = TextureRect.new()
		ability_icon.texture = Sprites.icon("abilities", str(id))
		ability_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		ability_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ability_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ability_icon.tooltip_text = Db.s(AbilitySystem.ability(str(id)), "name")
		_abilities.add_child(ability_icon)


func _play(clip: String) -> void:
	if _sprite != null and _sprite.sprite_frames.has_animation(clip):
		_sprite.play(clip)
