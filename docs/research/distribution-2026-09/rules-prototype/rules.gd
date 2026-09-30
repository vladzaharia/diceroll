class_name Rules
extends RefCounted
## Prototype "rules as data" evaluator (scratch experiment, not repo code).
## JSON (res://core/rules/rules_base.json) -> compiled node objects at load (one class per
## operator: no string dispatch at run time); per-run dispatch table {hook: [Inst sorted by
## prio]}; closed condition / value / effect vocabulary; bounded depth; no loops except
## bounded iteration over the dice pool / enemies; no recursion in data.
##
## A rule: {on, prio, if, do:[effects], announce:{effect, value, count, extra}, limit:{per, max,
## key}, chance, stop, repeat, variant}. Owners: passive, item (+variant), rune, asc.
## An effect with "skip_zero": true cancels the rule when its value is 0 (no announce, no use).

const MAX_DEPTH := 8
const _EMPTY := {}
const _EMPTY_A := []

# ------------------------------------------------------------------ value / condition nodes

class N:
	func ev(_x: Ctx) -> Variant:
		return null

class Const extends N:
	var v: Variant
	func ev(_x: Ctx) -> Variant:
		return v

## Payload variable: Ctx.vars first, then the few computed ones (VarComputed).
class VarP extends N:
	var name: String
	func ev(x: Ctx) -> Variant:
		return x.vars.get(name)

class VarComputed extends N:
	var id := 0
	var name := ""
	func ev(x: Ctx) -> Variant:
		match id:
			0: return x.c.turn
			1: return x.run.gold
			2: return x.value
			3: return x.times
			4: return int((x.vars.eff as Array)[x.die])
			5: return x.run.hp
			6: return x.run.max_hp
			7: return x.run.act
			8: return x.die
			9: return int(x.c.enemies[x.self_idx].phase)
			10: return x.c.alive(x.self_idx)
			11: return int(x.c.enemies[x.self_idx].atk_bonus)
			12: return int(x.run.stats.get("boss_stage", 0))
			13: return x.run.route
			14: return x.run.stats.get("minibosses_killed", Rules._EMPTY_A)
			15: return x.locals.get("was", 0)
		return Rules.native_value(name, x)

const COMPUTED := {"turn": 0, "gold": 1, "value": 2, "times": 3, "die.pips": 4, "hero.hp": 5, "hero.max_hp": 6, "act": 7, "die": 8,
	"self.phase": 9, "self.alive": 10, "self.atk_bonus": 11, "boss_stage": 12, "run.route": 13, "run.minibosses_killed": 14,
	"was": 15}

## Resource value of the owner (a fight-scoped counter; `bind` maps it onto a legacy field).
class ResVal extends N:
	var res: String
	func ev(x: Ctx) -> Variant:
		return Rules.res_get(x, res)
class AscOn extends N:
	var key: String
	func ev(x: Ctx) -> Variant:
		return x.run.has_asc(key)
class Tern extends N:
	var c: N
	var a: N
	var b: N
	func ev(x: Ctx) -> Variant:
		return a.ev(x) if bool(c.ev(x)) else b.ev(x)
class Has extends N:
	var l: N
	var v: N
	func ev(x: Ctx) -> Variant:
		return (l.ev(x) as Array).has(v.ev(x))

class ParamItem extends N:
	var key: String
	func ev(x: Ctx) -> Variant:
		return ItemDefs.num(x.inst.id, key, x.inst.tier, x.inst.variant)

class ParamOwn extends N:
	var key: String
	func ev(x: Ctx) -> Variant:
		return x.inst.params.get(key, 0)

class Sec extends N:
	var key: String
	func ev(x: Ctx) -> Variant:
		return ItemDefs.sec_num(x.inst.variant, key)

class Native extends N:
	var name: String
	func ev(x: Ctx) -> Variant:
		return Rules.native_value(name, x)

class Un extends N:
	var a: N
class AFloor extends Un:
	func ev(x: Ctx) -> Variant:
		return floorf(float(a.ev(x)))
class ARound extends Un:
	func ev(x: Ctx) -> Variant:
		return roundf(float(a.ev(x)))
class ATrunc extends Un:
	func ev(x: Ctx) -> Variant:
		return int(a.ev(x))
