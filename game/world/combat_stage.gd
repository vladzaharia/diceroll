class_name CombatStage
extends Node3D
## Stages a fight on the board: enemies rise from the ground in a row facing the hero,
## world-anchored HP bars + intents, and awaitable attack / hit / death beats.
##
##   var stage := CombatStage.new()
##   world.add_child(stage)
##   await stage.begin(hero, board.combat_anchor(idx), enemies)   # enemies: contract dicts
##   camera.combat(hero.global_position, stage.enemy_positions())
##   await stage.hero_attack(0, "melee")
##   await stage.enemy_hit(0, 14, true)
##   await stage.enemy_die(0)
##
## Enemy dicts: {id, name, hp, max_hp, block, intent:{kind, value}, boss, poison, frozen}.

signal began

const UNIT_SCALE := 0.7
const SPACING := 1.75
const DISTANCE := 2.7

var hero: Character
var hero_home := Vector3.ZERO
var facing := Vector3.FORWARD
var side := Vector3.RIGHT
var enemies: Array[Character] = []
var huds: Array[UnitHud] = []
var data: Array[Dictionary] = []
var target := 0
## Presentation speed (game speed setting): scales beat timers, tweens and enemy clips.
var speed := 1.0

var _target_ring: MeshInstance3D
var _board: BoardView
var _board_idx := -1
var _rig: CameraRig
var _ground_y := 0.0
var _distance := DISTANCE
## Sideways shift of the enemy line (world units along `side`) so it clears the hero on screen.
var _lateral := 0.0


func _init() -> void:
	name = "CombatStage"


## Spawns the enemies (rising from the ground) and turns the hero toward them.
## anchor: {hero: Vector3, facing: Vector3, side: Vector3, ground_y: float} (BoardView.combat_anchor).
func begin(p_hero: Character, anchor: Dictionary, enemy_list: Array) -> void:
	clear()
	hero = p_hero
	hero_home = anchor.get("hero", p_hero.global_position)
	facing = (anchor.get("facing", Vector3.FORWARD) as Vector3).normalized()
	side = (anchor.get("side", facing.cross(Vector3.UP)) as Vector3).normalized()
	_ground_y = float(anchor.get("ground_y", hero_home.y - 0.45))
	_distance = float(anchor.get("distance", DISTANCE))
	_lateral = float(anchor.get("lateral", 0.0))
	# the fight is staged on the anchor tile: the hero always starts (and returns) there
	hero.global_position = hero_home
	_face(hero, hero_home + facing, 0.3)
	_arena()
	var n := enemy_list.size()
	for i in n:
		_add(enemy_list[i], i, n, 0.05 + 0.2 * i)
	await get_tree().create_timer((0.2 * n + 0.75) / speed, false).timeout
	set_target(0)
	began.emit()


## One-call staging on a BoardView tile: hides the tile's dressing and nearby props,
## spawns the enemies, frames `rig` (optional) in combat mode and sinks occluders.
## Await it; resolves once every enemy has risen.
func begin_on_board(board: BoardView, idx: int, enemy_list: Array, rig: CameraRig = null) -> void:
	_board = board
	_board_idx = idx
	_rig = rig
	if board.hero_idx != board.wrap_idx(idx):
		push_warning("CombatStage: hero on tile %d, fight on tile %d; moving the hero" % [board.hero_idx, idx])
		board.place_hero(idx)
	board.set_tile_dressing_visible(idx, false)
	var anchor := board.combat_anchor(idx)
	if rig:
		# The combat camera swings behind the hero; shift the line toward screen-right so the
		# enemy nearest the hero isn't hidden behind them.
		var sw := deg_to_rad(rig.combat_swing_portrait if rig.is_portrait() else rig.combat_swing_landscape)
		var right: Vector3 = (anchor.facing as Vector3).rotated(Vector3.UP, -sw)
		var sgn := signf((anchor.side as Vector3).dot(right))
		anchor["lateral"] = sgn * (1.0 if rig.is_portrait() else 0.5)

	begin(board.hero, anchor, enemy_list)

	var focus: Array = enemy_positions()
	focus.append(hero_home)
	var centre := Vector3.ZERO
	for f: Vector3 in focus:
		centre += f
	board.clear_area(centre / focus.size(), 5.5)
	if rig:
		rig.combat(hero_home, enemy_positions(), false, enemy_heights())
		var vs := get_viewport().get_visible_rect().size
		board.hide_occluders(rig.desired_transform(), rig.camera.fov, vs.x / maxf(vs.y, 1.0), focus)
	await began


