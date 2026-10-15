# Neon Requiem

Neonpunk bullet hell / action roguelike for Yandex Games (Web) and Windows. Godot 4.7, GDScript,
desktop 1920x1080 (`canvas_items` stretch), Russian UI. A run lasts ~20 minutes through five
locations, each with a miniboss (T+2 min) and a boss (T+5 min). The final boss opens a choice:
bank the run currency in the hub, or loop with every item kept and difficulty x1.5.
Every number lives in `data/*.json`; saves are `user://meta_save.json` and `user://run_save.json`.
All art is procedural (Polygon2D / Line2D / generated tile atlas), so no PNG is needed to run.

## Structure

- `autoload/`
  - `Signals` is the event bus: every signal in the game is declared there.
  - `GameState` owns the run state (resources, abilities, items, buffs, difficulty, location chain) and the single seeded `RandomNumberGenerator`; it emits after mutations, batched per domain.
  - `MetaState` owns persistent progression (bank, heroes, skill tree, signature item tiers, stats).
  - `SaveManager` does save I/O with versions and migrations; `TimeService` gives unix time and the pausable run clock.
  - `SpawnDirector`, `WaveDirector` and `DamageCalc` are PURE: inputs in, results out, no node or GameState references.
  - `ItemSystem`, `AbilitySystem` and `LootRoller` hold the item / ability / loot rules.
  - `InputMapHelper` handles rebindable actions; `AudioBus`, `IAP` and `AdManager` are stubs.
- `core/` holds static helpers: `Db` (JSON tables), `Fmt` (text), `Neon` (procedural neon shapes).
- `scenes/`
  - `Hub.tscn` and `Run.tscn` are the two top-level scenes (scripts in `scenes/scripts/`, plus `RunSpawner`).
  - `entities/`: `Player`, `Enemy`, `EliteEnemy` (inherits `Enemy` + `EliteModifier` component), `Boss`, `Projectile`, `Pickup`, `Drone`. Components: `PlayerAttack`, `AbilityCaster`, `ShotFactory`, `EliteModifier`.
  - `ui/`: `HUD`, `LevelUpModal`, `InventoryOverlay`, `PauseMenu`, `GameOverModal`, `LoopChoiceModal`, `HeroDraftModal`. Components: `AbilitySlot`, `ItemCard`, `StatRow`, `ModalBase`.
  - `fx/`: `EliteOutline.gdshader` (one outline shader for every enemy, coloured by elite modifiers), `DamageNumber`, `ScreenShake`.
  - `Locations/`: five TileMapLayer scenes (`NeonSlums`, `DataCore`, `ChromeGardens`, `AshenRail`, `RequiemSpire`) with `LocationBase.gd` and per-location flavour scripts. `tiles/` holds the generated atlas and TileSet.
- `data/`: config, heroes, abilities, items (with recipes), enemies, elites, bosses, locations, meta_tree, difficulty, iap, tiles.
- `tools/`: world builder, lint, strict compile check, smoke and soak tests.
- `TILE_SPEC.md` is the tile art spec (ids, atlas coords, collision, layers).
- `obsidian/` is the project map for Obsidian.

## Conventions

- Typed GDScript everywhere; functions are at most 40 lines; `push_error()` for errors, never `print()`.
- No cross-scene node refs: entities ask for spawns through `Signals`, the Run calls `setup()` downwards, UI reads state only from signals.
- Timers use `TimeService.run_msec()` (`Time.get_ticks_msec()` minus paused time); saves use unix time.
- Physics layers: 1 player, 2 enemy, 3 player_projectile, 4 enemy_projectile, 5 pickup, 6 wall.
- `tools/lint.py` checks these rules; `tools/check.sh` runs lint + strict compile + smoke test.

## Controls

WASD moves, the mouse aims, LMB attacks, RMB fires the empowered attack. R reloads (Vector), parries (Katar) or recalls drones (Chorus). Z X C V cast abilities (B appears after the "Limit Break: abilities" item), 1–6 use active items (7 after "Limit Break: gear"). ESC pauses, TAB opens inventory and crafting. Debug builds only: F10 skips 60 s of run time, F9 grants XP and credits.

## First run

1. Open the folder in Godot 4.7 and let the first import finish.
2. Press F5. The hub opens with 200 credits and Vector unlocked. Pick a hero and press "Начать забег", then pick 2 of the 3 starting items.
3. To start over, delete `user://meta_save.json` and `user://run_save.json` (Project → Open User Data Folder).

## Export

- **Web (Yandex Games):** add the *Web* preset with the GL Compatibility renderer (already set) and Thread Support off. Add `data/*.json` to *Filters to export non-resource files*. Export `index.html` and zip the build folder with `index.html` at the root. The window is not fullscreen on Web (`window/size/mode.web=0`). Replace the `_platform_*` stubs in `IAP.gd` / `AdManager.gd` with the Yandex SDK bridge to go live.
- **Windows:** add the *Windows Desktop* preset with the same `data/*.json` filter. The game starts fullscreen 1920x1080.

## Verification

```bash
GODOT=/path/to/Godot_v4.7 tools/check.sh            # lint, strict compile, smoke test (68 checks)
GODOT=/path/to/Godot_v4.7 SOAK=1 tools/check.sh     # + 3-minute soak: 3 heroes x 5 locations
godot --headless --path . res://tools/BuildWorld.tscn   # rebuild tile atlas, TileSet and locations
```

The smoke test covers the acceptance list: hub → run → draft, WASD / LMB / RMB / R / Z X C / 1–6 through the real input map, level-up draft and level-5 ultimate, elite outlines (single / dual / rainbow), shield and antiheal, tier +1 per 60 s with scaling, miniboss at 2:00 and boss at 5:00, seamless transition, final boss → loop (x1.5, items kept, tier cap +20%), death → hub with meta bank and skill-tree purchase, and the purity of the PURE modules.

## MVP decisions

- Defeat loses the run credits (`meta.defeat_keep_fraction` = 0); a new profile starts with 200 hub credits so the skill tree can be tried right away.
- Each hero has 3 fixed starting abilities (Z X C); V is filled from level-ups. The start draft keeps 2 of the hero's 3 starting items, one of them the signature item that the hub can upgrade to tier 5.
- A loop multiplies difficulty by 1.5 and sets the tier cap to the current tier + 20%; the first pass caps the tier at 20 (20 minutes).
- Limit Break adds a 5th ability slot (key B) or a 7th item slot (key 7), once per run.
- Movement actions are `move_wasd_up/down/left/right` (physical keys, so the Russian keyboard layout works).