class LNot extends Un:
	func ev(x: Ctx) -> Variant:
		return not bool(a.ev(x))

class Bin extends N:
	var a: N
	var b: N
class AAdd extends Bin:
	func ev(x: Ctx) -> Variant:
		return a.ev(x) + b.ev(x)
class ASub extends Bin:
	func ev(x: Ctx) -> Variant:
		return a.ev(x) - b.ev(x)
class AMul extends Bin:
	func ev(x: Ctx) -> Variant:
		return a.ev(x) * b.ev(x)
class ADiv extends Bin:
	func ev(x: Ctx) -> Variant:
		return float(a.ev(x)) / float(b.ev(x))
class AIdiv extends Bin:
	func ev(x: Ctx) -> Variant:
		return int(a.ev(x)) / int(b.ev(x))
class AMin extends Bin:
	func ev(x: Ctx) -> Variant:
		var p: Variant = a.ev(x)
		var q: Variant = b.ev(x)
		return q if q < p else p
class AMax extends Bin:
	func ev(x: Ctx) -> Variant:
		var p: Variant = a.ev(x)
		var q: Variant = b.ev(x)
		return q if q > p else p
class CEq extends Bin:
	func ev(x: Ctx) -> Variant:
		return a.ev(x) == b.ev(x)
class CNe extends Bin:
	func ev(x: Ctx) -> Variant:
		return a.ev(x) != b.ev(x)
class CLt extends Bin:
	func ev(x: Ctx) -> Variant:
		return a.ev(x) < b.ev(x)
class CLte extends Bin:
	func ev(x: Ctx) -> Variant:
		return a.ev(x) <= b.ev(x)
class CGt extends Bin:
	func ev(x: Ctx) -> Variant:
		return a.ev(x) > b.ev(x)
class CGte extends Bin:
	func ev(x: Ctx) -> Variant:
		return a.ev(x) >= b.ev(x)
class CIn extends N:
	var a: N
	var list: Array
	func ev(x: Ctx) -> Variant:
		var v: Variant = a.ev(x)
		for y in list:
			if y == v:
				return true
		return false

class LAll extends N:
	var args: Array[N] = []
	func ev(x: Ctx) -> Variant:
		for n in args:
			if not bool(n.ev(x)):
				return false
		return true
class LAny extends N:
	var args: Array[N] = []
	func ev(x: Ctx) -> Variant:
		for n in args:
			if bool(n.ev(x)):
				return true
		return false

## Bounded count over the combat pool: filter keys in_group, value, rerolled, runed.
class CountDice extends N:
	var in_group := -1   # -1 any, 0 no, 1 yes
	var value := -1
	var rerolled := -1
	var runed := -1
	var shown := -1      # value on the die face (CombatState.dice_values), before Wild substitution
	var base_pool := false
	var rune_not := ""
	func ev(x: Ctx) -> Variant:
		if shown >= 0:
			var m := 0
			for k in x.c.dice_values.size():
				if x.c.dice_values[k] != shown:
					continue
				if base_pool and k >= x.run.dice.size():
					continue
				if rune_not != "" and k < x.run.dice.size() and x.run.dice[k].rune == rune_not:
					continue
				m += 1
			return m
		var eff: Array = x.vars.eff
		var group: Array = x.vars.group if in_group >= 0 else Rules._EMPTY_A
		var n := 0
		for i in eff.size():
			if value >= 0 and int(eff[i]) != value:
				continue
			if in_group >= 0 and group.has(i) != (in_group == 1):
				continue
			if rerolled >= 0 and x.c.rerolled[i] != (rerolled == 1):
				continue
			if runed >= 0 and (((x.vars.pd as Array)[i] as Die).rune != "") != (runed == 1):
				continue
			n += 1
		return n

# ------------------------------------------------------------------ effects

class Effect:
	var v: N
	var to := ""
	var source := ""
	var shape := ""
	var name := ""
	var skip_zero := false
	## Applies the effect; returns false when the rule must not fire (no target, zero value).
	func apply(_x: Ctx, _out: Array[Dictionary]) -> bool:
		return true

class EMultAdd extends Effect:
	func apply(x: Ctx, _out: Array[Dictionary]) -> bool:
		x.acc["mult"] = float(x.acc.mult) + float(v.ev(x))
		return true
