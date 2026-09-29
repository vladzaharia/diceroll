extends Node
## Audio autoload (`Audio`). Creates the Music and SFX buses in code, plays pooled
## one-shot SFX by id (random variant + pitch jitter) and cross-fades music beds.
## Volumes (linear 0..1) persist in user://settings.cfg, section "audio".
##
##   Audio.play_sfx("dice_roll")
##   Audio.play_music("act1")
##   Audio.set_volume("Music", 0.6)

const SETTINGS_PATH := "user://settings.cfg"
const BUSES := ["Master", "Music", "SFX"]
const POOL_SIZE := 12

const S := "res://assets/audio/sfx/"
const CASINO := S + "casino-audio/"
const IMPACT := S + "impact-sounds/"
const UI := S + "interface-sounds/"
const RPG := S + "rpg-audio/"
const JINGLE := S + "music-jingles/"
const DIGI := S + "digital-audio/"

## id -> [files (a random one plays), volume_db]
const SFX := {
	"dice_roll": [[CASINO + "dice-throw-1.ogg", CASINO + "dice-throw-2.ogg", CASINO + "dice-throw-3.ogg"], 0.0],
	"dice_shake": [[CASINO + "dice-shake-1.ogg", CASINO + "dice-shake-2.ogg", CASINO + "dice-shake-3.ogg"], -2.0],
	"dice_land": [[CASINO + "die-throw-1.ogg", CASINO + "die-throw-2.ogg", CASINO + "die-throw-3.ogg", CASINO + "die-throw-4.ogg"], -3.0],
	"dice_select": [[CASINO + "chip-lay-1.ogg", CASINO + "chip-lay-2.ogg", CASINO + "chip-lay-3.ogg"], -2.0],
	"step": [[IMPACT + "footstep_wood_000.ogg", IMPACT + "footstep_wood_001.ogg", IMPACT + "footstep_wood_002.ogg", IMPACT + "footstep_wood_003.ogg", IMPACT + "footstep_wood_004.ogg"], -4.0],
	"coin": [[RPG + "handleCoins.ogg", RPG + "handleCoins2.ogg"], -1.0],
	"hit": [[IMPACT + "impactPunch_medium_000.ogg", IMPACT + "impactPunch_medium_001.ogg", IMPACT + "impactPunch_medium_002.ogg", IMPACT + "impactPunch_medium_003.ogg"], 0.0],
	"crit": [[IMPACT + "impactPunch_heavy_000.ogg", IMPACT + "impactPunch_heavy_001.ogg", IMPACT + "impactPunch_heavy_002.ogg"], 1.0],
	"block": [[IMPACT + "impactMetal_heavy_000.ogg", IMPACT + "impactMetal_heavy_001.ogg", IMPACT + "impactMetal_heavy_002.ogg"], -3.0],
	"swing": [[RPG + "knifeSlice.ogg", RPG + "knifeSlice2.ogg", RPG + "drawKnife1.ogg"], -3.0],
	"death": [[IMPACT + "impactSoft_heavy_000.ogg", IMPACT + "impactSoft_heavy_001.ogg"], 0.0],
	"drum": [[IMPACT + "impactSoft_heavy_000.ogg", IMPACT + "impactSoft_heavy_001.ogg", IMPACT + "impactWood_heavy_000.ogg"], 1.0],
	"heal": [[DIGI + "powerUp2.ogg"], -6.0],
	"buff": [[DIGI + "powerUp7.ogg"], -6.0],
	"levelup": [[JINGLE + "jingles_PIZZI10.ogg"], -2.0],
	"click": [[UI + "click_001.ogg", UI + "click_002.ogg", UI + "click_003.ogg"], -4.0],
	"open": [[UI + "open_001.ogg", UI + "open_002.ogg"], -4.0],
	"close": [[UI + "close_001.ogg", UI + "close_002.ogg"], -4.0],
	"error": [[UI + "error_004.ogg"], -4.0],
	"page": [[RPG + "bookFlip1.ogg", RPG + "bookFlip2.ogg", RPG + "bookFlip3.ogg"], -3.0],
	"win": [[JINGLE + "jingles_PIZZI00.ogg"], -1.0],
	"lose": [[JINGLE + "jingles_SAX04.ogg"], -1.0],
	"fanfare": [[JINGLE + "jingles_STEEL00.ogg"], -2.0],
	"portal": [[DIGI + "phaseJump1.ogg", DIGI + "zapThreeToneUp.ogg"], -6.0],
	"trap": [[IMPACT + "impactMining_000.ogg", IMPACT + "impactMining_001.ogg", IMPACT + "impactMining_002.ogg"], -1.0],
	"chest": [[RPG + "creak1.ogg", RPG + "creak2.ogg", RPG + "metalLatch.ogg"], -2.0],
	# minigames (ui/minigames)
	"dig": [[IMPACT + "impactMining_003.ogg", IMPACT + "impactMining_004.ogg", IMPACT + "footstep_snow_000.ogg"], -3.0],
	"clink": [[IMPACT + "impactPlate_light_000.ogg", IMPACT + "impactPlate_light_001.ogg", IMPACT + "impactPlate_light_002.ogg"], -4.0],
	"pop": [[UI + "drop_001.ogg", UI + "drop_002.ogg", UI + "drop_003.ogg", UI + "drop_004.ogg"], -2.0],
	"scratch": [[UI + "scratch_001.ogg", UI + "scratch_002.ogg", UI + "scratch_003.ogg", UI + "scratch_004.ogg", UI + "scratch_005.ogg"], -3.0],
	"reveal": [[UI + "confirmation_001.ogg", UI + "confirmation_002.ogg"], -5.0],
	"tick": [[UI + "tick_001.ogg", UI + "tick_002.ogg", UI + "tick_004.ogg"], -4.0],
	"claw": [[RPG + "metalClick.ogg"], -2.0],
	"fwump": [[IMPACT + "impactSoft_medium_000.ogg", IMPACT + "impactSoft_medium_001.ogg", IMPACT + "impactSoft_medium_002.ogg"], -3.0],
	"whirr": [[UI + "maximize_003.ogg", UI + "maximize_006.ogg"], -6.0],
}

