class_name MatchContext
extends Resource
## The canonical per-match data bundle. Created by the Game State Manager on entry to
## MatchSetup, filled by MatchSetup (clans, map, target score), read by Round Flow during
## InMatch and by the MatchEnd UI, then discarded when the GSM returns to MainMenu.
## See design/gdd/game-state-manager.md — Core Rule 3 + the MatchContext lifecycle criteria.

## Slot (1..4) → chosen clan id. Filled during MatchSetup.
@export var clan_by_slot: Dictionary = {}

## The map chosen for this match (StringName id; resolved by the Map system).
@export var map_id: StringName = &""

## First-to-N: the round count a slot must reach to win the match.
@export var target_score: int = 5

## Slot (1..4) → rounds won so far. Written by Round Flow each round.
@export var score_by_slot: Dictionary = {}

## Slots (1..4) participating in this match. Filled during MatchSetup.
@export var active_slots: Array[int] = []
