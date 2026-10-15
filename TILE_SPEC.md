# TILE_SPEC — тайлы Neon Requiem

Спецификация тайлов. Источник правды — `data/tiles.json`. Атлас рисуется кодом
(`tools/art/tiles.py`, без нейросетей) в `assets/tiles/neon_atlas.png`; TileSet и сцены локаций
собирает `tools/build_world.gd`.

## Сетка и формат

| Параметр | Значение |
|---|---|
| Тайл | 64×64 px, 1 пиксель арта = 1 пиксель экрана при 1080p |
| Атлас | 16 столбцов × 8 строк = 1024×512 px, один источник `source_id = 0` |
| Координаты | `atlas` = (столбец, строка) первой ячейки тайла |
| Варианты | `variants` — сколько ячеек вправо занимают варианты рисунка; сборщик выбирает вариант случайно по `variant_weights` |
| Анимация | `frames` — кадры анимации вправо от первой ячейки, `frame_sec` на кадр (TileSet animation) |
| Фасад | `face` — тайл передней грани стены (вид 3/4): ставится, когда под стеной открытый пол |
| TileSet | `scenes/Locations/tiles/neon_tileset.tres` |
| Физика | physics layer 0 → слой коллизий 6 `wall` (bit 32), полигон на весь тайл для `solid` |
| Custom data | `collision` (String: `none` / `solid` / `hazard`), `tile_id` (String) |
| Фильтр | nearest (пиксель-арт), без mipmap |
| Свечение | слои локации рисуются общим материалом `SpriteFx`: неоновые пиксели (ярче 0,9) усиливаются и светятся |

## Слои локации

Каждая сцена `scenes/Locations/*.tscn` собрана из трёх TileMapLayer:

| Слой | Узел | z_index | Что лежит | Коллизия |
|---|---|---|---|---|
| floor | `Floor` | −10 | пол и опасные тайлы (`hazard`) | нет; `hazard` наносит урон раз в `hazard.tick_sec` |
| wall | `Walls` | −6 | стены (крыша и фасад), граница арены | `solid` — слой физики 6 (`wall`) |
| decor | `Decor` | −8 | вывески, кабели, растения, руны | нет |

Плюс `Markers`: `PlayerSpawn`, `BossSpawn`, `Powerups/Spot0..N` (места временных усилений).

## Тайлы

