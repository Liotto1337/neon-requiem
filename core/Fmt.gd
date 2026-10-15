extends RefCounted
## Text formatting for the UI: timers, numbers, percents, stat names.

const SECONDS_PER_MINUTE: int = 60
const PERCENT: float = 100.0
const STAT_NAMES: Dictionary = {
	"hp_max": "Макс. HP",
	"mana_max": "Макс. мана",
	"hp_regen": "Реген HP/с",
	"mana_regen": "Реген маны/с",
	"move_speed": "Скорость",
	"damage_mult": "Урон",
	"crit_chance": "Шанс крита",
	"crit_mult": "Крит. урон",
	"attack_speed_mult": "Скорость атаки",
	"cooldown_mult": "Перезарядка",
	"armor": "Броня",
	"lifesteal_pct": "Вампиризм",
	"thorns_pct": "Шипы",
	"pickup_radius": "Радиус сбора",
	"xp_mult": "Опыт",
	"currency_mult": "Кредиты",
	"area_mult": "Площадь",
	"drone_damage_mult": "Урон дронов",
}
const PERCENT_STATS: Array[String] = ["crit_chance", "lifesteal_pct", "thorns_pct"]
const MULT_STATS: Array[String] = [
	"damage_mult", "crit_mult", "attack_speed_mult", "cooldown_mult", "xp_mult",
	"currency_mult", "area_mult", "drone_damage_mult",
]


static func clock(seconds: float) -> String:
	var total: int = maxi(0, floori(seconds))
	return "%02d:%02d" % [floori(float(total) / float(SECONDS_PER_MINUTE)), total % SECONDS_PER_MINUTE]


static func whole(value: float) -> String:
	return str(roundi(value))


static func one(value: float) -> String:
	return String.num(value, 1)


static func stat_name(key: String) -> String:
	return str(STAT_NAMES.get(key, key))


static func stat_value(key: String, value: float) -> String:
	if PERCENT_STATS.has(key):
		return "%s%%" % one(value)
	if MULT_STATS.has(key):
		return "×%s" % String.num(value, 2)
	return one(value)
