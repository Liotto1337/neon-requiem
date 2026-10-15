extends Control
## Shared behaviour of full-screen run modals: show / hide and announce visibility on the
## Signals bus, so the Run pauses while any modal is open.

const Db = preload("res://core/Db.gd")
const CARD_SCENE: PackedScene = preload("res://scenes/ui/components/ItemCard.tscn")

var modal_id: String = ""


func open_modal() -> void:
	if visible:
		return
	visible = true
	Signals.modal_visibility_changed.emit(modal_id, true)


func close_modal() -> void:
	if not visible:
		return
	visible = false
	Signals.modal_visibility_changed.emit(modal_id, false)


func is_open() -> bool:
	return visible


func clear(container: Node) -> void:
	for child: Node in container.get_children():
		child.queue_free()
		container.remove_child(child)


## Adds an ItemCard to `container` (already in the tree, so show_* works right away).
func add_card(container: Node) -> Node:
	var card: Node = CARD_SCENE.instantiate()
	container.add_child(card)
	return card
