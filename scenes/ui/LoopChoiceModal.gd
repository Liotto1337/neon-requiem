extends "res://scenes/ui/components/ModalBase.gd"
## Victory after the final boss: return to the hub (bank all run credits) or start the next
## loop (location 1 again, items kept, difficulty multiplier grows).

const Fmt = preload("res://core/Fmt.gd")
const MODAL_ID: String = "loop_choice"

@onready var _summary: Label = $Center/Panel/Rows/Summary
@onready var _hub_button: Button = $Center/Panel/Rows/Buttons/ToHub
@onready var _loop_button: Button = $Center/Panel/Rows/Buttons/Loop


func _ready() -> void:
	modal_id = MODAL_ID
	visible = false
	Signals.victory_reached.connect(_on_victory)
	_hub_button.pressed.connect(_choose.bind("hub"))
	_loop_button.pressed.connect(_choose.bind("loop"))


func _on_victory(summary: Dictionary) -> void:
	var factor: float = Db.f(Db.d(Db.table("difficulty"), "loop"), "multiplier_factor", 1.0)
	_summary.text = "Время: %s · Уровень: %d · Убийств: %d\nКредиты забега: %d" % [
		Fmt.clock(Db.f(summary, "elapsed_sec")), Db.i(summary, "level", 1), Db.i(summary, "kills"), Db.i(summary, "currency"),
	]
	_hub_button.text = "В хаб — сохранить %d кредитов" % Db.i(summary, "currency")
	_loop_button.text = "Петля %d — предметы с собой, сложность ×%s" % [Db.i(summary, "loop_count") + 1, String.num(factor, 1)]
	open_modal()


func _choose(choice: String) -> void:
	close_modal()
	Signals.loop_choice_made.emit(choice)