class EMultFloor extends Effect:
	func apply(x: Ctx, _out: Array[Dictionary]) -> bool:
		x.acc["mult"] = maxf(float(x.acc.mult), float(v.ev(x)))
		return true
class EFlatAdd extends Effect:
	var slot := "flat"
	func apply(x: Ctx, _out: Array[Dictionary]) -> bool:
		var f := int(v.ev(x))
		if skip_zero and f == 0:
			return false
		x.result = f
		x.acc[slot] = int(x.acc[slot]) + f
		return true
class EFactorMul extends Effect:
	func apply(x: Ctx, _out: Array[Dictionary]) -> bool:
		x.acc["factor"] = float(x.acc.factor) * float(v.ev(x))
		return true
class ESetValue extends Effect:
	func apply(x: Ctx, _out: Array[Dictionary]) -> bool:
		x.value = v.ev(x)
		x.result = x.value
		return true
class ESetTimes extends Effect:
	func apply(x: Ctx, _out: Array[Dictionary]) -> bool:
		x.times = int(v.ev(x))
		return true
class ESetFlag extends Effect:
	func apply(x: Ctx, _out: Array[Dictionary]) -> bool:
		x.vars[name] = true
		return true
class ERerolls extends Effect:
	func apply(x: Ctx, _out: Array[Dictionary]) -> bool:
		x.c.rerolls_left += int(v.ev(x))
		return true
class ESurvive extends Effect:
	func apply(x: Ctx, _out: Array[Dictionary]) -> bool:
		x.run.hp = 1
		x.saved = x.inst.id
		return true
class EHeal extends Effect:
	func apply(x: Ctx, out: Array[Dictionary]) -> bool:
		var h := x.run.heal(int(v.ev(x)))
		x.result = h
		var e := {"type": "hp_changed", "amount": h, "total": x.run.hp, "source": source if source != "" else x.inst.id}
		if shape != "no_max":
			e["max_hp"] = x.run.max_hp
		out.append(e)
		return true
class EGold extends Effect:
	func apply(x: Ctx, out: Array[Dictionary]) -> bool:
		var g := int(v.ev(x))
		if skip_zero and g == 0:
			return false
		x.result = g
		x.run.gold += g
		if g > 0:
			x.run.stats.gold_earned = int(x.run.stats.get("gold_earned", 0)) + g
		out.append({"type": "gold_changed", "amount": g, "total": x.run.gold, "source": source if source != "" else x.inst.id})
		return true
class EBlock extends Effect:
	func apply(x: Ctx, out: Array[Dictionary]) -> bool:
		var bl := int(v.ev(x))
		x.result = bl
		if shape == "item":
			out.append_array(ItemLogic.gain_block(x.run, x.c, bl, x.inst.id, name))
			return true
		x.run.block += bl
		x.run.stats.block_gained = int(x.run.stats.get("block_gained", 0)) + bl
		var be := {"type": "block_gained", "target": "hero", "amount": bl, "total": x.run.block}
		if source != "":
			be["source"] = source
		out.append(be)
		return true
class EDamage extends Effect:
	func apply(x: Ctx, out: Array[Dictionary]) -> bool:
		var amt := int(v.ev(x))
		x.result = amt
		var src := source if source != "" else "item"
		match to:
			"all_enemies":
				for j in x.c.enemies.size():
					if x.c.alive(j):
						out.append_array(x.c.damage_enemy(j, amt, src, x.run))
			"next_other":
				var o := ItemLogic._next_alive(x.c, int(x.vars.target))
				if o < 0:
					return false
				x.tgt = o
				out.append_array(x.c.damage_enemy(o, amt, src, x.run))
			"attacker":
				x.tgt = int(x.vars.attacker)
				out.append_array(x.c.damage_enemy(x.tgt, amt, src, x.run))
		return true
class EFreeze extends Effect:
	func apply(x: Ctx, out: Array[Dictionary]) -> bool:
		var t := int(x.vars.target)
		if not x.c.alive(t):
			return false
		x.tgt = t
		if not bool(x.c.enemies[t].frozen):
			x.run.stats.freezes = int(x.run.stats.get("freezes", 0)) + 1
		x.c.enemies[t].frozen = true
		out.append({"type": "status", "target": t, "status": "frozen", "value": 1, "source": "item"})
		return true

