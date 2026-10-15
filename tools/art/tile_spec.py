"""Writes TILE_SPEC.md from data/tiles.json, data/locations.json and data/hub.json.
Usage: python3 tools/art/tile_spec.py   (build_art.py runs it after the tiles)."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LAYERS = {"floor": "floor (пол)", "wall": "wall (стены)", "decor": "decor (декор)", "shadow": "shadow (тени)"}


def _load(name: str) -> dict:
    return json.loads((ROOT / "data" / name).read_text(encoding="utf-8"))


def _mentions(node, ids: set[str]) -> set[str]:
    """Tile ids named anywhere in a JSON block (as values or as dictionary keys)."""
    found: set[str] = set()
    if isinstance(node, dict):
        for key, value in node.items():
            if key in ids:
                found.add(key)
            found |= _mentions(value, ids)
    elif isinstance(node, list):
        for value in node:
            found |= _mentions(value, ids)
    elif isinstance(node, str) and node in ids:
        found.add(node)
    return found


def _usage(ids: set[str]) -> dict[str, list[str]]:
    used: dict[str, list[str]] = {tile_id: [] for tile_id in ids}
    for location in _load("locations.json")["locations"]:
        for tile_id in _mentions(location.get("layout", {}), ids):
            used[tile_id].append(location["name"])
    for tile_id in _mentions(_load("hub.json"), ids):
        used[tile_id].append("Хаб")
    return used


def _cells(tile: dict) -> str:
    col, row = tile["atlas"]
    if tile.get("block"):
        return "(%d…%d, %d…%d)" % (col, col + 31, row, row + 1)
    span = max(tile.get("variants", 1), tile.get("frames", 1))
    return "(%d, %d)" % (col, row) if span == 1 else "(%d…%d, %d)" % (col, col + span - 1, row)


def _shape(tile: dict) -> str:
    if tile.get("block"):
        return "блок: 16 вариантов по 2×2 ячейки"
    if tile.get("frames", 1) > 1:
        return "анимация из %d кадров" % tile["frames"]
    if tile.get("variants", 1) > 1:
        return "%d вариантов" % tile["variants"] if tile["variants"] >= 5 else "%d варианта" % tile["variants"]
    return "—"


def table(data: dict) -> str:
    ids = {tile["id"] for tile in data["tiles"]}
    used = _usage(ids)
    rows = ["| tile_id | Название | Ячейки атласа | collision | Слой | Варианты / анимация | Где | Рисунок (`art`) |",
            "|---|---|---|---|---|---|---|---|"]
    for tile in data["tiles"]:
        where = ", ".join(sorted(set(used[tile["id"]]))) or ("все локации" if tile["id"] == "shadow" else "—")
        rows.append("| `%s` | %s | %s | %s | %s | %s | %s | %s |" % (
            tile["id"], tile["name"], _cells(tile), tile["collision"], LAYERS.get(tile["layer"], tile["layer"]),
            _shape(tile), where, tile["art"]))
    return "\n".join(rows)


def render() -> str:
    data = _load("tiles.json")
    size = data["tile_size"]
    cols, rows = data["atlas_columns"], data["atlas_rows"]
    return HEADER.format(size=size, cols=cols, rows=rows, width=cols * size, height=rows * size, up=data["block_up"],
                         side=data["block_side"], frame_ms=int(data["frame_sec"] * 1000)) + table(data) + "\n" + FOOTER


HEADER = """# TILE_SPEC — тайлы Neon Requiem

Спецификация тайлов. Источник правды — `data/tiles.json`; этот файл собирает
`tools/art/tile_spec.py`. Атлас рисуется кодом (`tools/art/tiles.py`, без нейросетей) в
`assets/tiles/neon_atlas.png`; TileSet и сцены локаций собирает `tools/build_world.gd`.

## Сетка и формат

