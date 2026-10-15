extends Control
## Run HUD: HP / mana / XP / credits (top-left), timer, location, threat tier and boss bar
## (top), ability slots Z X C V [B] and active item slots 1..6 [7] (bottom), class action
## state and toasts. Reads state only from Signals.

const Db = preload("res://core/Db.gd")
const Fmt = preload("res://core/Fmt.gd")
const SLOT_SCENE: PackedScene = preload("res://scenes/ui/components/AbilitySlot.tscn")
const MSEC: float = 1000.0
const KIND_ABILITY: String = "ability"
const KIND_ITEM: String = "item"
const FAIL_TEXT: Dictionary = {
	"mana": "Не хватает маны",
	"ammo": "Мало патронов",
	"no_target": "Нет цели",
}

var _abilities: Array = []
var _actives: Array = []
var _location_name: String = ""
var _tier: int = 0
var _multiplier: float = 1.0
var _loop: int = 0
var _action_label: String = ""
var _action_ready_msec: int = 0
var _ammo_text: String = ""
var _buffs: Array = []
var _antiheal: bool = false
var _shield: float = 0.0

@onready var _hp_bar: ProgressBar = $Resources/Rows/HpRow/Bars/HpBar
@onready var _shield_bar: ProgressBar = $Resources/Rows/HpRow/Bars/ShieldBar
@onready var _hp_text: Label = $Resources/Rows/HpRow/Text
@onready var _mana_bar: ProgressBar = $Resources/Rows/ManaRow/Bar
@onready var _mana_text: Label = $Resources/Rows/ManaRow/Text
@onready var _level_label: Label = $Resources/Rows/XpRow/Name
@onready var _xp_bar: ProgressBar = $Resources/Rows/XpRow/Bar
@onready var _xp_text: Label = $Resources/Rows/XpRow/Text
@onready var _currency_text: Label = $Resources/Rows/CurrencyRow/Text
@onready var _status: Label = $Resources/Rows/Status
@onready var _timer: Label = $Top/Timer
@onready var _info: Label = $Top/Info
@onready var _boss_box: VBoxContainer = $Top/BossBox
@onready var _boss_name: Label = $Top/BossBox/BossName
@onready var _boss_bar: ProgressBar = $Top/BossBox/BossBar
@onready var _ability_row: HBoxContainer = $Bottom/Abilities
@onready var _item_row: HBoxContainer = $Bottom/Items
@onready var _class_info: Label = $ClassInfo
@onready var _toasts: VBoxContainer = $Toasts


func _ready() -> void:
	Signals.resources_changed.connect(_on_resources)
	Signals.timer_changed.connect(_on_timer)
	Signals.difficulty_changed.connect(_on_difficulty)
	Signals.location_changed.connect(_on_location)
	Signals.abilities_changed.connect(_on_abilities)
	Signals.items_changed.connect(_on_items)
	Signals.slot_limits_changed.connect(_on_slot_limits)
	Signals.ability_cooldown_started.connect(_on_ability_cooldown)
	Signals.item_cooldown_started.connect(_on_item_cooldown)
	Signals.cast_failed.connect(_on_cast_failed)
	Signals.ammo_changed.connect(_on_ammo)
	Signals.class_action_changed.connect(_on_class_action)
	Signals.boss_spawned.connect(_on_boss_spawned)
	Signals.boss_health_changed.connect(_on_boss_health)
	Signals.boss_defeated.connect(_on_boss_defeated)
	Signals.buffs_changed.connect(_on_buffs)
	Signals.antiheal_changed.connect(_on_antiheal)
	Signals.toast_requested.connect(show_toast)
	Signals.item_gained.connect(_on_item_gained)
	Signals.loop_started.connect(_on_loop_started)
	_on_slot_limits({"abilities": Db.cfg_i("slots.abilities"), "active_items": Db.cfg_i("slots.active_items")})


