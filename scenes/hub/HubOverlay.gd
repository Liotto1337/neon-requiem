extends Control
## Base of the hub terminal windows: a dimmed full-screen backdrop with a framed panel, a
## title line and a close hint. Subclasses fill `content` in build() and refresh on
## Signals.meta_changed. The Hub opens one overlay at a time and closes it on ESC / E.

const Db = preload("res://core/Db.gd")
const Sprites = preload("res://core/Sprites.gd")
const Fmt = preload("res://core/Fmt.gd")
const BACKDROP: Color = Color(0.02, 0.01, 0.05, 0.78)

var meta: Dictionary = {}
var content: VBoxContainer = null
var _title: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var margin: float = Db.cfg_f("ui.hub_overlay_margin")
	panel.offset_left = margin
	panel.offset_top = margin * 0.6
	panel.offset_right = -margin
	panel.offset_bottom = -margin * 0.6
	add_child(panel)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	_title = _label("", 34, Db.color("cyan"))
	content.add_child(_title)
	build()
	Signals.meta_changed.connect(_on_meta)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func set_title(text: String) -> void:
	_title.text = "%s    ·    %s — закрыть" % [text, InputMapHelper.label("pause_esc")]


## Subclasses add their widgets to `content` here.
func build() -> void:
	pass


## Subclasses redraw from `meta` here.
func refresh() -> void:
	pass


func open() -> void:
	visible = true
	MetaState.emit_all()


func close() -> void:
	visible = false


func _on_meta(snapshot: Dictionary) -> void:
	meta = snapshot
	if visible:
		refresh()


func clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
