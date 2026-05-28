extends Node
## Pre-match "Fight Setup / Variants" ruleset (TowerFall-style), GLOBAL for the match (one ruleset
## for every fighter). Registered as the `MatchConfig` autoload: loads on boot, applies target_score
## into GameState, persists each change. Defaults are captured from PlayerTuning + GameState so an
## untouched config plays EXACTLY like the standard game. Pure load/save/clamp is unit-tested;
## capture_defaults() reads the tuning resource and apply() pushes target_score into GameState.
##
## Own file (NOT settings.cfg): SettingsStore.save_to() rewrites a fresh ConfigFile with only its
## section, which would erase a shared [match_config] on every settings change (and vice-versa).
## A separate file sidesteps that cross-writer clobber with no change to SettingsStore.

const DEFAULT_PATH := "user://match_config.cfg"
const SECTION := "match_config"
const TUNING_PATH := "res://player_tuning.tres"

# Clamp caps for the steppers (UI + load both clamp to these).
const MAX_KATANA_CHARGES := 9
const STASH_CAP := 5            # the catch cap in player.gd — start count can't exceed it
const MAX_HP_CAP := 9
const MIN_TARGET_SCORE := 1
const MAX_TARGET_SCORE := 15

# --- Variant state (every value defaults to today's standard behaviour) ---
var katana_enabled: bool = true       # OFF = no katana at all (0 charges, swing no-ops, no HUD marks)
var katana_recharge: bool = true      # true = PER-ROUND refill on respawn (default); false = NEVER (finite for the match)
var katana_charges: int = 3           # charges granted (per round, or once at match start when recharge is off)
var shurikens_enabled: bool = true    # OFF = spawn with 0, cannot throw
var start_shurikens: int = 3          # shurikens held at spawn (0..STASH_CAP)
var infinite_shurikens: bool = false  # throws never deplete the stash
var max_hp: int = 5                   # hits to kill
var target_score: int = 5             # rounds to win the match

# --- Captured factory defaults (data-driven; restored by reset_to_defaults) ---
var _def_katana_charges: int = 3
var _def_start_shurikens: int = 3
var _def_max_hp: int = 5
var _def_target_score: int = 5


func _ready() -> void:
	capture_defaults()
	load_from(DEFAULT_PATH)
	apply()


# Read the data-driven defaults from PlayerTuning (+ GameState for target_score) and seed the
# current values to match. Safe to call outside the scene tree (tests): missing tuning/GameState
# fall back to the literal field defaults. Called in _ready and re-used by reset_to_defaults.
func capture_defaults() -> void:
	if ResourceLoader.exists(TUNING_PATH):
		var tuning: Resource = load(TUNING_PATH)
		if tuning != null:
			_def_max_hp = int(tuning.max_hp)
			_def_katana_charges = int(tuning.max_katana)
			_def_start_shurikens = int(tuning.start_shurikens)
	if is_inside_tree():
		var gs: Node = get_node_or_null("/root/GameState")
		if gs != null:
			_def_target_score = int(gs.target_score)
	max_hp = _def_max_hp
	katana_charges = _def_katana_charges
	start_shurikens = _def_start_shurikens
	target_score = _def_target_score


# --- Effective loadout helpers (read by player.gd at respawn) ---

func effective_start_shurikens() -> int:
	return start_shurikens if shurikens_enabled else 0


func effective_katana_charges() -> int:
	return katana_charges if katana_enabled else 0


# --- Mutators (clamp + persist; numeric target_score also applies into GameState) ---

func set_katana_enabled(on: bool) -> void:
	katana_enabled = on
	save_to(DEFAULT_PATH)


func set_katana_recharge(on: bool) -> void:
	katana_recharge = on
	save_to(DEFAULT_PATH)


func set_katana_charges(n: int) -> void:
	katana_charges = clampi(n, 0, MAX_KATANA_CHARGES)
	save_to(DEFAULT_PATH)


func set_shurikens_enabled(on: bool) -> void:
	shurikens_enabled = on
	save_to(DEFAULT_PATH)


func set_start_shurikens(n: int) -> void:
	start_shurikens = clampi(n, 0, STASH_CAP)
	save_to(DEFAULT_PATH)


func set_infinite_shurikens(on: bool) -> void:
	infinite_shurikens = on
	save_to(DEFAULT_PATH)


func set_max_hp(n: int) -> void:
	max_hp = clampi(n, 1, MAX_HP_CAP)
	save_to(DEFAULT_PATH)


func set_target_score(n: int) -> void:
	target_score = clampi(n, MIN_TARGET_SCORE, MAX_TARGET_SCORE)
	apply()
	save_to(DEFAULT_PATH)


func reset_to_defaults() -> void:
	katana_enabled = true
	katana_recharge = true
	shurikens_enabled = true
	infinite_shurikens = false
	capture_defaults()   # restores numeric values to the data-driven defaults
	apply()
	save_to(DEFAULT_PATH)


# --- Persistence (pure I/O — unit-tested with a temp path) ---

func load_from(path: String) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return   # no file yet → keep the captured defaults
	katana_enabled = bool(cfg.get_value(SECTION, "katana_enabled", katana_enabled))
	katana_recharge = bool(cfg.get_value(SECTION, "katana_recharge", katana_recharge))
	katana_charges = clampi(int(cfg.get_value(SECTION, "katana_charges", katana_charges)), 0, MAX_KATANA_CHARGES)
	shurikens_enabled = bool(cfg.get_value(SECTION, "shurikens_enabled", shurikens_enabled))
	start_shurikens = clampi(int(cfg.get_value(SECTION, "start_shurikens", start_shurikens)), 0, STASH_CAP)
	infinite_shurikens = bool(cfg.get_value(SECTION, "infinite_shurikens", infinite_shurikens))
	max_hp = clampi(int(cfg.get_value(SECTION, "max_hp", max_hp)), 1, MAX_HP_CAP)
	target_score = clampi(int(cfg.get_value(SECTION, "target_score", target_score)), MIN_TARGET_SCORE, MAX_TARGET_SCORE)


func save_to(path: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "katana_enabled", katana_enabled)
	cfg.set_value(SECTION, "katana_recharge", katana_recharge)
	cfg.set_value(SECTION, "katana_charges", katana_charges)
	cfg.set_value(SECTION, "shurikens_enabled", shurikens_enabled)
	cfg.set_value(SECTION, "start_shurikens", start_shurikens)
	cfg.set_value(SECTION, "infinite_shurikens", infinite_shurikens)
	cfg.set_value(SECTION, "max_hp", max_hp)
	cfg.set_value(SECTION, "target_score", target_score)
	cfg.save(path)


# --- Apply (side effect: rounds-to-win lives on GameState, which drives match end) ---

func apply() -> void:
	if not is_inside_tree():
		return
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		gs.target_score = target_score