func _on_resources(res: Dictionary) -> void:
	_set_bar(_hp_bar, Db.f(res, "hp"), Db.f(res, "hp_max"))
	_hp_text.text = "%s/%s" % [Fmt.whole(Db.f(res, "hp")), Fmt.whole(Db.f(res, "hp_max"))]
	_shield = Db.f(res, "shield")
	_set_bar(_shield_bar, _shield, Db.f(res, "hp_max"))
	_set_bar(_mana_bar, Db.f(res, "mana"), Db.f(res, "mana_max"))
	_mana_text.text = "%s/%s" % [Fmt.whole(Db.f(res, "mana")), Fmt.whole(Db.f(res, "mana_max"))]
	var level: int = Db.i(res, "level", 1)
	_level_label.text = "Ур. %d" % level
	var capped: bool = level >= Db.i(res, "level_cap")
	_set_bar(_xp_bar, 1.0 if capped else Db.f(res, "xp"), 1.0 if capped else Db.f(res, "xp_needed"))
	_xp_text.text = "МАКС" if capped else "%s/%d" % [Fmt.whole(Db.f(res, "xp")), Db.i(res, "xp_needed")]
	_currency_text.text = str(Db.i(res, "currency"))
	_refresh_status()


func _set_bar(bar: ProgressBar, value: float, maximum: float) -> void:
	bar.max_value = maxf(0.001, maximum)
	bar.value = clampf(value, 0.0, bar.max_value)


func _on_timer(elapsed_sec: float, location_elapsed_sec: float) -> void:
	_timer.text = Fmt.clock(elapsed_sec)
	_timer.tooltip_text = "В локации: %s" % Fmt.clock(location_elapsed_sec)


func _on_difficulty(tier: int, multiplier: float, loop_count: int) -> void:
	_tier = tier
	_multiplier = multiplier
	_loop = loop_count
	_refresh_info()


func _on_location(location_id: String, index: int, count: int) -> void:
	_location_name = "%s (%d/%d)" % [Db.s(Db.entry("locations", "locations", location_id), "name", location_id), index + 1, count]
	_boss_box.visible = false
	_refresh_info()


func _refresh_info() -> void:
	var loop_text: String = " · Петля %d (×%s)" % [_loop, String.num(_multiplier, 2)] if _loop > 0 else ""
	_info.text = "%s · Угроза %d%s" % [_location_name, _tier, loop_text]


func _on_slot_limits(limits: Dictionary) -> void:
	_rebuild_row(_ability_row, Db.i(limits, "abilities"), KIND_ABILITY)
	_rebuild_row(_item_row, Db.i(limits, "active_items"), KIND_ITEM)
	_fill_abilities()
	_fill_items()


func _rebuild_row(row: HBoxContainer, count: int, kind: String) -> void:
	for child: Node in row.get_children():
		child.free()
	for slot: int in count:
		var widget: Node = SLOT_SCENE.instantiate()
		row.add_child(widget)
		var action: String = InputMapHelper.ability_action(slot) if kind == KIND_ABILITY else InputMapHelper.item_action(slot)
		widget.call("set_key", InputMapHelper.label(action))


func _on_abilities(abilities: Array) -> void:
	_abilities = abilities
	_fill_abilities()


func _fill_abilities() -> void:
	for slot: int in _ability_row.get_child_count():
		_ability_row.get_child(slot).call("show_empty")
	for entry: Variant in _abilities:
		var slot: int = Db.i(entry, "slot")
		if slot < _ability_row.get_child_count():
			_ability_row.get_child(slot).call("show_ability", entry)


func _on_items(_passives: Array, actives: Array) -> void:
	_actives = actives
	_fill_items()


func _fill_items() -> void:
	for slot: int in _item_row.get_child_count():
		_item_row.get_child(slot).call("show_empty")
	for entry: Variant in _actives:
		var slot: int = Db.i(entry, "slot")
		if slot < _item_row.get_child_count():
			_item_row.get_child(slot).call("show_item", Db.s(entry, "id"))


