class_name PetHost
extends Node
## Keeps the run's pet familiar (PetView) in the world next to the hero: it spawns the pet
## for the flow's run (and rebuilds it when the run or pet changes), floats it at the hero's
## camera-left shoulder on the board (lagging behind hops) and beside the hero's home spot in
## combat, clear of the enemy line, and plays pet_acted actions for MetaBeats.
##
##   pets = PetHost.new(controller); controller.add_child(pets)

const BOARD_SCALE := 1.6
const COMBAT_SCALE := 1.3

var c: GameController
var view: PetView

var _key := ""
var _flow: GameFlow
var _t := 0.0


func _init(ctrl: GameController) -> void:
	c = ctrl
	name = "PetHost"


func _process(dt: float) -> void:
	_t += dt
	var f: GameFlow = c.flow if c.mode == "run" else null
	var id := f.run.pet_id() if f else ""
	var key := "%s:%d" % [id, f.run.pet_level()] if id != "" else ""
	if key != _key or f != _flow:
		_rebuild(f, id, key)
	if view == null:
		return
	view.speed = c.speed
	var hero := c.board.hero if c.board else null
	view.visible = hero != null and hero.is_visible_in_tree()
	if hero == null:
		return
	view.home = home_position()
	# the board camera sits far back: a bigger familiar there, a smaller one in fights
	var want := BOARD_SCALE if not c.in_combat else COMBAT_SCALE
	if not is_equal_approx(view.scale.x, want):
		view.scale = view.scale.lerp(Vector3.ONE * want, minf(1.0, dt * 4.0))
	# keep the meter honest once playback is over (condensed beats, loads)
	if not c.busy and f:
		var ch := int(f.run.pet_state.get("charge", 0))
		if ch != view.charge:
			view.set_charge(ch, PetDefs.size(id), false)


func _rebuild(f: GameFlow, id: String, key: String) -> void:
	_key = key
	_flow = f
	if view:
		view.queue_free()
		view = null
	if id == "" or f == null:
		return
	view = PetView.create(id, f.run.pet_level())
	view.name = "PetFamiliar"
	c.world.add_child(view)
	view.set_charge(int(f.run.pet_state.get("charge", 0)), PetDefs.size(id))
	view.follow = true
	view.scale = Vector3.ONE * (COMBAT_SCALE if c.in_combat else BOARD_SCALE)
	if c.board and c.board.hero:
		view.home = home_position()
		view.snap()


## Where the pet floats now: at the hero's shoulder on the camera's left (board), or beside
## the hero's fight spot, on the side away from the enemy line (combat).
func home_position() -> Vector3:
	var cam := c.rig.camera
	var right := cam.global_basis.x
	right.y = 0.0
	right = right.normalized() if right.length() > 0.01 else Vector3.RIGHT
	var back := cam.global_basis.z
	back.y = 0.0
	back = back.normalized() if back.length() > 0.01 else Vector3.BACK
	var orbit := right * cos(_t * 0.9) * 0.1 + back * sin(_t * 0.9) * 0.1
	if c.in_combat and c.stage.hero:
		var base := c.stage.hero_home
		# the enemy line sits toward screen-right; the pet goes left of the hero, a bit toward
		# the camera, so it never covers the hero or an enemy
		# (portrait frames the hero near the left edge: tuck the pet closer in)
		var side := 0.62 if c.rig.is_portrait() else 0.75
		return base - right * side + back * 0.6 + orbit
	return c.board.hero.global_position - right * 0.85 + back * 0.35 + orbit


## World point of enemy `i` (body height) in the current fight, or the hero's.
func target_point(target: Variant) -> Vector3:
	if target is int or target is float:
		var i := int(target)
		if c.in_combat and i >= 0 and i < c.stage.enemy_count():
			return c.stage.enemy_position(i) + Vector3.UP * 0.9
	elif String(target) == "all" and c.in_combat and c.flow and c.flow.combat:
		var ti := c.flow.combat.target
		if ti >= 0 and ti < c.stage.enemy_count():
			return c.stage.enemy_position(ti) + Vector3.UP * 0.9
	return c.hero_pos() + Vector3.UP * 0.9


## Screen point just above the pet (or the hero when there is no pet).
func screen_point(height := 0.6) -> Vector2:
	var p := view.body_position() if view else c.hero_pos() + Vector3.UP * 1.6
	return c.rig.camera.unproject_position(p + Vector3.UP * height)
