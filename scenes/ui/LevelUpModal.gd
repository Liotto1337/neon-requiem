extends "res://scenes/ui/components/ModalBase.gd"
## Level-up draft: 3 options (new ability / ability upgrade / item) from GameState. Mouse or
## keys 1..3 pick one; the modal closes before announcing the choice, so a queued next
## level-up can reopen it.

const MODAL_ID: String = "levelup"

@onready var _title: Label = $Center/Panel/Rows/Title
@onready var _options: HBoxContainer = $Center/Panel/Rows/Options


func _ready() -> void:
	modal_id = MODAL_ID
	visible = false
	Signals.level_up_ready.connect(_on_level_up_ready)


func _on_level_up_ready(level: int, options: Array) -> void:
	_title.text = "НОВЫЙ УРОВЕНЬ %d" % level
	clear(_options)
	for index: int in options.size():
		var card: Node = add_card(_options)
		card.call("show_option", options[index])
		(card as Button).pressed.connect(_choose.bind(index))
	open_modal()


func _choose(index: int) -> void:
	if not is_open():
		return
	close_modal()
	Signals.levelup_option_chosen.emit(index)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	for index: int in _options.get_child_count():
		if event.is_action_pressed(InputMapHelper.item_action(index)):
			get_viewport().set_input_as_handled()
			_choose(index)
			return
