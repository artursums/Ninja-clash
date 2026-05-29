class_name BotTuning
extends Resource
## Data-driven tuning for the AI fighter (see player.gd `_bot_think`). Extracted from the
## hardcoded per-tier arrays so bot balance is editable in the inspector and injectable in
## tests — mirrors the PlayerTuning pattern.
##
## Each knob is a 3-element array indexed by difficulty: [GENIN, CHUNIN, JONIN]
## (bot_difficulty 1/2/3 → index 0/1/2). Defaults below are the VALIDATED prototype numbers;
## the two historical scalar multipliers (near/far ×1.15, rush/melee-commit ×0.85) are folded
## into the defaults, so behaviour is unchanged. Edit bot_tuning.tres to re-balance the bot
## without touching code.

# --- Survival / defence ---
@export var dodge_chance: Array[float] = [0.45, 0.63, 0.80]      ## chance to read an incoming shuriken
@export var dodge_range: Array[float] = [82.0, 98.0, 116.0]      ## how far out it reacts (timed to catch)
@export var deflect_chance: Array[float] = [0.40, 0.55, 0.70]    ## parry an incoming shuriken with the blade
@export var guard_chance: Array[float] = [0.55, 0.72, 0.88]      ## blocks when dodge is on cooldown under fire
@export var reaction_s: Array[float] = [0.24, 0.17, 0.11]        ## lag before answering a NEW threat (point-blank beats it)

# --- Ranged / aggression ---
@export var throw_cd: Array[float] = [0.75, 0.52, 0.34]          ## min gap between throws
@export var near_range: Array[float] = [80.5, 71.3, 62.1]        ## back off sooner (= raw 70/62/54 ×1.15)
@export var far_range: Array[float] = [253.0, 224.25, 197.8]     ## only close when foe is further out (= 220/195/172 ×1.15)
@export var rush_chance: Array[float] = [0.0034, 0.00595, 0.00935] ## per-frame pressure-rush chance (= raw ×0.85)
@export var pickup_range: Array[float] = [120.0, 150.0, 180.0]   ## how far it detours to grab a loose blade (stash<5)

# --- Melee duel ---
@export var melee_commit_chance: Array[float] = [0.0051, 0.00765, 0.01105] ## per-frame chance to start a duel (= raw ×0.85)
@export var melee_windup: Array[float] = [0.50, 0.42, 0.34]      ## pause before a strike (the "stare-down")
@export var melee_recovery: Array[float] = [1.10, 0.90, 0.72]    ## rest after a strike — no spamming

# --- Movement / positioning ---
@export var jump_react_h: Array[float] = [72.0, 58.0, 46.0]      ## eagerness to chase a higher foe
@export var hop_chance: Array[float] = [0.010, 0.014, 0.020]     ## per-frame idle-hop chance
@export var dash_close_chance: Array[float] = [0.020, 0.032, 0.048] ## burst-dash to close a big gap
@export var dash_air_chance: Array[float] = [0.030, 0.050, 0.080] ## air-dash mid-jump toward the foe
@export var high_ground_chance: Array[float] = [0.006, 0.011, 0.018] ## per-frame chance to commit to a high-ground push
