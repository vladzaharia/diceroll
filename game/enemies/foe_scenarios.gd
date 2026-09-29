class_name FoeScenarios
extends RefCounted
## Enemy-look scenarios for the screenshot harness (served through game/actors/scenarios.gd).
##  enemy_gallery   every id x its cosmetic variants, labelled, on a plain stage.
##                  --only=old|new|mini|boss|all|<id,id,...> (default old), --tier=1..3 (default:
##                  the id's home biome tier), --elite=1, --traits=a,b, --hud=1 (HP / intent HUDs),
##                  --anim=<role> (loops idle|attack|hit|death|spawn|cast on everyone), --pitch=deg
##  enemy_gallery --legend   meaning sheet: each family x (early, mid, late, elite, armor, thorns,
##                  ward, pierce), from SkinRules. --only picks the families (default: the 7
##                  shared regulars; also crypt|frost|magma|glade|hollow|throne|<ids>)
##  combat_<biome>  a fight on that biome's board with a varied roster from its pool
##                  (--enemies=a,b,c, --elite=1, --seed=N, --tile=N, --beat=attack|hit|die|cast)
##  <boss id> / <mini-boss id>   e.g. boss_lich, mini_grave_mage: that fight on its home biome
##                  (--phase=2: phase-2 traits; the Bone Warden brings two summoned warriors)

const GROUPS := {
	"old": ["skeleton_minion", "skeleton_warrior", "skeleton_archer", "cultist", "bandit", "brute"],
	"new": ["thorn_sprite", "wolf_bandit", "hollow_wisp", "frost_skeleton", "ice_archer", "bone_knight",
		"ember_imp", "magma_brute"],
	"mini": ["mini_bone_champion", "mini_pumpkin_knight", "mini_grave_mage", "mini_frost_warden",
		"mini_briar_beast", "mini_cinder_brute"],
	"boss": ["boss_bone_warden", "boss_lich", "boss_cinder_king", "boss_magma_golem", "boss_hollow_king"],
	"legend": ["skeleton_minion", "skeleton_warrior", "skeleton_archer", "cultist", "bandit", "brute", "wolf_bandit"],
	"size": ["skeleton_minion", "brute", "mini_bone_champion", "mini_cinder_brute", "boss_lich", "boss_magma_golem"],
}
const LEGEND_COLS := [["early", 1, false, []], ["mid", 2, false, []], ["late", 3, false, []], ["elite", 1, true, []],
	["armor", 1, false, ["armor"]], ["thorns", 1, false, ["thorns"]], ["ward", 1, false, ["ward"]],
	["pierce", 1, false, ["pierce"]]]


static func names() -> PackedStringArray:
	var out := PackedStringArray(["enemy_gallery"])
	for b in BiomeDefs.DEFS:
		out.append("combat_" + String(b))
	for id in EnemyDefs.BOSSES:
		out.append(String(id))
	for id in EnemyDefs.MINIBOSSES:
		out.append(String(id))
	return out


static func build(name: String) -> Node:
	if not names().has(name):
		return null
	if name == "enemy_gallery":
		var g := _Gallery.new()
		g.name = "EnemyGallery"
		return g
	var f := _Fight.new()
	f.name = "FoeFight"
	f.scenario = name
	return f


## Biome where an id lives (its home tier drives the default gallery tier).
static func home_biome(id: String) -> String:
	for b in BiomeDefs.DEFS:
		var d: Dictionary = BiomeDefs.DEFS[b]
		if id in d.bosses or id in d.minibosses or id == d.elite:
			return String(b)
		for pool in d.pools:
			if id in pool:
				return String(b)
	return "crypt"


static func _args() -> Dictionary:
	return Shot.args if Shot else {}


## Contract-shaped enemy dict (as core would send it), with its first signature intent.
static func enemy_dict(id: String, elite := false, phase := 1) -> Dictionary:
	var d := CombatState.make_enemy(Rng.new(7), id, 2, 8, elite)
	var ed := EnemyDefs.def(id)
	var pat: Array = ed.get("pattern", (ed.get("phases", [[]]) as Array)[phase - 1] if ed.has("phases") else [])
	if not pat.is_empty():
		d.intent = (pat[0] as Dictionary).duplicate()
		for q: Dictionary in pat:
			if not String(q.kind) in ["attack", "block", "aim"]:
				d.intent = q.duplicate()
				break
	d.traits = EnemyDefs.traits(id, phase).duplicate()
	d.phase = phase
	return d


