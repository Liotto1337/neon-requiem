extends "res://scenes/hub/HubOverlay.gd"
## Skill tree as a graph: three branches (data/meta_tree.json) laid out by prerequisite depth,
## nodes are icon buttons (state colour, level pips), edges glow in the branch colour once
## the prerequisite is bought. Hover shows the node card at the bottom; click buys a level.

const NODE_SIZE: float = 84.0
const ROW_GAP: float = 118.0
const COL_GAP: float = 112.0
const TOP: float = 70.0
const STATE_MAXED: String = "maxed"
const STATE_LOCKED: String = "locked"
const STATE_POOR: String = "poor"
const STATE_READY: String = "ready"

var _graph: Control = null
var _info: Label = null
var _credits: Label = null
var _positions: Dictionary = {}
var _buttons: Dictionary = {}


func build() -> void:
	set_title("НЕЙРОДРЕВО")
	_credits = _label("", 24, Db.color("amber"))
	content.add_child(_credits)
	_graph = Control.new()
	_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph.draw.connect(_draw_edges)
	_graph.resized.connect(_layout)
	content.add_child(_graph)
	_info = _label("Наведите на узел", 18, Db.color("white"))
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(0.0, 84.0)
	content.add_child(_info)
	for branch: Variant in Db.list("meta_tree", "branches"):
		var header: Label = _label(Db.s(branch, "name").to_upper(), 24, Db.color(Db.s(branch, "color", "white")))
		header.name = "Header_" + Db.s(branch, "id")
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.size = Vector2(300.0, 30.0)
		_graph.add_child(header)
	for node: Variant in Db.list("meta_tree", "nodes"):
		_graph.add_child(_make_button(node))


func _make_button(node: Dictionary) -> Button:
	var button: Button = Button.new()
	var id: String = Db.s(node, "id")
	button.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	button.size = Vector2(NODE_SIZE, NODE_SIZE)
	button.icon = Sprites.icon("meta", id)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.mouse_entered.connect(func() -> void: _show_info(node))
	button.pressed.connect(func() -> void: Signals.meta_node_purchase_requested.emit(id))
	var pips: Label = _label("", 14, Db.color("white"))
	pips.name = "Pips"
	pips.position = Vector2(0.0, NODE_SIZE + 2.0)
	pips.size = Vector2(NODE_SIZE, 18.0)
	pips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_child(pips)
	_buttons[id] = button
	return button


# ---------------------------------------------------------------- layout

func _depth(node_id: String, memo: Dictionary) -> int:
	if memo.has(node_id):
		return int(memo[node_id])
	var best: int = 0
	for parent: Variant in Db.a(Db.entry("meta_tree", "nodes", node_id), "requires"):
		best = maxi(best, _depth(str(parent), memo) + 1)
	memo[node_id] = best
	return best


## Branch columns; rows by prerequisite depth; inside a row nodes follow their parents' x.
func _layout() -> void:
	var branches: Array = Db.list("meta_tree", "branches")
	var memo: Dictionary = {}
	_positions.clear()
	for b: int in branches.size():
		var center: float = _graph.size.x * (float(b) + 0.5) / float(branches.size())
		(_graph.get_node("Header_" + Db.s(branches[b], "id")) as Label).position = Vector2(center - 150.0, 0.0)
		var rows: Dictionary = {}
		for node: Variant in Db.list("meta_tree", "nodes"):
			if Db.s(node, "branch") == Db.s(branches[b], "id"):
				var depth: int = _depth(Db.s(node, "id"), memo)
				if not rows.has(depth):
					rows[depth] = []
				(rows[depth] as Array).append(Db.s(node, "id"))
		for depth: int in range(rows.size()):
			_place_row(rows.get(depth, []), depth, center)
	for id: Variant in _buttons.keys():
		var button: Button = _buttons[id]
		button.position = (_positions.get(id, Vector2.ZERO) as Vector2) - Vector2.ONE * NODE_SIZE * 0.5
	_graph.queue_redraw()