func _on_ability_cooldown(slot: int, duration_sec: float) -> void:
	if slot < _ability_row.get_child_count():
		_ability_row.get_child(slot).call("start_cooldown", duration_sec)


func _on_item_cooldown(slot: int, duration_sec: float) -> void:
	if slot < _item_row.get_child_count():
		_item_row.get_child(slot).call("start_cooldown", duration_sec)


func _on_cast_failed(kind: String, slot: int, reason: String) -> void:
	var row: HBoxContainer = _ability_row if kind == KIND_ABILITY else _item_row
	if (kind == KIND_ABILITY or kind == KIND_ITEM) and slot >= 0 and slot < row.get_child_count():
		row.get_child(slot).call("flash_fail")
	if FAIL_TEXT.has(reason):
		show_toast(str(FAIL_TEXT[reason]))


func _on_ammo(current: int, magazine: int, reloading: bool) -> void:
	_ammo_text = "Перезарядка…" if reloading else "Патроны %d/%d" % [current, magazine]


func _on_class_action(label: String, ready_in_sec: float) -> void:
	_action_label = label
	_action_ready_msec = TimeService.deadline(ready_in_sec)


func _process(_delta: float) -> void:
	var left: float = TimeService.until_sec(_action_ready_msec)
	var state: String = "готово" if left <= 0.0 else "%s с" % String.num(left, 1)
	var prefix: String = _ammo_text + "   " if not _ammo_text.is_empty() else ""
	_class_info.text = "%sR — %s: %s" % [prefix, _action_label, state]


func _on_boss_spawned(_boss_id: String, boss_name: String, hp_max: float, kind: String) -> void:
	_boss_box.visible = true
	_boss_name.text = ("Минибосс: %s" if kind == "miniboss" else "БОСС: %s") % boss_name
	_set_bar(_boss_bar, hp_max, hp_max)
	show_toast(_boss_name.text)


func _on_boss_health(hp: float, hp_max: float, phase: int) -> void:
	_set_bar(_boss_bar, hp, hp_max)
	_boss_bar.tooltip_text = "Фаза %d" % (phase + 1)


func _on_boss_defeated(_boss_id: String, kind: String, is_final: bool) -> void:
	_boss_box.visible = false
	if kind == "boss" and not is_final:
		show_toast("Босс повержен — переход в следующую локацию")


func _on_buffs(buffs: Array) -> void:
	_buffs = buffs
	_refresh_status()


func _on_antiheal(active: bool) -> void:
	_antiheal = active
	_refresh_status()


func _refresh_status() -> void:
	var parts: Array[String] = []
	if _antiheal:
		parts.append("АНТИХИЛ: регенерация заблокирована")
	if _shield > 0.0:
		parts.append("Щит %s" % Fmt.whole(_shield))
	for buff: Variant in _buffs:
		parts.append(Db.s(buff, "name"))
	_status.text = " · ".join(parts)
	_status.add_theme_color_override("font_color", Db.color("red") if _antiheal else Db.color("white"))


func _on_item_gained(item_id: String, source: String) -> void:
	if source == "levelup" or source == "draft":
		return
	show_toast("Предмет: %s" % Db.s(ItemSystem.item(item_id), "name"))


func _on_loop_started(loop_count: int, multiplier: float) -> void:
	show_toast("Петля %d: сложность ×%s" % [loop_count, String.num(multiplier, 2)])


func show_toast(text: String) -> void:
	if _toasts.get_child_count() >= Db.cfg_i("ui.toast_max"):
		_toasts.get_child(0).free()
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Db.color("amber"))
	_toasts.add_child(label)
	var tween: Tween = label.create_tween()
	tween.tween_interval(Db.cfg_f("ui.toast_sec"))
	tween.tween_property(label, "modulate:a", 0.0, Db.cfg_f("ui.toast_sec") * 0.3)
	tween.tween_callback(label.queue_free)