# --- gallery ------------------------------------------------------------------------------------

class _Gallery extends Node3D:
	var _pts := PackedVector3Array()
	var _cam: Camera3D

	func _ready() -> void:
		var args := FoeScenarios._args()
		load("res://game/actors/scenarios.gd")._add_environment(self)
		for we in find_children("*", "WorldEnvironment", false, false):
			# the ortho camera sits far back; distance fog would wash the sheet out
			(we as WorldEnvironment).environment.fog_enabled = false
		_floor()
		if args.has("legend"):
			_legend(args)
		else:
			_variants(args)
		_cam = Camera3D.new()
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		add_child(_cam)
		_cam.current = true
		get_viewport().size_changed.connect(_fit)
		_fit()

	func _ids(only: String, fallback: String) -> Array:
		if only == "":
			only = fallback
		if only == "all":
			return EnemyRoster.LOOKS.keys()
		if FoeScenarios.GROUPS.has(only):
			return FoeScenarios.GROUPS[only]
		if BiomeDefs.has(only):
			var out := []
			for pool in BiomeDefs.DEFS[only].pools:
				for id in pool:
					if not id in out:
						out.append(id)
			if not BiomeDefs.DEFS[only].elite in out:
				out.append(BiomeDefs.DEFS[only].elite)
			return out
		return Array(only.split(","))

	## Rows of ids, one column per cosmetic variant.
	func _variants(args: Dictionary) -> void:
		var ids := _ids(String(args.get("only", "")), "old")
		var cols := 1
		for id in ids:
			cols = maxi(cols, EnemyLooks.variant_count(String(id)))
		var gap := 2.3
		var z := 0.0
		for r in ids.size():
			var id := String(ids[r])
			var big := _size(id)
			if r > 0:
				z += _row_step(maxf(_tall(id), _tall(String(ids[r - 1]))))
			var tier := int(args.get("tier", str(SkinRules.tier_for(FoeScenarios.home_biome(id)))))
			var traits: Array = Array(String(args.get("traits", "")).split(",", false)) if args.has("traits") else EnemyDefs.traits(id)
			var n := EnemyLooks.variant_count(id)
			var g := gap * maxf(1.0, big * 0.8)
			for v in n:
				var ctx := {"variant": v, "tier": tier, "elite": args.has("elite"), "traits": traits}
				var p := Vector3((float(v) - (cols - 1) * 0.5) * g, 0.0, z)
				var L := EnemyLooks.look(id, ctx)
				_figure(id, ctx, p, args)
				_label(p + Vector3(0, 0.02, 0.75 + 0.2 * big), "%s  %d: %s" % [id, v, String(L.get("label", ""))], 32)

	## Figure height (to its HUD) in stage units.
	func _tall(id: String) -> float:
		return EnemyLooks.hud_height(id) * CombatStage.UNIT_SCALE

	## Depth between rows so a row's heads clear the labels of the row behind at the pitch.
	func _row_step(tall: float) -> float:
		var pitch := deg_to_rad(float(FoeScenarios._args().get("pitch", "30")))
		return tall * 1.3 / tan(pitch) + 0.9

	## Footprint of an id relative to a regular unit (scale x big rig).
	func _size(id: String) -> float:
		return EnemyLooks.scale_of(id) * (1.45 if EnemyLooks.is_large(id) else 1.0)

	## The meaning sheet: family rows x SkinRules columns.
	func _legend(args: Dictionary) -> void:
		var ids := _ids(String(args.get("only", "")), "legend")
		var gap := 2.2
		var row_gap := 0.0
		for id in ids:
			row_gap = maxf(row_gap, _row_step(_tall(String(id))))
		var cols := LEGEND_COLS.size()
		for c in cols:
			var col: Array = LEGEND_COLS[c]
			var x := (float(c) - (cols - 1) * 0.5) * gap
			var z := (-0.5 - (ids.size() - 1) * 0.5) * row_gap - 0.4
			var title := String(col[0]).to_upper()
			_label(Vector3(x, 0.02, z), title, 64, Color(1.0, 0.86, 0.5))
		for r in ids.size():
			var id := String(ids[r])
			var z := (float(r) - (ids.size() - 1) * 0.5) * row_gap
			var nm := String(EnemyDefs.def(id).name) if FoeScenarios._core(id) else id
			_label(Vector3(-(cols - 1) * 0.5 * gap - gap * 0.95, 0.02, z + 0.1), nm.replace(" ", "\n"), 44, Color(0.85, 0.92, 1.0))
			for c in cols:
				var col: Array = LEGEND_COLS[c]
				# one cosmetic variant per row so the columns differ only by meaning
				var ctx := {"variant": 0, "tier": int(col[1]), "elite": bool(col[2]), "traits": col[3]}
				var p := Vector3((float(c) - (cols - 1) * 0.5) * gap, 0.0, z)
				_figure(id, ctx, p, args)

	func _figure(id: String, ctx: Dictionary, p: Vector3, args: Dictionary) -> void:
		var ch := EnemyLooks.create(id, true, ctx)
		ch.scale = Vector3.ONE * CombatStage.UNIT_SCALE * EnemyLooks.scale_of(id)
		ch.position = p
		if args.has("anim"):
			# before add_child: the loop starts on the figure's ready
			load("res://game/actors/scenarios.gd")._loop(ch, String(args.anim))
		add_child(ch)
		var h := EnemyLooks.hud_height(id) * CombatStage.UNIT_SCALE
		_pts.append(p + Vector3(-0.9, 0, 0.6))
		_pts.append(p + Vector3(0.9, 0, 0.6))
		_pts.append(p + Vector3.UP * (h + 0.3))
		if args.has("hud"):
			var hud := UnitHud.new()
			add_child(hud)
			hud.position = p + Vector3.UP * (h + 0.35)
			var d := FoeScenarios.enemy_dict(id, bool(ctx.get("elite", false))) if FoeScenarios._core(id) else {"hp": 10, "max_hp": 12}
			d.traits = ctx.get("traits", [])
			hud.set_data(d, false)
			_pts.append(hud.position + Vector3.UP * 0.6)
		if args.has("yaw"):
			ch.rotation.y = deg_to_rad(float(args.yaw))
		if args.has("pose"):
			# --pose=<role>@<fraction>: freeze the clip at that point (0..1) for a still check
			var pr := String(args.pose).split("@")
			var clip := ch.resolve(pr[0])
			if clip != "":
				ch.anim_player.play(clip, 0.0)
				ch.anim_player.seek(ch.anim_player.get_animation(clip).length * float(pr[1] if pr.size() > 1 else "0.5"), true)
				ch.anim_player.pause()

	func _label(p: Vector3, text: String, size: int, color := Color(1.0, 0.95, 0.85)) -> void:
		var l := Label3D.new()
		l.text = text
		l.font = load(Props.FONT_TITLE)
		l.font_size = size
		l.pixel_size = 0.006
		l.outline_size = 12
		l.outline_modulate = Color(0.06, 0.05, 0.08, 0.95)
		l.modulate = color
		l.position = p
		l.rotation_degrees.x = -90.0
		l.width = 380.0
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(l)
		# the label's footprint (not just its anchor) must stay in frame
		var half := minf(float(text.split("\n")[0].length()) * size * l.pixel_size * 0.3, l.width * l.pixel_size * 0.5)
		_pts.append(p + Vector3(-half, 0, 0))
		_pts.append(p + Vector3(half, 0, 0))

	func _floor() -> void:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(400, 400)
		mi.mesh = pm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.3, 0.27, 0.3)
		m.roughness = 0.95
		mi.material_override = m
		add_child(mi)

	func _fit() -> void:
		var pitch := deg_to_rad(float(FoeScenarios._args().get("pitch", "30")))
		var vs := get_viewport().get_visible_rect().size
		var aspect := vs.x / maxf(vs.y, 1.0)
		var fwd := Vector3(0, -sin(pitch), -cos(pitch))
		var basis := Basis.looking_at(fwd, Vector3.UP)
		var right := basis.x
		var up := basis.y
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		var c := Vector3.ZERO
		for p in _pts:
			c += p
		c /= maxf(_pts.size(), 1)
		for p in _pts:
			var d := p - c
			var q := Vector2(d.dot(right), d.dot(up))
			lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
			hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
		var mid := c + right * (lo.x + hi.x) * 0.5 + up * (lo.y + hi.y) * 0.5
		var w := (hi.x - lo.x) * 1.06
		var h := (hi.y - lo.y) * 1.08
		_cam.keep_aspect = Camera3D.KEEP_HEIGHT
		_cam.size = maxf(h, w / aspect)
		_cam.global_transform = Transform3D(basis, mid - fwd * 150.0)
		_cam.far = 400.0