## Re-frames the camera after the line-up changed (summons, deaths).
func reframe() -> void:
	if _rig and hero:
		var pos: Array[Vector3] = []
		var hs := []
		var all := enemy_positions()
		var heights := enemy_heights()
		for i in enemies.size():
			if enemies[i].visible:
				pos.append(all[i])
				hs.append(heights[i])
		if not pos.is_empty():
			_rig.combat(hero_home, pos, false, hs)
			if _board:
				var focus: Array = pos.duplicate()
				focus.append(hero_home)
				var vs := get_viewport().get_visible_rect().size
				_board.hide_occluders(_rig.desired_transform(), _rig.camera.fov, vs.x / maxf(vs.y, 1.0), focus)


## Undoes begin_on_board(): clears the stage, restores props and returns the camera to
## follow the hero (or overview when `overview` is true).
func end_on_board(overview := false) -> void:
	clear()
	if _board:
		_board.restore_occluders()
		_board.set_tile_dressing_visible(_board_idx, true)
		_board.place_hero(_board_idx)
	if _rig and _board:
		if overview:
			_rig.overview(_board.ring_bounds())
		else:
			_rig.follow(_board.hero)
	_board = null
	_rig = null


## Adds one enemy mid-fight (summons). Returns its index.
func add_enemy(d: Dictionary) -> int:
	var i := enemies.size()
	_add(d, i, i + 1, 0.0)
	_relayout()
	return i


func enemy_count() -> int:
	return enemies.size()


## World position of enemy i's feet (its resting slot; valid right after begin()).
func enemy_position(i: int) -> Vector3:
	return _slot(i, enemies.size()) if i < enemies.size() else hero_home + facing * DISTANCE


## Height above each enemy's feet that framing should include (top of its HUD).
func enemy_heights() -> Array:
	var out := []
	for i in enemies.size():
		var tall := bool(data[i].get("boss", false)) or bool(data[i].get("miniboss", false))
		out.append(_hud_height(String(data[i].get("id", ""))) + (1.1 if tall else 0.7))
	return out


func enemy_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in enemies.size():
		out.append(_slot(i, enemies.size()))
	return out


func _slot(i: int, n: int) -> Vector3:
	var c := float(i) - float(n - 1) * 0.5
	var along := _distance + (0.35 if n > 1 else 0.3) + absf(c) * -0.3
	var base := hero_home + facing * along + side * (c * SPACING + _lateral * (1.0 if n > 1 else 0.5))
	return Vector3(base.x, _ground_y + _floor_offset(), base.z)


func _floor_offset() -> float:
	return 0.0


func _add(d: Dictionary, i: int, n: int, rise_delay := -1.0) -> void:
	var id := String(d.get("id", "skeleton_minion"))
	var ch := EnemyLooks.create(id)
	ch.anim_player.speed_scale = speed
	var s := UNIT_SCALE * EnemyLooks.scale_of(id)
	ch.scale = Vector3.ONE * s
	add_child(ch)
	var pos := _slot(i, n)
	ch.global_position = pos
	_face(ch, hero_home, 0.0)
	enemies.append(ch)
	var dd := d.duplicate(true)
	dd["boss"] = bool(d.get("boss", EnemyLooks.is_boss(id)))
	data.append(dd)
	dd["miniboss"] = bool(d.get("miniboss", EnemyLooks.is_miniboss(id)))
	var hud := UnitHud.new()
	add_child(hud)
	hud.scale = Vector3.ONE * (1.2 if dd.boss else (1.1 if dd.miniboss else 1.0))
	hud.global_position = pos + Vector3.UP * _hud_height(id)
	hud.set_data(dd, false)
	huds.append(hud)
	# shadow disc under the unit (grounds it on the moat floor)
	var blob := _blob(0.55 * s / UNIT_SCALE)
	ch.add_child(blob)
	if rise_delay >= 0.0:
		_rise(ch, id, hud, rise_delay)


func _hud_height(id: String) -> float:
	var h := 2.2 * UNIT_SCALE * EnemyLooks.scale_of(id)
	if id == "brute":
		h *= 1.2
	return h + 0.35


