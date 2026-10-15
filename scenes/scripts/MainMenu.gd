extends Node2D
## Main menu (main scene): the game title, hero cards with each hero's animated sprite
## (select an unlocked hero or buy a locked one), "Войти в хаб", "Продолжить забег" (when
## user://run_save.json exists) and "Выход". The hub room drifts behind a dark veil.

const Db = preload("res://core/Db.gd")
const Sprites = preload("res://core/Sprites.gd")
const Neon = preload("res://core/Neon.gd")
const HERO_CARD: PackedScene = preload("res://scenes/ui/components/HeroCard.tscn")
const DRIFT_PX: float = 260.0
const DRIFT_SPEED: float = 0.08

var _meta: Dictionary = {}
var _center: Vector2 = Vector2.ZERO

@onready var _environment: WorldEnvironment = $WorldEnvironment
@onready var _backdrop: Node2D = $Backdrop
@onready var _camera: Camera2D = $Camera
@onready var _cards: HBoxContainer = $UI/Menu/Rows/Cards
@onready var _info: Label = $UI/Menu/Rows/Info
@onready var _play: Button = $UI/Menu/Rows/Buttons/Play
@onready var _continue: Button = $UI/Menu/Rows/Buttons/Continue
@onready var _quit: Button = $UI/Menu/Rows/Buttons/Quit
@onready var _toast: Label = $UI/Menu/Rows/Toast


func _ready() -> void:
	Neon.configure_glow(_environment.environment)
	var room: Node2D = (load(Db.s(Db.table("hub"), "scene")) as PackedScene).instantiate()
	_backdrop.add_child(room)
	for layer_name: String in ["Floor", "Walls", "Decor"]:
		(room.get_node(layer_name) as TileMapLayer).material = Sprites.FX_MATERIAL
	_center = (room.get_node("Markers/Spawn") as Node2D).global_position
	_play.pressed.connect(func() -> void: get_tree().change_scene_to_file(Db.cfg_s("scenes.hub")))
	_continue.pressed.connect(func() -> void: Signals.run_continue_requested.emit())
	_quit.pressed.connect(func() -> void: get_tree().quit())
	Signals.meta_changed.connect(_on_meta)
	Signals.run_started.connect(func(_summary: Dictionary) -> void: get_tree().change_scene_to_file(Db.cfg_s("scenes.run")))
	Signals.toast_requested.connect(func(text: String) -> void: _toast.text = text)
	_toast.text = ""
	Input.set_custom_mouse_cursor(null)
	MetaState.emit_all()


func _process(_delta: float) -> void:
	var t: float = float(Time.get_ticks_msec()) * 0.001 * DRIFT_SPEED
	_camera.global_position = _center + Vector2(cos(t), sin(t * 1.3) * 0.5) * DRIFT_PX


func _on_meta(meta: Dictionary) -> void:
	_meta = meta
	_continue.visible = bool(meta.get("has_run_save", false))
	var stats: Dictionary = Db.d(meta, "stats")
	_info.text = "Кредиты: %d   ·   Забегов: %d   ·   Побед: %d" % [Db.i(meta, "currency"), Db.i(stats, "runs"), Db.i(stats, "wins")]
	for child: Node in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for hero: Variant in Db.list("heroes", "heroes"):
		var card: Button = HERO_CARD.instantiate()
		_cards.add_child(card)
		var id: String = Db.s(hero, "id")
		var unlocked: bool = Db.a(meta, "unlocked_heroes").has(id)
		card.call("show_hero", hero, unlocked, id == Db.s(meta, "selected_hero"))
		if unlocked:
			card.pressed.connect(func() -> void: Signals.hero_selected.emit(id))
		else:
			card.pressed.connect(func() -> void: Signals.hero_unlock_requested.emit(id))