## Resource effects: set / add (with floor and an optional no-change skip) and the resource event
## {type: <res.event>, value, delta, source, <extra...>, max}.
class ERes extends Effect:
	var res := ""
	var mode := ""       # set | add | event
	var floor_v: N = null
	var delta_v: N = null
	var save_as := ""
	var quiet := false
	var extra := {}
	func apply(x: Ctx, out: Array[Dictionary]) -> bool:
		var before := int(Rules.res_get(x, res))
		var now := before
		match mode:
			"set":
				now = int(v.ev(x))
			"add":
				now = before + int(v.ev(x))
				if floor_v != null:
					now = maxi(int(floor_v.ev(x)), now)
				if skip_zero and now == before:
					return false
		if save_as != "":
			x.locals[save_as] = before
		if mode != "event":
			Rules.res_set(x, res, now)
		if quiet:
			return true
		var rd: Dictionary = x.inst.res[res]
		var e := {"type": String(rd.get("event", "resource")), "value": now,
			"delta": int(delta_v.ev(x)) if delta_v != null else now - before, "source": source}
		for k in extra:
			e[k] = (extra[k] as N).ev(x)
		e["max"] = int(Rules.param_of(x, String(rd.get("max_param", "max"))))
		out.append(e)
		return true
class EBossPhase extends Effect:
	func apply(x: Ctx, out: Array[Dictionary]) -> bool:
		out.append_array(x.c._boss_phase2(x.self_idx, x.run, true))
		return true
class ERollIntent extends Effect:
	func apply(x: Ctx, _out: Array[Dictionary]) -> bool:
		x.c.roll_intent(x.run.rng, x.self_idx)
		return true
class ESetIntent extends Effect:
	func apply(x: Ctx, _out: Array[Dictionary]) -> bool:
		x.c.enemies[x.self_idx].intent = {"kind": name, "value": int(v.ev(x))}
		return true
class EIntentEvent extends Effect:
	func apply(x: Ctx, out: Array[Dictionary]) -> bool:
		out.append({"type": "enemy_intent", "enemy_idx": x.self_idx, "intent": (x.c.enemies[x.self_idx].intent as Dictionary).duplicate()})
		return true

const EFFECTS := {"res_set": ERes, "res_add": ERes, "res_event": ERes, "boss_phase": EBossPhase, "roll_intent": ERollIntent,
	"set_intent": ESetIntent, "intent_event": EIntentEvent, "mult_add": EMultAdd, "mult_floor": EMultFloor, "flat_add": EFlatAdd, "bonus_add": EFlatAdd,
	"factor_mul": EFactorMul, "set_value": ESetValue, "set_times": ESetTimes, "set_flag": ESetFlag,
	"rerolls_add": ERerolls, "survive": ESurvive, "heal": EHeal, "gold": EGold, "block": EBlock,
	"damage": EDamage, "freeze": EFreeze}

# ------------------------------------------------------------------ rules, owners, context

class Rule:
	var kind := ""
	var owner := ""
	var variant := ""
	var hook := ""
	var prio := 100
	var cond: N = null
	var effects: Array[Effect] = []
	var ann := false
	var ann_effect := ""
	var ann_value: N = null
	var ann_from := ""       # "" | "result" | "value"
	var ann_count: N = null
	var ann_extra := {}      # key -> N | "$target"
	var lim_per := ""        # "" | fight | run | act
	var lim_max: N = null
	var lim_key := ""
	var chance: N = null
	var stop := false
	var repeat: N = null

## One owner instance a rule runs for (the equipped item's tier and variant, a die's rune...).
class Inst:
	var rule: Rule
	var kind := ""
	var id := ""
	var variant := ""
	var tier := 0
	var params := {}
	var res := {}

class Ctx:
	var run: RunState
	var c: CombatState
	var ev: Array[Dictionary]
	var vars := {}
	var acc := {}
	var inst: Inst
	var die := -1
	var times := 1
	var value: Variant = null
	var result: Variant = null
	var saved := ""
	var tgt := -1
	var self_idx := -1
	var locals := {}
	func _init(p_run: RunState, p_c: CombatState, p_ev: Array[Dictionary]) -> void:
		run = p_run
		c = p_c
		ev = p_ev

