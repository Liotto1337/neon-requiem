extends "res://scenes/ui/components/ModalBase.gd"
## Defeat screen: run summary and the forced return to the hub. Run credits are lost (only
## config.meta.defeat_keep_fraction is banked); meta unlocks stay.

const Fmt = preload("res://core/Fmt.gd")
const MODAL_ID: String = "game_over"

@onready var _summary: Label = $Center/Panel/Rows/Summary
@onready var _button: Button = $Center/Panel/Rows/ToHub


func _ready() -> void:
	modal_id = MODAL_ID
	visible = false
	Signals.player_died.connect(_on_player_died)
	_button.pressed.connect(_on_to_hub)


func _on_player_died(summary: Dictionary) -> void:
	var kept: int = floori(float(Db.i(summary, "currency")) * Db.cfg_f("meta.defeat_keep_fraction"))
	var lines: Array[String] = [
		"Время: %s" % Fmt.clock(Db.f(summary, "elapsed_sec")),
		"Уровень: %d · Убийств: %d · Угроза: %d" % [Db.i(summary, "level", 1), Db.i(summary, "kills"), Db.i(summary, "tier")],
		"Петля: %d" % Db.i(summary, "loop_count"),
		"Кредиты забега: %d — в банк уйдёт %d" % [Db.i(summary, "currency"), kept],
		"Открытия и прокачка хаба сохраняются.",
	]
	_summary.text = "\n".join(lines)
	open_modal()


func _on_to_hub() -> void:
	close_modal()
	Signals.game_over_confirmed.emit()