func _rise(ch: Character, id: String, hud: UnitHud, delay: float) -> void:
	var final := ch.global_position
	ch.global_position = final - Vector3.UP * 1.6
	hud.visible = false
	ch.visible = false
	if delay > 0.0:
		await get_tree().create_timer((delay) / speed, false).timeout
	if not is_instance_valid(ch):
		return
	ch.visible = true
	Fx.burst(self, final + Vector3.UP * 0.15, {"amount": 22, "lifetime": 0.8, "speed": Vector2(1.0, 3.0),
		"gravity": Vector3(0, -6, 0), "size": 0.26, "color": Color(0.55, 0.45, 0.4), "tex": "dot",
		"additive": false, "spread": 60.0})
	Fx.shockwave(self, final + Vector3.UP * 0.04, Color(0.8, 0.5, 1.0) if EnemyLooks.is_boss(id) else Color(1.0, 0.6, 0.4), 1.6)
	var clip := EnemyLooks.clip(id, "spawn")
	ch.play_once(clip, EnemyLooks.clip(id, "idle"))
	var t := ch.create_tween().set_speed_scale(speed)
	t.tween_property(ch, "global_position", final, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void:
		hud.visible = true
		hud.scale = Vector3.ONE * 0.01
		var ht := hud.create_tween().set_speed_scale(speed)
		ht.tween_property(hud, "scale", Vector3.ONE * (1.2 if EnemyLooks.is_boss(id) else (1.1 if EnemyLooks.is_miniboss(id) else 1.0)), 0.25) \

			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	Audio.play_sfx("trap", 0.1)


func _relayout() -> void:
	var n := enemies.size()
	for i in n:
		var p := _slot(i, n)
		var t := enemies[i].create_tween().set_speed_scale(speed)
		t.tween_property(enemies[i], "global_position", p, 0.3).set_trans(Tween.TRANS_SINE)
		var ht := huds[i].create_tween().set_speed_scale(speed)
		ht.tween_property(huds[i], "global_position", p + Vector3.UP * _hud_height(String(data[i].get("id", ""))), 0.3)


## Updates enemy i's HP / block / intent / statuses from a contract dict.
func set_enemy(i: int, d: Dictionary) -> void:
	if i >= data.size():
		return
	for k in d:
		data[i][k] = d[k]
	huds[i].set_data(data[i], true)


## Moves the target marker under enemy i.
func set_target(i: int) -> void:
	target = i
	if _target_ring == null:
		_target_ring = MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(1.5, 1.5)
		_target_ring.mesh = pm
		var m := Props.glow_material(Color(1.0, 0.3, 0.25), true, 1.8)
		m.albedo_texture = Props.particle_texture("ring")
		_target_ring.material_override = m
		_target_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_target_ring)
		var t := _target_ring.create_tween().set_speed_scale(speed).set_loops()
		t.tween_property(_target_ring, "scale", Vector3.ONE * 1.1, 0.5).set_trans(Tween.TRANS_SINE)
		t.tween_property(_target_ring, "scale", Vector3.ONE * 0.92, 0.5).set_trans(Tween.TRANS_SINE)
	if i < 0 or i >= enemies.size():
		_target_ring.visible = false
		return
	_target_ring.visible = true
	var s := EnemyLooks.scale_of(String(data[i].get("id", "")))
	_target_ring.global_position = enemies[i].global_position + Vector3.UP * 0.04
	_target_ring.global_basis = Basis().scaled(Vector3.ONE * s)


# --- beats --------------------------------------------------------------------------------

## Enemy i lunges at the hero and plays its attack. Resolves at the impact moment's end.
func enemy_attack(i: int) -> void:
	if i >= enemies.size():
		return
	var ch := enemies[i]
	var id := String(data[i].get("id", ""))
	var home := ch.global_position
	var ranged := id in ["skeleton_archer", "cultist", "boss_lich", "mini_grave_mage"]
	var lunge := home + (hero_home - home).normalized() * (0.2 if ranged else 0.9)
	var t := ch.create_tween().set_speed_scale(speed)
	t.tween_property(ch, "global_position", lunge, 0.18).set_trans(Tween.TRANS_SINE)
	var clip := EnemyLooks.clip(id, "attack")
	ch.play_once(clip, EnemyLooks.clip(id, "idle"), 0.08, 1.3)
	Audio.play_sfx("swing")
	await get_tree().create_timer((0.32) / speed, false).timeout
	if ranged:
		var col := Color(0.7, 0.4, 1.0) if id != "skeleton_archer" else Color(1.0, 0.9, 0.7)
		await Fx.projectile(self, ch.global_position + Vector3.UP * 1.1, hero_home + Vector3.UP * 0.8, col, 0.28 / speed)
	var back := ch.create_tween().set_speed_scale(speed)
	back.tween_property(ch, "global_position", home, 0.3).set_trans(Tween.TRANS_SINE).set_delay(0.1)


