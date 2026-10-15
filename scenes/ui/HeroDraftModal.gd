extends "res://scenes/ui/components/ModalBase.gd"
## Run-start draft: the hero offers 3 starting items, the player keeps config.run.draft_picks
## of them. Opens on Signals.run_draft_ready, answers with Signals.hero_draft_chosen.

const MODAL_ID: String = "hero_draft"

var _picked: Array = []

@onready var _subtitle: Label = $Center/Panel/Rows/Subtitle
@onready var _options: HBoxContainer = $Center/Panel/Rows/Options
@onready var _confirm: Button = $Center/Panel/Rows/Confirm


func _ready() -> void:
	modal_id = MODAL_ID
	visible = false
	Signals.run_draft_ready.connect(_on_draft_ready)
	_confirm.pressed.connect(_on_confirm)


func _picks() -> int:
	return Db.cfg_i("run.draft_picks")


func _on_draft_ready(hero_id: String, item_ids: Array) -> void:
	_picked = []
	clear(_options)
	_subtitle.text = "%s: выберите %d предмета из %d" % [Db.s(Db.entry("heroes", "heroes", hero_id), "name"), _picks(), item_ids.size()]
	for id: Variant in item_ids:
		var card: Node = add_card(_options)
		card.call("show_item", str(id), 1)
		(card as Button).pressed.connect(_toggle.bind(str(id), card))
	_refresh()
	open_modal()


func _toggle(item_id: String, card: Node) -> void:
	if _picked.has(item_id):
		_picked.erase(item_id)
	elif _picked.size() < _picks():
		_picked.append(item_id)
	card.call("set_selected", _picked.has(item_id))
	_refresh()


func _refresh() -> void:
	_confirm.disabled = _picked.size() != _picks()
	_confirm.text = "В бой" if not _confirm.disabled else "Выбрано %d/%d" % [_picked.size(), _picks()]


func _on_confirm() -> void:
	if _picked.size() != _picks():
		return
	close_modal()
	Signals.hero_draft_chosen.emit(_picked.duplicate())
