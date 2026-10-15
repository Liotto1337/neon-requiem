extends Node
## Global event bus. Every game-wide signal is declared here and nowhere else.
## State owners (GameState, MetaState) emit after mutations; UI listens and sends intents back.

# Lifecycle
signal run_started(summary: Dictionary)
signal run_ended(summary: Dictionary)
signal game_saved(kind: String)
signal draft_completed

# Run state (GameState emits each once per logical change, after the mutation)
signal resources_changed(resources: Dictionary)
signal abilities_changed(abilities: Array)
signal items_changed(passives: Array, actives: Array)
signal recipes_changed(recipes: Array)
signal stats_changed(stats: Dictionary)
signal slot_limits_changed(limits: Dictionary)
signal difficulty_changed(tier: int, multiplier: float, loop_count: int)
signal timer_changed(elapsed_sec: float, location_elapsed_sec: float)
signal location_changed(location_id: String, index: int, count: int)
signal buffs_changed(buffs: Array)
signal antiheal_changed(active: bool)
signal player_damaged(amount: float, source: String)
signal player_died(summary: Dictionary)
signal run_draft_ready(hero_id: String, item_ids: Array)
signal level_up_ready(level: int, options: Array)
signal item_gained(item_id: String, source: String)
signal enemy_killed(enemy_id: String, position: Vector2, elite_mods: Array)
signal boss_spawned(boss_id: String, boss_name: String, hp_max: float, kind: String)
signal boss_health_changed(hp: float, hp_max: float, phase: int)
signal boss_defeated(boss_id: String, kind: String, is_final: bool)
signal victory_reached(summary: Dictionary)
signal loop_started(loop_count: int, multiplier: float)

# Combat feedback (AbilitySystem / ItemSystem / player components)
signal ability_cooldown_started(slot: int, duration_sec: float)
signal item_cooldown_started(slot: int, duration_sec: float)
signal cast_failed(kind: String, slot: int, reason: String)
signal ammo_changed(current: int, magazine: int, reloading: bool)
signal class_action_changed(label: String, ready_in_sec: float)

# World requests (entities ask, RunSpawner spawns; Node refs never travel on this bus)
signal projectile_requested(spec: Dictionary)
signal pickup_requested(kind: String, position: Vector2, value: float, extra: Dictionary)
signal drone_requested(spec: Dictionary)
signal drones_recall_requested(haste_sec: float, haste_mult: float)
signal drones_command(command: String, data: Dictionary)
signal adds_requested(enemy_id: String, count: int, position: Vector2, spread_px: float)
signal magnet_requested
signal beam_fx_requested(points: PackedVector2Array, color: Color, width: float, duration_sec: float)
signal ring_fx_requested(position: Vector2, radius: float, color: Color, duration_sec: float)
signal damage_number_requested(position: Vector2, amount: float, crit: bool, color: Color)
signal screen_shake_requested(strength: float, duration_sec: float)

# UI intents (run)
signal modal_visibility_changed(modal_id: String, visible: bool)
signal pause_menu_requested(open: bool)
signal inventory_toggle_requested(open: bool)
signal hero_draft_chosen(item_ids: Array)
signal levelup_option_chosen(index: int)
signal craft_requested(recipe_id: String)
signal loop_choice_made(choice: String)
signal game_over_confirmed
signal return_to_hub_requested
signal toast_requested(text: String)

# Meta / hub
signal meta_changed(meta: Dictionary)
signal hero_selected(hero_id: String)
signal hero_unlock_requested(hero_id: String)
signal meta_node_purchase_requested(node_id: String)
signal starting_item_upgrade_requested(hero_id: String)
signal run_start_requested(hero_id: String)
signal run_continue_requested

# Audio
signal mute_toggle_requested(bus_name: String)
signal audio_mute_changed(bus_name: String, muted: bool)

# Monetization
signal purchase_requested(sku: String)
signal purchase_completed(sku: String)
signal purchase_failed(sku: String, reason: String)
signal ad_rewarded_requested(placement: String)
signal ad_rewarded_completed(placement: String)
signal ad_interstitial_closed
signal ad_failed(kind: String, reason: String)
