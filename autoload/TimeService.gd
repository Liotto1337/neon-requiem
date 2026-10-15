extends Node
## Unix time for saves + the run clock. The run clock is Time.get_ticks_msec() minus paused
## time, so cooldowns, buffs, spawns and the run timer freeze while the game is paused.
## No Timer nodes drive gameplay: everything compares against run_msec().

const MSEC: float = 1000.0

var _paused: bool = false
var _pause_started_msec: int = 0
var _paused_total_msec: int = 0
var _skip_msec: int = 0
var _run_base_msec: int = 0
var _elapsed_base_sec: float = 0.0
var _location_base_msec: int = 0
var _location_base_sec: float = 0.0


func now_unix() -> int:
	return int(Time.get_unix_time_from_system())


## Run clock in msec: ticks minus paused time plus debug skips. Monotonic within a session.
func run_msec() -> int:
	var now: int = Time.get_ticks_msec()
	var paused_now: int = now - _pause_started_msec if _paused else 0
	return now - _paused_total_msec - paused_now + _skip_msec


func is_paused() -> bool:
	return _paused


func set_paused(paused: bool) -> void:
	if paused == _paused:
		return
	var now: int = Time.get_ticks_msec()
	if paused:
		_pause_started_msec = now
	else:
		_paused_total_msec += now - _pause_started_msec
	_paused = paused


func start_run_clock(run_elapsed: float, location_elapsed: float) -> void:
	var now: int = run_msec()
	_run_base_msec = now
	_elapsed_base_sec = run_elapsed
	_location_base_msec = now
	_location_base_sec = location_elapsed


func reset_location_clock() -> void:
	_location_base_msec = run_msec()
	_location_base_sec = 0.0


func elapsed_sec() -> float:
	return _elapsed_base_sec + float(run_msec() - _run_base_msec) / MSEC


func location_elapsed_sec() -> float:
	return _location_base_sec + float(run_msec() - _location_base_msec) / MSEC


## Seconds until a run-clock deadline (negative when it has passed).
func until_sec(deadline_msec: int) -> float:
	return float(deadline_msec - run_msec()) / MSEC


func deadline(seconds: float) -> int:
	return run_msec() + int(seconds * MSEC)


## Moves the run clock forward (debug key F10 and the smoke test).
func skip(seconds: float) -> void:
	_skip_msec += int(seconds * MSEC)