const M := "res://assets/audio/music/"
const MUSIC := {
	"title": M + "mixkit-zanarkand-forest-169.mp3",
	"act1": M + "mixkit-spirit-in-the-woods-2-147.mp3",
	"act2": M + "mixkit-ambient-251.mp3",
	"act3": M + "mixkit-vastness-184.mp3",
	"calm": M + "mixkit-nature-meditation-345.mp3",
	# biome beds (by BiomeDefs id)
	"glade": M + "mixkit-nature-meditation-345.mp3",
	"crypt": M + "mixkit-spirit-in-the-woods-2-147.mp3",
	"hollow": M + "mixkit-ambient-251.mp3",
	"frost": M + "mixkit-zanarkand-forest-169.mp3",
	"throne": M + "mixkit-vastness-184.mp3",
	"magma": M + "mixkit-vastness-184.mp3",
}
const MUSIC_DB := -8.0

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _streams: Dictionary = {}  # path -> AudioStream
var _music: Array[AudioStreamPlayer] = []
var _music_idx := 0
var _music_id := ""
var _music_tween: Tween
var _volumes := {"Master": 1.0, "Music": 0.8, "SFX": 0.9}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		_music.append(p)
	_load_settings()


func _exit_tree() -> void:
	stop_all()


## Stops every sound and drops cached streams (call a few frames before quitting so the
## mixer releases its playbacks; otherwise Godot reports leaked AudioStream instances).
func stop_all() -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_id = ""
	for p in _pool + _music:
		p.stop()
		p.stream = null
	_streams.clear()


## Plays a one-shot SFX by id. Unknown ids warn and do nothing.
func play_sfx(id: String, pitch_var := 0.05, volume_db := 0.0) -> void:
	if not SFX.has(id):
		push_warning("Audio: unknown sfx id '%s'" % id)
		return
	var def: Array = SFX[id]
	var files: Array = def[0]
	var stream := _stream(files[randi() % files.size()])
	if stream == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = stream
	p.volume_db = def[1] + volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


## Cross-fades to a music bed by id (see MUSIC). Same id already playing: no-op.
func play_music(id: String, fade := 1.0) -> void:
	if id == _music_id:
		return
	if not MUSIC.has(id):
		push_warning("Audio: unknown music id '%s'" % id)
		return
	var stream := _stream(MUSIC[id])
	if stream == null:
		return
	if "loop" in stream:
		stream.loop = true
	_music_id = id
	var old := _music[_music_idx]
	_music_idx = 1 - _music_idx
	var cur := _music[_music_idx]
	cur.stream = stream
	cur.volume_db = -40.0 if fade > 0.0 else MUSIC_DB
	cur.play()
	_crossfade(old, cur, fade)


func stop_music(fade := 1.0) -> void:
	_music_id = ""
	_crossfade(_music[_music_idx], null, fade)


func current_music() -> String:
	return _music_id


## bus: "Master" | "Music" | "SFX"; value linear 0..1. Persisted.
func set_volume(bus: String, value: float) -> void:
	if not _volumes.has(bus):
		push_warning("Audio: unknown bus '%s'" % bus)
		return
	_volumes[bus] = clampf(value, 0.0, 1.0)
	_apply_volume(bus)
	_save_settings()


func get_volume(bus: String) -> float:
	return _volumes.get(bus, 1.0)


func set_master_volume(value: float) -> void:
	set_volume("Master", value)


func set_music_volume(value: float) -> void:
	set_volume("Music", value)


func set_sfx_volume(value: float) -> void:
	set_volume("SFX", value)


func _crossfade(old: AudioStreamPlayer, cur: AudioStreamPlayer, fade: float) -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	if fade <= 0.0:
		if old and old != cur:
			old.stop()
		if cur:
			cur.volume_db = MUSIC_DB
		return
	_music_tween = create_tween().set_parallel(true)
	if old and old != cur and old.playing:
		_music_tween.tween_property(old, "volume_db", -60.0, fade)
		_music_tween.chain().tween_callback(old.stop)
	if cur:
		_music_tween.tween_property(cur, "volume_db", MUSIC_DB, fade).set_trans(Tween.TRANS_SINE)


func _stream(path: String) -> AudioStream:
	if not _streams.has(path):
		var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if s == null:
			push_warning("Audio: missing stream %s" % path)
		_streams[path] = s
	return _streams[path]


func _apply_volume(bus: String) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	var v: float = _volumes[bus]
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(i, v <= 0.001)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for b in _volumes:
			_volumes[b] = clampf(float(cfg.get_value("audio", b.to_lower(), _volumes[b])), 0.0, 1.0)
	for b in _volumes:
		_apply_volume(b)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # keep other sections (game speed etc.)
	for b in _volumes:
		cfg.set_value("audio", b.to_lower(), _volumes[b])
	cfg.save(SETTINGS_PATH)
