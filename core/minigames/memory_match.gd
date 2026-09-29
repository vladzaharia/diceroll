class_name MemoryMatch
extends Minigame
## Memory Match: a 4x4 grid of face-down cards, two of each of 8 symbols (die faces 1..6, the
## Star rune 7 and the Skull rune 8), shuffled by the minigame Rng. Flip two cards per turn
## (action args [idx], 0 .. 15, one flip per action): a pair stays face up and scores
## PAIR_POINTS (+STREAK_BONUS for each pair in a row after the first); a mismatch flips both
## back and costs one of MISSES misses. The game ends when every pair is found (each miss left
## then scores MISS_LEFT_POINTS) or the misses run out.
## Hidden: every face-down card. The public state shows only the found pairs and the one card
## turned over in the current turn; a flipped-back card's face is only in that flip's info, so
## remembering it is the player's job (the game is the memory).
## actions_left = misses left (the MISSES pill).
## Public: {w, h, cards [0 face down | symbol], open (idx of the first card of the turn or -1),
##          open_symbol, pairs, streak, misses}.
## Info per flip: {idx, symbol, first (true: first card of a turn), other, other_symbol,
##          match, points}.

const W := 4
const H := 4
const SYMBOLS := 8
const MISSES := 6
const PAIR_POINTS := 2
const STREAK_BONUS := 0
const MISS_LEFT_POINTS := 1

var symbols: Array[int] = []
var found: Array[int] = []
var open := -1
var pairs := 0
var streak := 0
var bonus := 0

func _init() -> void:
	id = "memory_match"

func _setup() -> void:
	actions_left = MISSES
	var deck: Array = []
	for s in SYMBOLS:
		deck.append(s + 1)
		deck.append(s + 1)
	rng.shuffle(deck)
	symbols.clear()
	for v in deck:
		symbols.append(int(v))
	found.resize(W * H)
	found.fill(0)
	open = -1
	pairs = 0
	streak = 0
	bonus = 0

func _action(args: Array) -> Dictionary:
	if args.is_empty():
		return {"error": "flip needs [idx]"}
	var i := int(args[0])
	if i < 0 or i >= W * H:
		return {"error": "card out of range"}
	if found[i] == 1:
		return {"error": "already matched"}
	if i == open:
		return {"error": "already face up"}
	if open < 0:
		open = i
		return {"info": {"idx": i, "symbol": symbols[i], "first": true, "other": -1, "other_symbol": 0, "match": false, "points": 0}}
	var other := open
	open = -1
	var same := symbols[i] == symbols[other]
	var pts := 0
	if same:
		found[i] = 1
		found[other] = 1
		pairs += 1
		pts = PAIR_POINTS + (STREAK_BONUS * streak)
		bonus += STREAK_BONUS * streak
		streak += 1
		if pairs == SYMBOLS:
			pts += MISS_LEFT_POINTS * actions_left
			done = true
	else:
		streak = 0
		actions_left -= 1
	return {"info": {"idx": i, "symbol": symbols[i], "first": false, "other": other, "other_symbol": symbols[other], "match": same,
		"points": pts}}

func score() -> float:
	var s := PAIR_POINTS * pairs + bonus
	if pairs == SYMBOLS:
		s += MISS_LEFT_POINTS * actions_left
	return float(s)

func _public() -> Dictionary:
	var view: Array = []
	for i in W * H:
		view.append(symbols[i] if found[i] == 1 else 0)
	return {"w": W, "h": H, "cards": view, "open": open, "open_symbol": symbols[open] if open >= 0 else 0, "pairs": pairs,
		"streak": streak, "misses": MISSES}

func _save() -> Dictionary:
	return {"symbols": Array(symbols), "found": Array(found), "open": open, "pairs": pairs, "streak": streak, "bonus": bonus}

func _load(d: Dictionary) -> void:
	symbols = Minigame.ints(d.get("symbols", []))
	found = Minigame.ints(d.get("found", []))
	open = int(d.get("open", -1))
	pairs = int(d.get("pairs", 0))
	streak = int(d.get("streak", 0))
	bonus = int(d.get("bonus", 0))