## Enemy i takes damage: flash, knock-back, number, sparks. `blocked` is absorbed by block.
func enemy_hit(i: int, amount: int, crit := false, blocked := 0) -> void:
	if i >= enemies.size():
		return
	var ch := enemies[i]
	var id := String(data[i].get("id", ""))
	var top := ch.global_position + Vector3.UP * (1.3 * UNIT_SCALE / 0.6 * EnemyLooks.scale_of(id))
	var num_pos := top + _toward_camera(ch.global_position) * 0.6
	if blocked > 0:
		Fx.block_flash(self, ch.global_position + Vector3.UP * 0.8 * EnemyLooks.scale_of(id), 0.8 * EnemyLooks.scale_of(id))
		Audio.play_sfx("block")
	if amount > 0:
		Fx.hit_sparks(self, top, Fx.CRIT_COLOR if crit else Color(1.0, 0.85, 0.6), 26 if crit else 16)
		Fx.damage_number(self, num_pos, amount, crit)
		Audio.play_sfx("crit" if crit else "hit")
		_flash_white(ch, id)
		var dir := (ch.global_position - hero_home)
		dir.y = 0.0
		dir = dir.normalized()
		var home := _slot(i, enemies.size())
		var t := ch.create_tween().set_speed_scale(speed)
		t.tween_property(ch, "global_position", home + dir * (0.45 if crit else 0.25), 0.07)
		t.tween_property(ch, "global_position", home, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ch.play_once("hit", EnemyLooks.clip(id, "idle"), 0.05)
		if crit:
			Fx.hit_stop(self, 0.08)
	elif blocked > 0:
		Fx.popup_text(self, num_pos, "BLOCK", Fx.BLOCK_COLOR, 0.8)
	var d := data[i]
	d["block"] = maxi(int(d.get("block", 0)) - blocked, 0)
	d["hp"] = maxi(int(d.get("hp", 0)) - amount, 0)
	huds[i].set_data(d, true)
	await get_tree().create_timer((0.35) / speed, false).timeout


## Enemy i dies: death clip, sink into the ground, burst. HUD fades.
func enemy_die(i: int) -> void:
	if i >= enemies.size():
		return
	var ch := enemies[i]
	var id := String(data[i].get("id", ""))
	var hud := huds[i]
	var ht := hud.create_tween().set_speed_scale(speed)
	ht.tween_method(hud.set_opacity, 1.0, 0.0, 0.3)
	ht.tween_callback(func() -> void: hud.visible = false)
	Audio.play_sfx("death")
	await ch.play_once(EnemyLooks.clip(id, "death"), "")
	var pos := ch.global_position
	Fx.burst(self, pos + Vector3.UP * 0.4, {"amount": 26, "lifetime": 0.9, "speed": Vector2(0.6, 2.2),
		"gravity": Vector3(0, 1.5, 0), "size": 0.34, "color": Color(0.8, 0.75, 1.0, 0.8), "tex": "dot",
		"spread": 60.0})
	var t := ch.create_tween().set_speed_scale(speed)
	t.tween_property(ch, "global_position", pos - Vector3.UP * 1.4, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(ch, "scale", ch.scale * 0.7, 0.5)
	await t.finished
	ch.visible = false
	if target == i:
		for k in enemies.size():
			if enemies[k].visible and int(data[k].get("hp", 0)) > 0:
				set_target(k)
				break


## Hero attacks enemy i. style: melee | magic | ranged | "" (auto from the hero model).
func hero_attack(target_i: int, style := "") -> void:
	if target_i >= enemies.size() or hero == null:
		return
	if style == "":
		style = "magic" if hero.model_id == "mage" else ("ranged" if hero.model_id == "ranger" else "melee")
	var ch := enemies[target_i]
	var home := hero_home
	_face(hero, ch.global_position, 0.12)
	match style:
		"melee":
			var dir := (ch.global_position - home)
			dir.y = 0.0
			var gap := 1.25 * EnemyLooks.scale_of(String(data[target_i].get("id", "")))
			var reach := home + dir.normalized() * maxf(dir.length() - gap, 0.0) * 0.8
			reach.y = home.y
			var t := hero.create_tween().set_speed_scale(speed)
			t.tween_property(hero, "global_position", reach + Vector3.UP * 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			hero.play("Running_A", 0.05)
			await t.finished
			hero.play_once("attack", "idle", 0.05, 1.35)
			Audio.play_sfx("swing")
			await get_tree().create_timer((0.3) / speed, false).timeout
			Fx.slash(self, ch.global_position + Vector3.UP * 0.9 * EnemyLooks.scale_of(String(data[target_i].get("id", ""))),
				(ch.global_position - home).normalized())
			await get_tree().create_timer((0.06) / speed, false).timeout
			_return_hero(0.12)
		"magic", "ranged":
			hero.play_once("attack" if style == "ranged" else "Ranged_Magic_Shoot", "idle", 0.05, 1.2)
			await get_tree().create_timer((0.25) / speed, false).timeout
			var col := Color(0.5, 0.75, 1.0) if style == "magic" else Color(1.0, 0.9, 0.7)
			await Fx.projectile(self, hero_home + Vector3.UP * 1.0 + facing * 0.4,
				ch.global_position + Vector3.UP * 0.9, col, 0.3 / speed)


func _toward_camera(from: Vector3) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.ZERO
	var v := cam.global_position - from
	v.y = 0.0
	return v.normalized()


func _camera_right() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	return cam.global_basis.x if cam else Vector3.RIGHT


func _return_hero(delay: float) -> void:
	var t := hero.create_tween().set_speed_scale(speed)
	t.tween_interval(delay)
	t.tween_property(hero, "global_position", hero_home, 0.28).set_trans(Tween.TRANS_SINE)


## Hero takes damage: hit clip, red number, shake-worthy flash. `blocked` shows a shield.
func hero_hit(amount: int, blocked := 0) -> void:
	if hero == null:
		return
	var top := hero_home + Vector3.UP * 1.4
	if blocked > 0:
		Fx.block_flash(self, hero_home + Vector3.UP * 0.8, 0.85)
		Audio.play_sfx("block")
		if amount <= 0:
			Fx.popup_text(self, top + Vector3.UP * 0.5, "BLOCK", Fx.BLOCK_COLOR, 0.8)
	if amount > 0:
		Fx.hit_sparks(self, top - Vector3.UP * 0.3, Color(1.0, 0.45, 0.35), 16)
		Fx.damage_number(self, top + Vector3.UP * 0.5, amount, false, Fx.HERO_DAMAGE_COLOR)
		Audio.play_sfx("hit")
		hero.play_once("hit", "idle", 0.05)
		var cam := get_viewport().get_camera_3d()
		var rig := cam.get_parent() as CameraRig if cam else null
		if rig:
			rig.shake(clampf(float(amount) / 15.0, 0.25, 0.9), 0.3)
	await get_tree().create_timer((0.35) / speed, false).timeout


## Removes every enemy, HUD and marker and returns the hero home.
func clear() -> void:
	for e in enemies:
		e.queue_free()
	for h in huds:
		h.queue_free()
	enemies.clear()
	huds.clear()
	data.clear()
	if _target_ring:
		_target_ring.queue_free()
		_target_ring = null
	if _arena_mi:
		_arena_mi.queue_free()
		_arena_mi = null
	if hero and is_instance_valid(hero):
		hero.global_position = hero_home if hero_home != Vector3.ZERO else hero.global_position


func _face(ch: Node3D, at: Vector3, time: float) -> void:
	var d := at - ch.global_position
	d.y = 0.0
	if d.length() < 0.01:
		return
	var yaw := atan2(d.x, d.z)
	if time <= 0.0:
		ch.rotation.y = yaw
		return
	var cur := ch.rotation.y
	var t := ch.create_tween().set_speed_scale(speed)
	t.tween_property(ch, "rotation:y", cur + wrapf(yaw - cur, -PI, PI), time)


func _flash_white(ch: Character, id: String) -> void:
	EnemyLooks.retint(ch, id, Color(0.9, 0.85, 0.8))
	var t := ch.create_tween().set_speed_scale(speed)
	t.tween_interval(0.08)
	t.tween_callback(func() -> void:
		if is_instance_valid(ch):
			EnemyLooks.retint(ch, id))


var _arena_mi: MeshInstance3D


## Faint magic circle under the enemy line-up that anchors the fight on the floor.
func _arena() -> void:
	_arena_mi = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6.4, 6.4)
	_arena_mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = preload("res://game/world/shaders/rune_circle.gdshader")
	m.set_shader_parameter("color", Color(1.0, 0.45, 0.35))
	m.set_shader_parameter("intensity", 0.0)
	m.set_shader_parameter("speed", 0.08)
	_arena_mi.material_override = m
	_arena_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_arena_mi)
	var c := hero_home + facing * (_distance + 0.2)
	_arena_mi.global_position = Vector3(c.x, _ground_y + 0.02, c.z)
	var t := _arena_mi.create_tween().set_speed_scale(speed)
	t.tween_method(func(v: float) -> void: m.set_shader_parameter("intensity", v), 0.0, 0.55, 0.6)


func _blob(r: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(r * 2.0, r * 2.0) / UNIT_SCALE
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = Props.particle_texture("dot")
	m.albedo_color = Color(0, 0, 0, 0.45)
	mi.material_override = m
	mi.position.y = 0.02
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
