extends SceneTree
## Headless check: 200 random rolls (random faces incl. duplicates, random index subsets)
## must settle with the requested value face-up, flat, square to the camera, while the
## dice not thrown keep their value.
##   godot --headless --path . -s game/dice/check_dice_tray.gd

const ROLLS := 200


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var tray := DiceTray.new()
	tray.size = Vector2(688, 330)
	root.add_child(tray)
	tray.speed_scale = 25.0
	tray.sfx_enabled = false
	var fails := 0
	for r in ROLLS:
		if r % 20 == 0:
			var n := rng.randi_range(1, 6)
			var pool: Array = []
			for i in n:
				var faces: Array[int] = []
				for k in 6:
					faces.append(rng.randi_range(1, 6) if rng.randf() < 0.4 else k + 1)
				var runes := ["", "blade", "wild", "frost", "gilded"]
				pool.append({"faces": faces, "rune": runes[rng.randi_range(0, runes.size() - 1)], "edited": [0, 0, 0, 0, 0, 0]})
			tray.set_dice(pool)
			var init: Array = []
			for d in tray.dice:
				init.append(d.faces[0])
			tray.set_values(init)
		var n := tray.dice.size()
		var idx: Array[int] = []
		for i in n:
			if rng.randf() < 0.7:
				idx.append(i)
		if idx.is_empty():
			idx.append(rng.randi_range(0, n - 1))
		var before: Array[int] = []
		for i in n:
			before.append(tray.get_up_value(i))
		var values: Array[int] = []
		var per_die := rng.randf() < 0.5
		for i in (n if per_die else idx.size()):
			var die_i: int = i if per_die else idx[i]
			values.append(tray.dice[die_i].faces[rng.randi_range(0, 5)])
		tray.roll(values, idx)
		await tray.settled
		for i in n:
			var want: int = before[i]
			if idx.has(i):
				want = values[i] if per_die else values[idx.find(i)]
			var got := tray.get_up_value(i)
			var flat := tray.get_up_alignment(i)
			var fwd := tray.dice[i].body.basis * DieMesh.face_v(DieMesh.up_slot(tray.dice[i].body.basis))
			var square := absf(fwd.normalized().dot(Vector3.BACK))
			if got != want or flat < 0.9999 or square < 0.99:
				fails += 1
				printerr("FAIL roll %d die %d: want %d got %d flat %.5f square %.4f" % [r, i, want, got, flat, square])
	print("dice tray check: %d rolls, %d failures" % [ROLLS, fails])
	tray.queue_free()
	await process_frame
	await process_frame
	DieMesh.clear_cache()
	quit(1 if fails > 0 else 0)
