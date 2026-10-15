extends RefCounted
## Read-only balance tables from res://data/*.json, loaded on first use and cached for the
## session. Every tunable number in the game is read through here (preload this script as Db).

const DATA_DIR: String = "res://data/"
const JSON_EXT: String = ".json"
const CONFIG: String = "config"

static var _tables: Dictionary = {}
static var _indexes: Dictionary = {}


static func table(table_name: String) -> Dictionary:
	if not _tables.has(table_name):
		_tables[table_name] = _load(table_name)
	return _tables[table_name]


static func _load(table_name: String) -> Dictionary:
	var path: String = DATA_DIR + table_name + JSON_EXT
	if not FileAccess.file_exists(path):
		push_error("Db: missing data file %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Db: invalid JSON in %s" % path)
		return {}
	return parsed


## Array stored under `key` of a table, e.g. list("enemies", "enemies").
static func list(table_name: String, key: String) -> Array:
	var value: Variant = table(table_name).get(key, [])
	if value is Array:
		return value
	push_error("Db: %s.%s is not an array" % [table_name, key])
	return []


## Entry with matching "id" inside list `key` of `table_name`; {} when absent.
static func entry(table_name: String, key: String, id: String) -> Dictionary:
	var index_key: String = table_name + "/" + key
	if not _indexes.has(index_key):
		var index: Dictionary = {}
		for item: Variant in list(table_name, key):
			if item is Dictionary:
				index[str((item as Dictionary).get("id", ""))] = item
		_indexes[index_key] = index
	var found: Variant = (_indexes[index_key] as Dictionary).get(id, {})
	return found


## Value at a dotted path inside a dictionary; null (with an error) when missing.
static func dig(source: Dictionary, path: String) -> Variant:
	var node: Variant = source
	for part: String in path.split("."):
		if not node is Dictionary or not (node as Dictionary).has(part):
			push_error("Db: missing key '%s'" % path)
			return null
		node = (node as Dictionary)[part]
	return node


static func cfg(path: String) -> Variant:
	return dig(table(CONFIG), path)


static func cfg_f(path: String) -> float:
	return num(cfg(path))


static func cfg_i(path: String) -> int:
	return int(num(cfg(path)))


static func cfg_s(path: String) -> String:
	var value: Variant = cfg(path)
	return "" if value == null else str(value)


static func cfg_d(path: String) -> Dictionary:
	var value: Variant = cfg(path)
	return value if value is Dictionary else {}


static func cfg_a(path: String) -> Array:
	var value: Variant = cfg(path)
	return value if value is Array else []


## Number from a JSON value (JSON numbers parse as float); `fallback` for anything else.
static func num(value: Variant, fallback: float = 0.0) -> float:
	if value is float or value is int:
		return float(value)
	return fallback


static func f(source: Dictionary, key: String, fallback: float = 0.0) -> float:
	return num(source.get(key, fallback), fallback)


static func i(source: Dictionary, key: String, fallback: int = 0) -> int:
	return int(num(source.get(key, fallback), float(fallback)))


static func s(source: Dictionary, key: String, fallback: String = "") -> String:
	var value: Variant = source.get(key, fallback)
	return fallback if value == null else str(value)


static func d(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	return value if value is Dictionary else {}


static func a(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	return value if value is Array else []


## Palette colour by name ("cyan") or a raw "#rrggbb" string.
static func color(name_or_hex: String) -> Color:
	var palette: Dictionary = d(table(CONFIG), "palette")
	var hex: String = str(palette.get(name_or_hex, name_or_hex))
	return Color.html(hex) if Color.html_is_valid(hex) else Color.WHITE


## Palette colour pushed above 1.0 so it crosses the glow threshold (HDR 2D).
static func glow(name_or_hex: String, energy: float = -1.0) -> Color:
	var boost: float = energy if energy > 0.0 else cfg_f("glow.hdr_energy")
	var base: Color = color(name_or_hex)
	return Color(base.r * boost, base.g * boost, base.b * boost, base.a)


## Collision bit for a named physics layer from config.physics_layers (1-based index).
static func layer_bit(layer_name: String) -> int:
	return 1 << (cfg_i("physics_layers." + layer_name) - 1)