| Параметр | Значение |
|---|---|
| Тайл | {size}×{size} px, в игре слои масштабированы ×4 (`art.pixel_scale`): на экране 64×64 |
| Атлас | сетка {cols} × {rows} ячеек (столбцы × строки) = {width}×{height} px, один источник `source_id = 0` |
| Координаты | `atlas` = (столбец, строка) первой ячейки тайла |
| Варианты | `variants` — сколько ячеек вправо занимают варианты рисунка; сборщик выбирает вариант случайно по `variant_weights` |
| Анимация | `frames` — кадры анимации вправо от первой ячейки, {frame_ms} мс на кадр (TileSet animation) |
| Блок стены | `block: true` — 16 вариантов по открытым соседям (маска: юг 1, восток 2, север 4, запад 8), каждый занимает 2×2 ячейки; вариант с маской m стоит в столбце `atlas.x + 2m` |
| Перспектива блока | камера чуть сверху и справа: крыша поднята на {up} px (`block_up`), видны передняя грань и правая грань шириной {side} px (`block_side`); грань рисуется только со стороны открытого пола |
| Тени | `shadow` — 7 масок по стенам рядом с клеткой пола (восток 1, север 2, северо-восток 4; столбец `atlas.x + маска − 1`): тень стены падает на пол влево-вниз |
| TileSet | `scenes/Locations/tiles/neon_tileset.tres` |
| Физика | physics layer 0 → слой коллизий 6 `wall` (bit 32); у блока полигон на клетку основания — центр 2×2-тайла, совпадает с клеткой карты; крыша и грани выступают за неё |
| Custom data | `collision` (String: `none` / `solid` / `hazard`), `tile_id` (String) |
| Фильтр | nearest (пиксель-арт), без mipmap |
| Свечение | слои рисуются общим материалом `SpriteFx`: неоновые пиксели (ярче 0,84) усиливаются ×1,5 и светятся; modulate слоя должен оставаться не выше 1 |

## Слои локации

Каждая сцена `scenes/Locations/*.tscn` собрана из четырёх TileMapLayer (все с масштабом ×4):

| Слой | Узел | z_index | Что лежит | Коллизия |
|---|---|---|---|---|
| floor | `Floor` | −10 | пол и опасные тайлы (`hazard`) | нет; `hazard` наносит урон раз в `hazard.tick_sec` |
| shadow | `Shadows` | −9 | тени блоков на полу | нет |
| decor | `Decor` | −8 | вывески, кабели, растения, руны, фонари | нет |
| wall | `Walls` | 0, сортировка по y | блоки стен, граница арены | `solid` — слой физики 6 (`wall`) |

Плюс `Markers`: `PlayerSpawn`, `BossSpawn`, `Powerups/Spot0..N` (места временных усилений).
Корень локации сортирует по y, поэтому герой и враги заходят за блоки и выходят перед ними.
За краем карты рисуется фон `scenes/fx/Backdrop.gd` (ночной город, параллакс 0,35).

## Тайлы

"""

FOOTER = """
## Как поменять графику

1. Поправить рисунок в `tools/art/tiles.py` (или заменить `assets/tiles/neon_atlas.png` своим
   PNG с той же сеткой и расположением ячеек).
2. Пересобрать: `GODOT=<путь к Godot> tools/art/rebuild.sh tiles` — рисует атлас, обновляет этот
   файл, импортирует атлас и заново собирает TileSet и пять локаций.

## Пересборка локаций

`tools/build_world.gd` (сцена `tools/BuildWorld.tscn`) по блокам `layout` из `data/locations.json`
собирает TileSet и пять сцен локаций. Размеры планировки — в тайлах (на экране 64 px). Стили: `alleys`
(трущобы), `racks` (ядро данных), `garden` (сады), `rail` (магистраль с путями), `arena` (шпиль).
Для каждой стены сборщик выбирает вариант блока по открытым соседям и кладёт тени на пол.
После пересборки сцены можно править вручную в редакторе: рисовать тайлы, двигать маркеры.
"""


def main() -> None:
    (ROOT / "TILE_SPEC.md").write_text(render(), encoding="utf-8")


if __name__ == "__main__":
    main()
