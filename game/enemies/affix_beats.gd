class_name AffixBeats
extends RefCounted
## Combat presentation for the 2026-09-28 mechanics (docs/design/2026-09-28-classes-enemies-skins.md
## §3, §3A.6): affix procs (affix_triggered), the transform (enemy_transformed: an in-place model
## swap with a burst), rally (buff all + a drum beat) and frenzy stacks. EventPlayer routes the
## events here; like BiomeBeats it only reads events and never touches rules.

const MOON := Color(0.8, 0.88, 1.0)
const RALLY := Color(1.0, 0.5, 0.2)


## affix_triggered {enemy_idx, affix, value}: the badge flashes, the rim flares and a short pop
## names the proc (thorn reflect, regen heal, hex curse, chill, frenzy stacks, gilded charge).
static func affix_triggered(c: GameController, ev: Dictionary) -> void:
	var i := int(ev.get("enemy_idx", -1))
	var a := String(ev.get("affix", ""))
	var v := int(ev.get("value", 0))
	if i < 0 or i >= c.stage.enemy_count():
		return
	EncounterCards.note_affix(c, a)
	var st := c.stage
	var ch: Character = st.enemies[i]
	var col := SkinRules.affix_color(a)
	st.huds[i].flash_affix(a)
	AffixLooks.pulse(ch, a)
	var pos := st.enemy_position(i)
	var top := _pop_at(st, i)
	var text := AffixDefs.name_of(a).to_upper()
	var hold := 0.3
	match a:
		"thorned":
			text = "THORNS %d" % v
			Fx.burst(st, pos + Vector3.UP * 0.5, {"amount": 18, "lifetime": 0.55, "speed": Vector2(2.0, 4.5), "size": 0.18,
				"color": col, "tex": "spark", "spread": 70.0})
			hold = 0.2
		"regenerating":
			text = "REGEN"
			Fx.heal_glow(st, pos)
			hold = 0.15
		"hexing":
			text = "HEX!"
			Fx.shockwave(st, pos + Vector3.UP * 0.05, col, 1.4, 0.45)
			ch.play_once("cast" if ch.has_anim("cast") else "attack", "idle", 0.08, 1.2)
		"frostbound":
			text = "CHILL!"
			Fx.status_burst(st, pos + Vector3.UP, "frost")
		"frenzied":
			text = "FRENZY %d/%d" % [v, EnemyDefs.FRENZY_MAX]
			_set_frenzy(c, i, v)
			hold = 0.15
		"gilded":
			text = "+%d PET CHARGE" % v
			Fx.coin_burst(st, pos + Vector3.UP * 0.4, 8)
			Audio.play_sfx("coin")
	Fx.popup_text(st, top, text, col.lightened(0.25), 0.75)
	await c.wait(hold)


## Frenzy status (the Orc Raider's trait, or the Frenzied affix): stacks on the HUD and steam.
static func frenzy(c: GameController, ev: Dictionary) -> void:
	var i := int(ev.target)
	var v := int(ev.get("value", 0))
	_set_frenzy(c, i, v)
	var st := c.stage
	var ch: Character = st.enemies[i]
	ch.play_once("cheer" if ch.has_anim("cheer") else "hit", "idle", 0.08)
	var pos := st.enemy_position(i)
	Fx.burst(st, pos + Vector3.UP * 1.3, {"amount": 12, "lifetime": 0.6, "speed": Vector2(1.0, 2.5), "size": 0.28,
		"color": Color(1.0, 0.6, 0.35, 0.8), "tex": "dot", "spread": 40.0, "gravity": Vector3(0, 2.0, 0)})
	if not st.huds[i].affixes.has("frenzied"):
		Fx.popup_text(st, _pop_at(st, i),
			"FRENZY +%d" % v, SkinRules.TRAITS.frenzy.color.lightened(0.2), 0.75)
	Audio.play_sfx("buff")
	await c.wait(0.3)


## Where a proc pop starts: at the enemy's chest, in front of it (the HUD sits above).
static func _pop_at(st: CombatStage, i: int) -> Vector3:
	var h := EnemyLooks.hud_height(String(st.data[i].get("id", ""))) * CombatStage.UNIT_SCALE
	var to_hero := (st.hero_home - st.enemy_position(i))
	to_hero.y = 0.0
	return st.enemy_position(i) + Vector3.UP * h * 0.5 + to_hero.normalized() * 0.4


static func _set_frenzy(c: GameController, i: int, v: int) -> void:
	if i < c.stage.enemy_count():
		c.stage.set_enemy(i, {"frenzy": v})
		AffixLooks.set_stacks(c.stage.enemies[i], v)


