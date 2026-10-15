extends Node
## Ads facade — Yandex Games stub. Rewarded always succeeds one frame later; interstitials only
## between runs, at most once per interstitial_cooldown_seconds, never with no_ads.
## Replace _platform_* with the Yandex `adv.showRewardedVideo / showFullscreenAdv` bridge.

const Db = preload("res://core/Db.gd")
const KIND_REWARDED: String = "rewarded"
const KIND_INTERSTITIAL: String = "interstitial"

var _busy: bool = false
var _last_interstitial_unix: int = 0


func _ready() -> void:
	Signals.ad_rewarded_requested.connect(show_rewarded)


func is_busy() -> bool:
	return _busy


func show_rewarded(placement: String) -> void:
	if _busy:
		Signals.ad_failed.emit(KIND_REWARDED, "busy")
		return
	_busy = true
	_platform_rewarded.call_deferred(placement)


func can_show_interstitial(no_ads: bool) -> bool:
	var cooldown: int = Db.i(Db.d(Db.table("iap"), "ads"), "interstitial_cooldown_seconds")
	return not _busy and not no_ads and TimeService.now_unix() - _last_interstitial_unix >= cooldown


## Returns true when an interstitial was started.
func show_interstitial(no_ads: bool) -> bool:
	if not can_show_interstitial(no_ads):
		return false
	_busy = true
	_last_interstitial_unix = TimeService.now_unix()
	_platform_interstitial.call_deferred()
	return true


func _platform_rewarded(placement: String) -> void:
	_busy = false
	Signals.ad_rewarded_completed.emit(placement)


func _platform_interstitial() -> void:
	_busy = false
	Signals.ad_interstitial_closed.emit()