func _place_row(ids: Array, depth: int, center: float) -> void:
	var keyed: Array = []
	for id: Variant in ids:
		keyed.append([_parent_x(str(id), center), str(id)])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for k: int in keyed.size():
		var x: float = center + (float(k) - float(keyed.size() - 1) * 0.5) * COL_GAP
		_positions[keyed[k][1]] = Vector2(x, TOP + float(depth) * ROW_GAP)


func _parent_x(node_id: String, fallback: float) -> float:
	var parents: Array = Db.a(Db.entry("meta_tree", "nodes", node_id), "requires")
	var total: float = 0.0
	var count: int = 0
	for parent: Variant in parents:
		if _positions.has(str(parent)):
			total += (_positions[str(parent)] as Vector2).x
			count += 1
	return total / float(count) if count > 0 else fallback


func _draw_edges() -> void:
	for node: Variant in Db.list("meta_tree", "nodes"):
		var id: String = Db.s(node, "id")
		var color: Color = Db.color(Db.s(Db.entry("meta_tree", "branches", Db.s(node, "branch")), "color", "white"))
		for parent: Variant in Db.a(node, "requires"):
			if not _positions.has(str(parent)) or not _positions.has(id):
				continue
			var bought: bool = _level(str(parent)) > 0
			var line: Color = Color(color.r * 1.5, color.g * 1.5, color.b * 1.5) if bought else Color(0.3, 0.27, 0.4, 0.8)
			_graph.draw_line(_positions[str(parent)], _positions[id], line, 4.0 if bought else 2.0)


# ---------------------------------------------------------------- state

func _level(node_id: String) -> int:
	return Db.i(Db.d(meta, "meta_tree_nodes"), node_id)


func _cost(node: Dictionary, level: int) -> int:
	var costs: Array = Db.a(node, "costs")
	return int(Db.num(costs[level])) if level < costs.size() else 0


func node_state(node: Dictionary) -> String:
	var level: int = _level(Db.s(node, "id"))
	if level >= Db.i(node, "max_level"):
		return STATE_MAXED
	var requires: Array = Db.a(node, "requires")
	var unlocked: bool = requires.is_empty()
	for parent: Variant in requires:
		unlocked = unlocked or _level(str(parent)) > 0
	if not unlocked:
		return STATE_LOCKED
	return STATE_READY if Db.i(meta, "currency") >= _cost(node, level) else STATE_POOR


func refresh() -> void:
	_credits.text = "Кредиты: %d" % Db.i(meta, "currency")
	for node: Variant in Db.list("meta_tree", "nodes"):
		_style_button(node)
	_graph.queue_redraw()


func _style_button(node: Dictionary) -> void:
	var id: String = Db.s(node, "id")
	var button: Button = _buttons[id]
	var state: String = node_state(node)
	var branch: Color = Db.color(Db.s(Db.entry("meta_tree", "branches", Db.s(node, "branch")), "color", "white"))
	var border: Color = {STATE_MAXED: Db.color("lime"), STATE_READY: branch, STATE_POOR: branch.darkened(0.5), STATE_LOCKED: Db.color("dim").darkened(0.3)}[state]
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = branch.darkened(0.78) if state != STATE_LOCKED else Color(0.05, 0.04, 0.08)
	style.border_color = border
	style.set_border_width_all(4 if state == STATE_READY or state == STATE_MAXED else 2)
	style.set_corner_radius_all(int(NODE_SIZE * 0.5))
	for slot: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(slot, style)
	button.modulate = Color(0.45, 0.42, 0.55) if state == STATE_LOCKED else Color.WHITE
	var level: int = _level(id)
	(button.get_node("Pips") as Label).text = "●".repeat(level) + "○".repeat(maxi(0, Db.i(node, "max_level") - level))


func _show_info(node: Dictionary) -> void:
	var level: int = _level(Db.s(node, "id"))
	var state: String = node_state(node)
	var tail: String = {STATE_MAXED: "Максимальный уровень", STATE_LOCKED: "Закрыт: купите предыдущий узел ветки",
		STATE_POOR: "Цена %d — не хватает кредитов" % _cost(node, level), STATE_READY: "Нажмите, чтобы купить за %d" % _cost(node, level)}[state]
	_info.text = "%s  [%d/%d]\n%s\n%s" % [Db.s(node, "name"), level, Db.i(node, "max_level"), Db.s(node, "desc"), tail]