## Rally (status buff with rally = true, one per living enemy): the first event plays the
## caster's drum beat and a war-cry ring; every ally then flares "+N ATK".
static func rally(c: GameController, ev: Dictionary) -> void:
	var i := int(ev.target)
	var src := int(ev.get("source", i))
	var st := c.stage
	if i == _first_alive(c) and src < st.enemy_count():
		await drum_beat(c, src)
	var pos := st.enemy_position(i) + Vector3.UP
	Fx.status_burst(st, pos, "buff")
	var gain := 0
	var ed: Dictionary = EnemyDefs.def(String(st.data[src].get("id", ""))) if src < st.data.size() else {}
	for q: Dictionary in ed.get("pattern", []):
		if String(q.kind) == "rally":
			gain = int(q.value)
	Fx.popup_text(st, _pop_at(st, i) - Vector3.UP * 0.25, "+%d ATK" % gain if gain > 0 else "ATK UP", RALLY.lightened(0.2), 0.7)
	await c.wait(0.12)


## The drummer beats its war drum: two thumps, an orange war-cry ring and a camera nudge.
static func drum_beat(c: GameController, src: int) -> void:
	var st := c.stage
	var ch: Character = st.enemies[src]
	var pos := st.enemy_position(src)
	for k in 2:
		ch.play_once("cheer", "idle", 0.05, 1.5)
		Audio.play_sfx("drum")
		Fx.shockwave(st, pos + Vector3.UP * 0.06, RALLY, 1.6 + 1.6 * k, 0.45)
		if c.rig:
			c.rig.shake(0.25, 0.18)
		await c.wait(0.28)
	Fx.popup_text(st, _pop_at(st, src) + Vector3.UP * 0.3,
		"RALLY!", RALLY.lightened(0.25), 1.0)
	await c.wait(0.2)


static func _first_alive(c: GameController) -> int:
	if c.flow and c.flow.combat:
		for k in c.flow.combat.enemies.size():
			if c.flow.combat.alive(k):
				return k
	for k in c.stage.data.size():
		if int(c.stage.data[k].get("hp", 0)) > 0:
			return k
	return 0


## enemy_transformed {enemy_idx, form}: the model swaps in place with a burst.
static func transformed(c: GameController, ev: Dictionary) -> void:
	var i := int(ev.get("enemy_idx", -1))
	if i < 0 or i >= c.stage.enemy_count():
		return
	Audio.play_sfx("portal")
	c.stage.transform_enemy(i, String(ev.get("form", "wolf")))
	if c.rig:
		c.rig.shake(0.5, 0.4)
	var nm := String(c.stage.data[i].get("name", "It"))
	Fx.popup_text(c.stage, _pop_at(c.stage, i) + Vector3.UP * 0.3,
		"%s TURNS!" % nm.to_upper(), MOON, 1.0)
	await c.wait(0.9)


## The burst around a swapped figure: smoke, a moon-silver ring, and the new body pops up howling.
static func transform_fx(stage: Node3D, ch: Character, at: Vector3) -> void:
	Fx.burst(stage, at + Vector3.UP * 0.8, {"amount": 36, "lifetime": 0.9, "speed": Vector2(1.0, 3.0), "size": 0.55,
		"color": Color(0.35, 0.32, 0.4, 0.85), "tex": "dot", "additive": false, "spread": 80.0, "gravity": Vector3(0, 1.2, 0)})
	Fx.burst(stage, at + Vector3.UP * 1.0, {"amount": 20, "lifetime": 0.7, "speed": Vector2(2.0, 5.0), "size": 0.22,
		"color": MOON, "tex": "spark", "spread": 90.0})
	Fx.shockwave(stage, at + Vector3.UP * 0.05, MOON, 2.0, 0.5)
	var s := ch.scale
	ch.scale = s * 0.6
	var t := ch.create_tween()
	t.tween_property(ch, "scale", s, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ch.play_once("cheer" if ch.has_anim("cheer") else "attack", "idle", 0.05)


## Warded domes only while they protect (another living enemy without Warded).
static func refresh_warded(stage: CombatStage) -> void:
	for k in stage.data.size():
		if k >= stage.enemies.size() or not "ward_allies" in (stage.data[k].get("traits", []) as Array):
			continue
		var others := 0
		for j in stage.data.size():
			if j != k and int(stage.data[j].get("hp", 0)) > 0 and not "ward_allies" in (stage.data[j].get("traits", []) as Array):
				others += 1
		AffixLooks.set_ward_active(stage.enemies[k], others > 0 and int(stage.data[k].get("hp", 0)) > 0)