# ------------------------------------------------------------------ database and compiler

static var _db := {}          # kind -> {id -> {params, rules, [when, cap, no_double, by_hook]}}
static var _loaded := false
static var n_fire := 0
static var n_rules := 0
static var n_nodes := 0
static var us_fire := 0
static var timing := false
static var compile_us := 0

static func ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var t := Time.get_ticks_usec()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://core/rules/rules_base.json"))
	assert(data is Dictionary, "rules_base.json does not parse")
	for kind in data:
		_db[kind] = {}
		for id in data[kind]:
			var d: Dictionary = data[kind][id]
			var rules: Array = []
			for rd in d.get("rules", []):
				rules.append(_compile_rule(String(kind), String(id), rd))
			var entry := {"params": d.get("params", {}), "rules": rules, "resources": d.get("resources", {})}
			if kind == "enemy":
				var eb := {}
				for r: Rule in rules:
					var ei := Inst.new()
					ei.rule = r
					ei.kind = "enemy"
					ei.id = String(id)
					ei.params = entry.params
					ei.res = entry.resources
					if not eb.has(r.hook):
						eb[r.hook] = []
					(eb[r.hook] as Array).append(ei)
				for h in eb:
					(eb[h] as Array).sort_custom(func(a: Inst, b: Inst) -> bool: return a.rule.prio < b.rule.prio)
				entry["by_hook"] = eb
			if kind == "rune":
				entry["when"] = _val(d.get("when", false), 0, "rune")
				entry["cap"] = int(d.get("cap", 2))
				entry["no_double"] = bool(d.get("no_double", false))
				var by_hook := {}
				for r: Rule in rules:
					var inst := Inst.new()
					inst.rule = r
					inst.kind = "rune"
					inst.id = String(id)
					inst.params = entry.params
					if not by_hook.has(r.hook):
						by_hook[r.hook] = []
					(by_hook[r.hook] as Array).append(inst)
				entry["by_hook"] = by_hook
			_db[kind][id] = entry
	compile_us = Time.get_ticks_usec() - t

static func _compile_rule(kind: String, id: String, rd: Dictionary) -> Rule:
	var r := Rule.new()
	r.kind = kind
	r.owner = id
	r.variant = String(rd.get("variant", ""))
	r.hook = String(rd.on)
	r.prio = int(rd.get("prio", 100))
	if rd.has("if"):
		r.cond = _val(rd["if"], 0, kind)
	for e in rd.get("do", []):
		var op := String(e.op)
		assert(EFFECTS.has(op), "unknown effect op " + op)
		var ef: Effect = EFFECTS[op].new()
		if op == "bonus_add":
			(ef as EFlatAdd).slot = "bonus"
		if e.has("v"):
			ef.v = _val(e.v, 0, kind)
		ef.to = String(e.get("to", ""))
		ef.source = String(e.get("source", ""))
		ef.shape = String(e.get("shape", ""))
		ef.name = String(e.get("name", ""))
		ef.skip_zero = bool(e.get("skip_zero", false))
		if ef is ERes:
			var er: ERes = ef
			er.res = String(e.res)
			er.mode = op.substr(4)
			if e.has("floor"):
				er.floor_v = _val(e.floor, 0, kind)
			if e.has("delta"):
				er.delta_v = _val(e.delta, 0, kind)
			er.save_as = String(e.get("save_as", ""))
			er.quiet = bool(e.get("quiet", false))
			for k in e.get("extra", {}):
				er.extra[k] = _val(e.extra[k], 0, kind)
		r.effects.append(ef)
	if rd.has("announce"):
		var a: Dictionary = rd.announce
		r.ann = true
		r.ann_effect = String(a.get("effect", ""))
		var av: Variant = a.get("value", 0)
		if av is String and String(av).begins_with("$"):
			r.ann_from = String(av).substr(1)
		else:
			r.ann_value = _val(av, 0, kind)
		if a.has("count"):
			r.ann_count = _val(a.count, 0, kind)
		for k in a.get("extra", {}):
			var xv: Variant = a.extra[k]
			r.ann_extra[k] = xv if (xv is String and String(xv).begins_with("$")) else _val(xv, 0, kind)
	if rd.has("limit"):
		r.lim_per = String(rd.limit.per)
		r.lim_max = _val(rd.limit.get("max", 1), 0, kind)
		r.lim_key = String(rd.limit.get("key", kind + ":" + id))
	if rd.has("chance"):
		r.chance = _val(rd.chance, 0, kind)
	r.stop = bool(rd.get("stop", false))
	if rd.has("repeat"):
		r.repeat = _val(rd.repeat, 0, kind)
	n_rules += 1
	return r

