extends Node2D
## Floating damage number: rises and fades, then frees itself. Crits are larger.

const Db = preload("res://core/Db.gd")

var _amount: float = 0.0
var _crit: bool = false
var _color: Color = Color.WHITE

@onready var _label: Label = $Label


func setup(amount: float, crit: bool, color: Color) -> void:
	_amount = amount
	_crit = crit
	_color = color


func _ready() -> void:
	_label.text = str(maxi(1, roundi(_amount)))
	_label.add_theme_font_size_override("font_size", Db.cfg_i("fx.crit_font") if _crit else Db.cfg_i("fx.damage_number_font"))
	_label.add_theme_color_override("font_color", _color)
	var duration: float = Db.cfg_f("fx.damage_number_sec")
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - Db.cfg_f("fx.damage_number_rise_px"), duration)
	tween.tween_property(self, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(queue_free)
