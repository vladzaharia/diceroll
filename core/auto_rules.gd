class_name AutoRules
extends RefCounted
## Player-configurable AUTO policy (spec §15 "Speed and AUTO"). Bot.decide(flow, rules) reads it.
## Persist with to_dict()/from_dict() (plain JSON-safe values).
##
## Scope toggles: when a phase's scope is off, decide() hands control back (stop:true).
## Shop: with `shop` on AUTO buys; with it off the shop hands control back when `stop_on_shop`
## is set, otherwise AUTO just leaves the shop.
## Stop conditions: `stop_hp_below` (0 = never; e.g. 0.3) is checked on the board and in combat;
## `stop_before_miniboss` / `stop_before_boss` stop before a move (or portal jump) that would
## start that fight; `stop_on_boss_passive` stops when a boss-tier passive choice is offered.
## `focus` steers draft/shop/passive/rune scoring and how much HP is worth.
## `fight_miniboss`: "auto" (fight when it looks winnable), "always", "never" (avoid the tile).

const FOCUSES := ["balanced", "damage", "defense", "economy"]
## "realistic": the smart policy with bounded rationality (noisy near-best choices, shallower
## combat search, occasional gut-feel keeps and simpler draft/shop taste), the balance
## reference and the default. "expert": the full smart policy.
const SKILLS := ["realistic", "expert"]
const MINIBOSS_MODES := ["auto", "always", "never"]

# scope
var board: bool = true
var combat: bool = true
var drafts: bool = true
var shop: bool = false
var forge: bool = true
var events: bool = true
var portal: bool = true
# stop conditions
var stop_hp_below: float = 0.0
var stop_before_miniboss: bool = false
var stop_before_boss: bool = true
var stop_on_boss_passive: bool = true
var stop_on_shop: bool = true
# priorities
var focus: String = "balanced"
var fight_miniboss: String = "auto"
var skill: String = "realistic"

const _BOOLS := ["board", "combat", "drafts", "shop", "forge", "events", "portal",
	"stop_before_miniboss", "stop_before_boss", "stop_on_boss_passive", "stop_on_shop"]

## Every scope on and no stop conditions: AUTO plays the whole run (balance sim).
static func all_on(p_focus := "balanced", p_skill := "realistic") -> AutoRules:
	var r := AutoRules.new()
	r.shop = true
	r.stop_before_boss = false
	r.stop_on_boss_passive = false
	r.stop_on_shop = false
	r.focus = p_focus if FOCUSES.has(p_focus) else "balanced"
	r.skill = p_skill if SKILLS.has(p_skill) else "realistic"
	return r

func to_dict() -> Dictionary:
	var d := {}
	for k in _BOOLS:
		d[k] = bool(get(k))
	d["stop_hp_below"] = stop_hp_below
	d["focus"] = focus
	d["fight_miniboss"] = fight_miniboss
	d["skill"] = skill
	return d

## Missing keys keep their defaults; invalid values fall back to them.
static func from_dict(d: Dictionary) -> AutoRules:
	var r := AutoRules.new()
	if d == null:
		return r
	for k in _BOOLS:
		if d.has(k):
			r.set(k, bool(d[k]))
	if d.has("stop_hp_below"):
		r.stop_hp_below = clampf(float(d.stop_hp_below), 0.0, 1.0)
	var f := String(d.get("focus", "balanced"))
	r.focus = f if FOCUSES.has(f) else "balanced"
	var m := String(d.get("fight_miniboss", "auto"))
	r.fight_miniboss = m if MINIBOSS_MODES.has(m) else "auto"
	var sk := String(d.get("skill", "realistic"))
	r.skill = sk if SKILLS.has(sk) else "realistic"
	return r