const BIN := {"add": AAdd, "sub": ASub, "mul": AMul, "div": ADiv, "idiv": AIdiv, "min": AMin, "max": AMax,
	"eq": CEq, "ne": CNe, "lt": CLt, "lte": CLte, "gt": CGt, "gte": CGte}
const UN := {"floor": AFloor, "round": ARound, "trunc": ATrunc, "not": LNot}

## Compiles a value / condition. Closed vocabulary; depth-bounded; unknown keys fail loudly.
## n-ary add/mul/min/max fold left into binary nodes.
static func _val(v: Variant, depth: int, kind: String) -> N:
	assert(depth <= MAX_DEPTH, "rule expression too deep")
	n_nodes += 1
	if v is Dictionary:
		var d: Dictionary = v
		assert(d.size() == 1, "one operator per node")
		var op := String(d.keys()[0])
		var a: Variant = d[op]
		match op:
			"var":
				if COMPUTED.has(String(a)):
					var vc := VarComputed.new()
					vc.id = int(COMPUTED[String(a)])
					vc.name = String(a)
					return vc
				var vp := VarP.new()
				vp.name = String(a)
				return vp
			"param":
				var p: N = ParamItem.new() if kind == "item" else ParamOwn.new()
				p.set("key", String(a))
				return p
			"sec":
				var s := Sec.new()
				s.key = String(a)
				return s
			"native":
				var nv := Native.new()
				nv.name = String(a)
				return nv
			"in":
				var ci := CIn.new()
				ci.a = _val(a[0], depth + 1, kind)
				ci.list = a[1]
				return ci
			"all", "any":
				var l: N = LAll.new() if op == "all" else LAny.new()
				for y in a:
					(l.get("args") as Array).append(_val(y, depth + 1, kind))
				return l
			"count_dice":
				var cd := CountDice.new()
				var f: Dictionary = a
				cd.in_group = -1 if not f.has("in_group") else (1 if bool(f.in_group) else 0)
				cd.value = int(f.get("value", -1))
				cd.rerolled = -1 if not f.has("rerolled") else (1 if bool(f.rerolled) else 0)
				cd.runed = -1 if not f.has("runed") else (1 if bool(f.runed) else 0)
				cd.shown = int(f.get("shown", -1))
				cd.base_pool = bool(f.get("base_pool", false))
				cd.rune_not = String(f.get("rune_not", ""))
				return cd
			"res":
				var rv := ResVal.new()
				rv.res = String(a)
				return rv
			"asc":
				var ao := AscOn.new()
				ao.key = String(a)
				return ao
			"if":
				var tn := Tern.new()
				tn.c = _val(a[0], depth + 1, kind)
				tn.a = _val(a[1], depth + 1, kind)
				tn.b = _val(a[2], depth + 1, kind)
				return tn
			"has":
				var hs := Has.new()
				hs.l = _val(a[0], depth + 1, kind)
				hs.v = _val(a[1], depth + 1, kind)
				return hs
		if UN.has(op):
			var u: Un = UN[op].new()
			u.a = _val(a, depth + 1, kind)
			return u
		if BIN.has(op):
			var args: Array = a
			assert(args.size() >= 2, op + " needs 2+ operands")
			var acc: N = _val(args[0], depth + 1, kind)
			for k in range(1, args.size()):
				var bn: Bin = BIN[op].new()
				bn.a = acc
				bn.b = _val(args[k], depth + 1, kind)
				acc = bn
			return acc
		assert(false, "unknown operator " + op)
		return null
	var c := Const.new()
	c.v = v
	return c

static func def_of(kind: String, id: String) -> Dictionary:
	if not _loaded:
		ensure()
	return (_db.get(kind, _EMPTY) as Dictionary).get(id, _EMPTY)

# ------------------------------------------------------------------ per-run dispatch table

