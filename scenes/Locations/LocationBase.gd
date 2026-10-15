extends Node2D
## Base for every location scene. The scene is assembled from the neon tileset in three
## TileMapLayers — Floor (floor + hazard tiles), Walls (solid), Decor (no collision) — plus
## Markers (PlayerSpawn, BossSpawn, Powerups/*). Handles hazard ticks and powerup spawns;
## concrete locations add their flavour in _on_ready_flavor() / _tick_flavor().

const Db = preload("res://core/Db.gd")
const Neon = preload("res://core/Neon.gd")
const Sprites = preload("res://core/Sprites.gd")
const MSEC: float = 1000.0
const COLLISION_KEY: String = "collision"
const KIND_NONE: String = "none"
const KIND_HAZARD: String = "hazard"
const KIND_SOLID: String = "solid"

@export var location_id: String = ""

var config: Dictionary = {}
var target: Node2D = null
var floor_tint: Color = Color.WHITE
var _next_hazard_msec: int = 0
var _next_powerup_msec: int = 0

@onready var floor_layer: TileMapLayer = $Floor
@onready var wall_layer: TileMapLayer = $Walls
@onready var decor_layer: TileMapLayer = $Decor
@onready var _markers: Node2D = $Markers


func _ready() -> void:
	config = Db.entry("locations", "locations", location_id)
	if config.is_empty():
		push_error("Location: unknown location_id '%s'" % location_id)
	floor_tint = Db.color(Db.s(config, "floor_modulate", "white"))
	floor_layer.modulate = floor_tint
	for layer: TileMapLayer in [floor_layer, wall_layer, decor_layer]:
		layer.material = Sprites.FX_MATERIAL
	_on_ready_flavor()


## Called by the Run once the player exists.
func setup(player: Node2D) -> void:
	target = player
	_spawn_initial_powerups()
	_next_powerup_msec = TimeService.deadline(Db.f(config, "powerup_respawn_sec"))


func display_name() -> String:
	return Db.s(config, "name", location_id)


func bounds() -> Rect2:
	var used: Rect2i = floor_layer.get_used_rect()
	var tile: Vector2 = Vector2(floor_layer.tile_set.tile_size) * floor_layer.scale
	return Rect2(floor_layer.global_position + Vector2(used.position) * tile, Vector2(used.size) * tile)


func player_spawn() -> Vector2:
	return _marker_position("PlayerSpawn")


func boss_spawn() -> Vector2:
	return _marker_position("BossSpawn")


func _marker_position(marker_name: String) -> Vector2:
	var marker: Node2D = _markers.get_node_or_null(marker_name)
	return marker.global_position if marker != null else bounds().get_center()


func powerup_spots() -> Array:
	var out: Array = []
	var group: Node = _markers.get_node_or_null("Powerups")
	if group != null:
		for child: Node in group.get_children():
			if child is Node2D:
				out.append((child as Node2D).global_position)
	return out


## "solid" / "hazard" / "none" for the tile under a world position.
func tile_kind_at(world_pos: Vector2) -> String:
	for layer: TileMapLayer in [wall_layer, floor_layer]:
		var data: TileData = layer.get_cell_tile_data(layer.local_to_map(layer.to_local(world_pos)))
		if data != null:
			var kind: String = str(data.get_custom_data(COLLISION_KEY))
			if kind != KIND_NONE and not kind.is_empty():
				return kind
	return KIND_NONE


func is_walkable(world_pos: Vector2) -> bool:
	var wall_cell: Vector2i = wall_layer.local_to_map(wall_layer.to_local(world_pos))
	var floor_cell: Vector2i = floor_layer.local_to_map(floor_layer.to_local(world_pos))
	return wall_layer.get_cell_source_id(wall_cell) == -1 and floor_layer.get_cell_source_id(floor_cell) != -1


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var now: int = TimeService.run_msec()
	if now >= _next_hazard_msec:
		_next_hazard_msec = now + int(Db.f(Db.d(config, "hazard"), "tick_sec") * MSEC)
		_check_hazard()
	if now >= _next_powerup_msec:
		_next_powerup_msec = now + int(Db.f(config, "powerup_respawn_sec") * MSEC)
		var spots: Array = powerup_spots()
		if not spots.is_empty():
			_spawn_powerup(LootRoller.pick(GameState.rng, spots))
	_tick_flavor(now, delta)


func _check_hazard() -> void:
	if tile_kind_at(target.global_position) == KIND_HAZARD and target.has_method("receive_hit"):
		target.call("receive_hit", {"damage": Db.f(Db.d(config, "hazard"), "damage"), "source": "hazard"})


func _spawn_initial_powerups() -> void:
	var spots: Array = LootRoller.shuffled(GameState.rng, powerup_spots())
	for index: int in mini(Db.i(config, "powerups_max"), spots.size()):
		_spawn_powerup(spots[index])


func _spawn_powerup(spot: Vector2) -> void:
	var powerup: Dictionary = LootRoller.pick_weighted(GameState.rng, Db.list("locations", "powerups"), "weight")
	if not powerup.is_empty():
		Signals.pickup_requested.emit("powerup", spot, 0.0, {"id": Db.s(powerup, "id")})


## Hook for location-specific setup (lights, moving hazards).
func _on_ready_flavor() -> void:
	pass


## Hook for location-specific per-frame effects.
func _tick_flavor(_now: int, _delta: float) -> void:
	pass