static func _core(id: String) -> bool:
	return EnemyDefs.ENEMIES.has(id) or EnemyDefs.BOSSES.has(id) or EnemyDefs.MINIBOSSES.has(id)


# --- fights on a biome board ---------------------------------------------------------------------

class _Fight extends Node3D:
	var scenario := ""
	var board: BoardView
	var rig: CameraRig
	var stage: CombatStage

	func _ready() -> void:
		var args := FoeScenarios._args()
		EnemyLooks.run_seed = int(args.get("seed", "0"))
		var boss_fight := EnemyDefs.BOSSES.has(scenario) or EnemyDefs.MINIBOSSES.has(scenario)
		var biome := scenario.trim_prefix("combat_") if scenario.begins_with("combat_") else FoeScenarios.home_biome(scenario)
		biome = String(args.get("biome", biome))
		var tier := SkinRules.tier_for(biome)
		board = BoardView.new()
		add_child(board)
		board.hero_class = String(args.get("hero", ["knight", "barbarian", "mage"][tier - 1]))
		var idx := int(args.get("tile", "0" if EnemyDefs.BOSSES.has(scenario) else ("11" if boss_fight else "3")))
		board.hero_idx = idx
		board.build(biome, BoardScenarios.biome_tiles(biome))
		rig = CameraRig.new()
		add_child(rig)
		board.place_hero(idx)
		var phase := int(args.get("phase", "1"))
		var elite := args.has("elite")
		var list := []
		if boss_fight:
			list.append(FoeScenarios.enemy_dict(scenario, false, phase))
			if scenario == "boss_bone_warden" and phase == 2:
				for k in 2:
					var s := FoeScenarios.enemy_dict("skeleton_warrior")
					s.summoned = true
					list.append(s)
		else:
			var ids: Array = Array(String(args.get("enemies", "")).split(",", false))
			if ids.is_empty():
				var pool: Array = BiomeDefs.DEFS[biome].pools[1]
				ids = [pool[0], pool[0], pool[1]] if not elite else [BiomeDefs.DEFS[biome].elite, pool[0]]
			for id in ids:
				list.append(FoeScenarios.enemy_dict(String(id), elite))
		stage = CombatStage.new()
		add_child(stage)
		rig.overview(board.ring_bounds(), true)
		var begun := [false]
		stage.began.connect(func() -> void: begun[0] = true, CONNECT_ONE_SHOT)
		stage.begin_on_board(board, idx, list, rig)
		rig.combat(board.hero.global_position, stage.enemy_positions(), true, stage.enemy_heights())
		while not begun[0]:
			await get_tree().process_frame
		if scenario == "boss_magma_golem" and phase == 2:
			EnemyLooks.shatter(stage.enemies[0])
		var wait := float(args.get("wait", "2.0"))
		var beat := String(args.get("beat", ""))
		if beat == "":
			return
		await get_tree().create_timer(maxf(wait - 1.2, 0.05)).timeout
		var i := int(args.get("who", str(list.size() - 1 if boss_fight else 0)))
		match beat:
			"attack":
				stage.enemy_attack(i)
			"hit":
				stage.enemy_hit(i, 9)
			"die":
				stage.enemy_die(i)
			"cast":
				stage.enemies[i].play_once("cast", "idle")
			"hero":
				stage.hero_attack(i)