static func invalidate(run: RunState) -> void:
	run.rules_stamp = -1

static func _index(run: RunState) -> Dictionary:
	var stamp := run.passives.size()
	if run.rules_stamp == stamp:
		return run.rules_idx
	ensure()
	var idx := {}
	var add := func(inst: Inst) -> void:
		if not idx.has(inst.rule.hook):
			idx[inst.rule.hook] = []
		(idx[inst.rule.hook] as Array).append(inst)
	for p in run.passives:
		var d: Dictionary = def_of("passive", String(p))
		for r in d.get("rules", _EMPTY_A):
			var i := Inst.new()
			i.rule = r
			i.kind = "passive"
			i.id = String(p)
			i.params = d.params
			add.call(i)
	var its: Dictionary = run.meta.get("items", _EMPTY)
	for slot in ItemDefs.STAT_SLOTS:
		var e: Dictionary = its.get(slot, _EMPTY)
		if e.is_empty() or int(e.get("tier", 0)) <= 0:
			continue
		var d2: Dictionary = def_of("item", String(e.id))
		for r in d2.get("rules", _EMPTY_A):
			if (r as Rule).variant != "" and (r as Rule).variant != String(e.get("variant", e.id)):
				continue
			var i2 := Inst.new()
			i2.rule = r
			i2.kind = "item"
			i2.id = String(e.id)
			i2.variant = String(e.get("variant", e.id))
			i2.tier = int(e.tier)
			add.call(i2)
	for key in run.meta.get("asc_keys", _EMPTY_A):
		var d3: Dictionary = def_of("asc", String(key))
		for r in d3.get("rules", _EMPTY_A):
			var i3 := Inst.new()
			i3.rule = r
			i3.kind = "asc"
			i3.id = String(key)
			i3.params = d3.params
			add.call(i3)
	for h in idx:
		(idx[h] as Array).sort_custom(func(a: Inst, b: Inst) -> bool: return a.rule.prio < b.rule.prio)
	run.rules_idx = idx
	run.rules_stamp = stamp
	return idx

## True when any active rule listens on `hook` (callers skip building contexts otherwise).
static func listens(run: RunState, hook: String) -> bool:
	return _index(run).has(hook)

# ------------------------------------------------------------------ evaluation

## Runs every active rule on `hook` in priority order (lo..hi band) against ctx.
static func fire(hook: String, x: Ctx, lo := -1000000, hi := 1000000) -> void:
	var list: Array = _index(x.run).get(hook, _EMPTY_A)
	if list.is_empty():
		return
	var t := Time.get_ticks_usec() if timing else 0
	for inst: Inst in list:
		if inst.rule.prio < lo or inst.rule.prio > hi:
			continue
		n_fire += 1
		if _run_one(inst, x) and inst.rule.stop:
			break
	if timing:
		us_fire += Time.get_ticks_usec() - t

## Rune rules of die x.die (rune id `rune`) on `hook`. Returns true when the rune has any.
static func fire_rune(hook: String, rune: String, x: Ctx) -> bool:
	var d: Dictionary = def_of("rune", rune)
	if d.is_empty():
		return false
	var list: Array = (d.by_hook as Dictionary).get(hook, _EMPTY_A)
	if list.is_empty():
		return false
	var t := Time.get_ticks_usec() if timing else 0
	for inst: Inst in list:
		n_fire += 1
		_run_one(inst, x)
	if timing:
		us_fire += Time.get_ticks_usec() - t
	return true

static func _run_one(inst: Inst, x: Ctx) -> bool:
	var r := inst.rule
	x.inst = inst
	if r.cond != null and not bool(r.cond.ev(x)):
		return false
	if r.lim_per != "" and not _limit_ok(r, x):
		return false
	if r.chance != null and not x.run.rng.chance(float(r.chance.ev(x))):
		return false
	var reps := 1 if r.repeat == null else clampi(int(r.repeat.ev(x)), 0, 8)
	for k in reps:
		x.result = null
		x.tgt = -1
		var tmp: Array[Dictionary] = []
		for ef: Effect in r.effects:
			if not ef.apply(x, tmp):
				return false
		if r.ann:
			var av: Variant
			match r.ann_from:
				"result": av = x.result
				"value": av = x.value
				_: av = r.ann_value.ev(x)
			var cnt := 1 if r.ann_count == null else int(r.ann_count.ev(x))
			for c in cnt:
				x.ev.append(_announce(inst, x, av))
		if not tmp.is_empty():
			x.ev.append_array(tmp)
	if r.lim_per != "":
		_limit_use(r, x)
	return true

