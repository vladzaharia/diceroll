extends "res://tests/test_case.gd"
## Enemy looks (game/enemies, game/world/enemy_looks.gd): every id x variant builds, resolves
## a real clip for every role (no T-poses), and the meaningful skin layers stay consistent.

const ROLES := ["idle", "attack", "hit", "death", "spawn", "cast", "walk"]


func _assets() -> bool:
	# third-party assets are git-ignored; a fresh clone runs tools/import_assets.sh first
	return ResourceLoader.exists(String(Character.MODELS["skel_minion"][0]))


func test_every_core_enemy_has_a_look() -> void:
	for table in [EnemyDefs.ENEMIES, EnemyDefs.MINIBOSSES, EnemyDefs.BOSSES]:
		for id in table:
			assert_true(EnemyRoster.LOOKS.has(id), "no look for %s" % id)


func test_every_trait_has_a_skin_rule() -> void:
	var seen := {}
	for table in [EnemyDefs.ENEMIES, EnemyDefs.MINIBOSSES]:
		for id in table:
			for t in EnemyDefs.traits(id):
				seen[t] = true
	for id in EnemyDefs.BOSSES:
		for ph in [1, 2]:
			for t in EnemyDefs.traits(id, ph):
				seen[t] = true
	for t in seen:
		assert_true(SkinRules.TRAITS.has(t), "trait %s has no SkinRules entry" % t)


func test_variants_step_through_a_tile() -> void:
	EnemyLooks.run_seed = 1234
	var n := EnemyLooks.variant_count("skeleton_minion")
	assert_true(n >= 3, "skeleton_minion needs 3+ variants")
	var prior := []
	var got := {}
	for k in 3:
		var v := EnemyLooks.variant_for("skeleton_minion", 5, prior)
		got[v] = true
		prior.append({"id": "skeleton_minion"})
	assert_eq(got.size(), 3, "three minions on one tile look different")
	assert_eq(EnemyLooks.variant_for("skeleton_minion", 5, []), EnemyLooks.variant_for("skeleton_minion", 5, []), "deterministic")
	var runs := {}
	for s in 8:
		EnemyLooks.run_seed = s * 7919
		runs[EnemyLooks.variant_for("skeleton_minion", 5, [])] = true
	assert_true(runs.size() > 1, "runs differ")
	EnemyLooks.run_seed = 0


func test_meaning_layers() -> void:
	# a regular enemy never looks elite; tiers swap colourways; bosses keep their own
	var early := EnemyLooks.look("skeleton_minion", {"tier": 1})
	var late := EnemyLooks.look("skeleton_minion", {"tier": 3})
	var elite := EnemyLooks.look("skeleton_minion", {"tier": 1, "elite": true})
	assert_true(not early.has("elite") and not late.has("elite"), "regulars are not elite")
	assert_true(bool(elite.get("elite", false)), "elite flag")
	assert_true(String(early.get("texture", "")) != String(late.get("texture", "")), "late skeletons use the alternate skin")
	assert_true(float(late.get("strength", 0.0)) >= SkinRules.LATE_TINT_STRENGTH, "late tier darkens")
	var boss := EnemyLooks.look("boss_lich", {"tier": 3, "elite": true})
	assert_true(not boss.has("elite"), "bosses skip the elite skin")
	assert_eq(boss.get("texture", ""), EnemyLooks.def("boss_lich").get("texture", ""), "bosses keep their own colourway")
	for id in EnemyRoster.LOOKS:
		for v in EnemyLooks.variant_count(id):
			var raw: Dictionary = (EnemyRoster.LOOKS[id].get("variants", [{}]) as Array)[v] if EnemyRoster.LOOKS[id].has("variants") else {}
			var unique := bool(EnemyRoster.LOOKS[id].get("boss", false)) or bool(EnemyRoster.LOOKS[id].get("miniboss", false))
			if not unique:
				assert_true(not raw.has("texture") and not EnemyRoster.LOOKS[id].has("texture"),
					"%s v%d: regular colourways come from SkinRules tiers" % [id, v])
			assert_true(not raw.has("elite"), "%s v%d: cosmetic variants never carry elite" % [id, v])


func test_every_look_builds_with_real_clips() -> void:
	if not _assets():
		print("  (skipped: run tools/import_assets.sh for the enemy assets)")
		return
	for id in EnemyRoster.LOOKS:
		for v in EnemyLooks.variant_count(id):
			for ctx in [{"variant": v, "tier": 1}, {"variant": v, "tier": 3, "elite": true, "traits": ["armor", "pierce"]}]:
				var L := EnemyLooks.look(id, ctx)
				assert_true(Character.MODELS.has(String(L.model)), "%s v%d: unknown model %s" % [id, v, L.model])
				if String(L.get("texture", "")) != "":
					assert_true(ResourceLoader.exists(String(L.texture)), "%s v%d: missing texture %s" % [id, v, L.texture])
				for slot in L.get("gear", {}):
					assert_true(ResourceLoader.exists(String(L.gear[slot])), "%s v%d: missing gear %s" % [id, v, L.gear[slot]])
				var ch := EnemyLooks.create(id, false, ctx)
				for role in ROLES:
					assert_true(ch.has_anim(role), "%s v%d: no clip for %s" % [id, v, role])
					var o: Variant = ch.clip_overrides.get(role, "")
					for clip in (o if o is Array else [o]):
						if String(clip) != "":
							assert_true(ch.anim_player.has_animation(String(clip)), "%s v%d: %s clip %s missing" % [id, v, role, clip])
				assert_true(ch.anim_player.get_animation(ch.resolve("idle")).loop_mode != Animation.LOOP_NONE,
					"%s v%d: idle must loop" % [id, v])
				assert_true(ch.anim_player.get_animation(ch.resolve("death")).loop_mode == Animation.LOOP_NONE,
					"%s v%d: death must not loop" % [id, v])
				ch.free()
	Character.clear_cache()