| tile_id | Название | Ячейки атласа | collision | Слой | Варианты / анимация | Локации | Рисунок (`art`) |
|---|---|---|---|---|---|---|---|
| `floor_slum_a` | Асфальт трущоб | (0…3, 0) | none | floor (пол) | 4 варианта | Неоновые трущобы | asphalt |
| `floor_slum_b` | Асфальт с лужей | (4…5, 0) | none | floor (пол) | 2 варианта | Неоновые трущобы | puddle |
| `wall_slum` | Крыша трущоб | (6…7, 0) | solid | wall (стены) | 2 варианта фасад: `wall_slum_face` | Неоновые трущобы | wall_top:slum |
| `wall_slum_face` | Кирпичный фасад | (8…10, 0) | solid | wall (стены) | 3 варианта | Неоновые трущобы | wall_face:slum |
| `hazard_toxic` | Токсичная лужа | (11…14, 0) | hazard | floor (пол) | анимация 4 кадров | Неоновые трущобы | hazard:toxic |
| `floor_core_a` | Плита ядра | (0…3, 1) | none | floor (пол) | 4 варианта | Ядро данных | plate |
| `floor_core_glow` | Светящаяся плита | (4…5, 1) | none | floor (пол) | 2 варианта | Ядро данных | glow |
| `wall_core` | Серверная стойка | (6…7, 1) | solid | wall (стены) | 2 варианта фасад: `wall_core_face` | Ядро данных | wall_top:core |
| `wall_core_face` | Фронт стойки | (8…10, 1) | solid | wall (стены) | 3 варианта | Ядро данных | wall_face:core |
| `hazard_data_spike` | Статическое поле | (11…14, 1) | hazard | floor (пол) | анимация 4 кадров | Ядро данных | hazard:static |
| `floor_garden_a` | Мох | (0…3, 2) | none | floor (пол) | 4 варианта | Хромовые сады | moss |
| `floor_garden_b` | Мох со светлячками | (4…5, 2) | none | floor (пол) | 2 варианта | Хромовые сады | moss_bright |
| `wall_garden` | Заросший хром | (6…7, 2) | solid | wall (стены) | 2 варианта фасад: `wall_garden_face` | Хромовые сады | wall_top:garden |
| `wall_garden_face` | Хромовая колонна | (8…10, 2) | solid | wall (стены) | 3 варианта | Хромовые сады | wall_face:garden |
| `hazard_vines` | Терновые лозы | (11…14, 2) | hazard | floor (пол) | анимация 4 кадров | Хромовые сады | hazard:vines |
| `floor_rail_a` | Ржавая плита | (0…3, 3) | none | floor (пол) | 4 варианта | Пепельная магистраль | rust |
| `floor_rail_b` | Шпалы | (4, 3) | none | floor (пол) | — | Пепельная магистраль | track |
| `wall_rail` | Балка | (6…7, 3) | solid | wall (стены) | 2 варианта фасад: `wall_rail_face` | Пепельная магистраль | wall_top:rail |
| `wall_rail_face` | Ферма | (8…10, 3) | solid | wall (стены) | 3 варианта | Пепельная магистраль | wall_face:rail |
| `hazard_rail_h` | Рельс под током (гор.) | (11…14, 3) | hazard | floor (пол) | анимация 4 кадров | Пепельная магистраль | hazard:rail_h |
| `floor_spire_a` | Мрамор шпиля | (0…3, 4) | none | floor (пол) | 4 варианта | Шпиль реквиема | marble |
| `floor_spire_rune` | Руна на мраморе | (4…5, 4) | none | floor (пол) | 2 варианта | Шпиль реквиема | rune |
| `wall_spire` | Колонна шпиля | (6…7, 4) | solid | wall (стены) | 2 варианта фасад: `wall_spire_face` | Шпиль реквиема | wall_top:spire |
| `wall_spire_face` | Основание колонны | (8…9, 4) | solid | wall (стены) | 2 варианта | Шпиль реквиема | wall_face:spire |
| `hazard_void` | Разлом пустоты | (11…14, 4) | hazard | floor (пол) | анимация 4 кадров | Шпиль реквиема | hazard:void |
| `wall_neon_edge` | Неоновый блок | (0, 5) | solid | wall (стены) | — фасад: `wall_neon_edge_face` | Неоновые трущобы, Пепельная магистраль, Хромовые сады, Шпиль реквиема, Ядро данных | wall_top:edge |
| `wall_neon_edge_face` | Неоновый фасад | (1…2, 5) | solid | wall (стены) | 2 варианта | Неоновые трущобы, Пепельная магистраль, Хромовые сады, Шпиль реквиема, Ядро данных | wall_face:edge |
| `wall_crate` | Ящик | (3, 5) | solid | wall (стены) | — фасад: `wall_crate_face` | — | wall_top:crate |
| `wall_crate_face` | Ящик (фасад) | (4, 5) | solid | wall (стены) | — | — | wall_face:crate |
| `wall_barrier` | Барьер | (5, 5) | solid | wall (стены) | — фасад: `wall_barrier_face` | Шпиль реквиема | wall_top:barrier |
| `wall_barrier_face` | Барьер (фасад) | (6, 5) | solid | wall (стены) | — | Шпиль реквиема | wall_face:barrier |
| `hazard_rail_v` | Рельс под током (верт.) | (11…14, 5) | hazard | floor (пол) | анимация 4 кадров | — | hazard:rail_v |
| `decor_sign_cyan` | Вывеска (циан) | (0, 6) | none | decor (декор) | — | Неоновые трущобы | decor:sign_cyan |
| `decor_sign_magenta` | Вывеска (маджента) | (1, 6) | none | decor (декор) | — | Неоновые трущобы | decor:sign_magenta |
| `decor_cable` | Кабели | (2, 6) | none | decor (декор) | — | Неоновые трущобы, Ядро данных | decor:cable |
| `decor_vent` | Решётка | (3, 6) | none | decor (декор) | — | Пепельная магистраль, Ядро данных | decor:vent |
| `decor_plant` | Хром-папоротник | (4, 6) | none | decor (декор) | — | Хромовые сады | decor:plant |
| `decor_debris` | Обломки | (5, 6) | none | decor (декор) | — | Неоновые трущобы, Пепельная магистраль, Хромовые сады | decor:debris |
| `decor_rune` | Светящаяся руна | (6, 6) | none | decor (декор) | — | Шпиль реквиема | decor:rune |
| `decor_lamp` | Фонарь | (7, 6) | none | decor (декор) | — | Пепельная магистраль, Хромовые сады, Шпиль реквиема, Ядро данных | decor:lamp |
| `decor_hub_planter` | Клумба хаба | (8, 6) | none | decor (декор) | — | — | decor:hub_planter |
| `decor_hub_screen` | Экран хаба | (9, 6) | none | decor (декор) | — | — | decor:hub_screen |
| `floor_hub` | Пол хаба | (0…3, 7) | none | floor (пол) | 4 варианта | — | hub |
| `floor_hub_line` | Неоновая разметка | (4…5, 7) | none | floor (пол) | 2 варианта | — | hub_line |
| `wall_hub` | Стена хаба | (6, 7) | solid | wall (стены) | — фасад: `wall_hub_face` | — | wall_top:hub |
| `wall_hub_face` | Панель хаба | (7…8, 7) | solid | wall (стены) | 2 варианта | — | wall_face:hub |

## Как поменять графику

1. Поправить рисунок в `tools/art/tiles.py` (или заменить `assets/tiles/neon_atlas.png` своим
   PNG с той же сеткой 64×64 и расположением ячеек).
2. Пересобрать: `GODOT=<путь к Godot> tools/art/rebuild.sh tiles` — рисует атлас, импортирует его
   и заново собирает TileSet и пять локаций.

## Пересборка локаций

`tools/build_world.gd` (сцена `tools/BuildWorld.tscn`) по блокам `layout` из `data/locations.json`
собирает TileSet и пять сцен локаций. Размеры планировки — в тайлах 64 px. Стили: `alleys`
(трущобы), `racks` (ядро данных), `garden` (сады), `rail` (магистраль с путями), `arena` (шпиль).
После пересборки сцены можно править вручную в редакторе: рисовать тайлы, двигать маркеры.
