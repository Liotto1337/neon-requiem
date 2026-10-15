extends Node
## In-app purchases facade — Yandex Games stub. Products and grants live in data/iap.json;
## product ids in the Yandex console must equal the skus there.
## The stub succeeds one frame later; replace _platform_purchase() with the Yandex
## `payments.purchase({id})` bridge. MetaState grants on Signals.purchase_completed.

const Db = preload("res://core/Db.gd")

var _purchasing: String = ""


func _ready() -> void:
	Signals.purchase_requested.connect(purchase)


func products() -> Array:
	return Db.list("iap", "products")


func product(sku: String) -> Dictionary:
	for entry: Variant in products():
		if entry is Dictionary and str((entry as Dictionary).get("sku", "")) == sku:
			return entry
	return {}


func is_busy() -> bool:
	return not _purchasing.is_empty()


func purchase(sku: String) -> void:
	if is_busy():
		Signals.purchase_failed.emit(sku, "busy")
		return
	if product(sku).is_empty():
		push_error("IAP: unknown sku '%s'" % sku)
		Signals.purchase_failed.emit(sku, "unknown_sku")
		return
	_purchasing = sku
	_platform_purchase.call_deferred(sku)


func _platform_purchase(sku: String) -> void:
	_purchasing = ""
	Signals.purchase_completed.emit(sku)