static func _announce(inst: Inst, x: Ctx, value: Variant) -> Dictionary:
	var e: Dictionary
	match inst.kind:
		"passive":
			e = {"type": "passive_triggered", "id": inst.id, "value": int(value)}
		"item":
			e = ItemLogic.ev(x.run, inst.id, inst.rule.ann_effect, int(value))
		"rune":
			e = {"type": "rune_fired", "die_idx": x.die, "rune": inst.id, "effect": inst.rule.ann_effect, "value": int(value)}
		_:
			e = {"type": "rule_triggered", "kind": inst.kind, "id": inst.id, "value": value}
	for k in inst.rule.ann_extra:
		var xv: Variant = inst.rule.ann_extra[k]
		e[k] = x.tgt if (xv is String and xv == "$target") else (xv as N).ev(x)
	return e

# limits ---------------------------------------------------------------

static func _limit_ok(r: Rule, x: Ctx) -> bool:
	match r.lim_per:
		"fight":
			var mx := int(r.lim_max.ev(x))
			return mx <= 0 or int(x.c.item_state.get(r.lim_key, 0)) < mx
		"run":
			return not bool(x.run.passive_state.get(r.lim_key, false))
		"act":
			return int(x.run.passive_state.get(r.lim_key, 0)) != x.run.act
	return true

static func _limit_use(r: Rule, x: Ctx) -> void:
	match r.lim_per:
		"fight":
			x.c.item_state[r.lim_key] = int(x.c.item_state.get(r.lim_key, 0)) + 1
		"run":
			x.run.passive_state[r.lim_key] = true
		"act":
			x.run.passive_state[r.lim_key] = x.run.act

## Enemy-owned rules on `hook`, enemy by enemy (index order), each with x.self_idx set.
static func fire_enemies(hook: String, x: Ctx) -> void:
	for i in x.c.enemies.size():
		var d: Dictionary = def_of("enemy", String(x.c.enemies[i].id))
		if d.is_empty():
			continue
		var list: Array = (d.by_hook as Dictionary).get(hook, _EMPTY_A)
		for inst: Inst in list:
			x.self_idx = i
			n_fire += 1
			_run_one(inst, x)

static func res_get(x: Ctx, res: String) -> Variant:
	var rd: Dictionary = x.inst.res[res]
	if rd.has("bind"):
		return x.c.get(String(rd.bind))
	return x.c.item_state.get("res:%s:%d" % [res, x.self_idx], int(rd.get("start", 0)))

static func res_set(x: Ctx, res: String, v: int) -> void:
	var rd: Dictionary = x.inst.res[res]
	if rd.has("bind"):
		x.c.set(String(rd.bind), v)
	else:
		x.c.item_state["res:%s:%d" % [res, x.self_idx]] = v

static func param_of(x: Ctx, key: String) -> Variant:
	return x.inst.params.get(key, 0)

## Named native values: closed list, versioned with the core (caps "native:<name>@1").
static func native_value(name: String, x: Ctx) -> Variant:
	match name:
		"rune_dmg":
			return ItemLogic.rune_dmg(x.run)
		"combo.set_value":
			return ItemLogic.set_value(x.vars.eff, x.vars.group)
		"combo.mult_now":
			return float(x.c.current_combo(x.run).mult)
		"target.alive":
			return x.c.alive(int(x.vars.target))
	assert(false, "unknown native value " + name)
	return null

## First rule on `hook` that survives a lethal hit (hero.lethal): returns the owner id or "".
static func first_saved(run: RunState, hook: String) -> String:
	if not listens(run, hook):
		return ""
	var x := Ctx.new(run, null, [] as Array[Dictionary])
	fire(hook, x)
	return x.saved

static func stats_line() -> String:
	return "RULES compiled %d rules / %d nodes in %d us; fired %d rule evaluations, %d us total (%.2f us/eval)" % [
		n_rules, n_nodes, compile_us, n_fire, us_fire, float(us_fire) / maxi(1, n_fire)]
