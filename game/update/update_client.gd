extends Node
## Check + download pipeline (no gating, no UI, no relaunch): fetch manifest + signature,
## verify, validate, decide, and for a content update download + verify the pack into
## staged/. The Updater autoload drives it; tests drive it directly with a local feed.
##
##   var client := UpdateClient.new(store)     # preload("res://game/update/update_client.gd")
##   add_child(client)
##   var r: Dictionary = await client.check({"base_url": ..., "channel": "stable",
##       "public_key": pem, "distribution": "github", "platform": ..., "engine": ...,
##       "version": ..., "binary_version": ...})
##   # r: {"ok", "error", "decision" (see UpdatePolicy.decide), "manifest"}

signal download_progress(done: int, total: int)

const Manifest := preload("res://game/update/update_manifest.gd")
const Policy := preload("res://game/update/update_policy.gd")
const Fetcher := preload("res://game/update/update_fetcher.gd")
const Store := preload("res://game/update/update_store.gd")

var store: Store
var fetcher: Fetcher
var busy := false


func _init(p_store: Store = null) -> void:
	store = p_store if p_store else Store.new()
	fetcher = Fetcher.new()
	fetcher.name = "Fetcher"
	add_child(fetcher)
	fetcher.progress.connect(func(d: int, t: int) -> void: download_progress.emit(d, t))


## ctx: base_url, channel, public_key (PEM) + the UpdatePolicy.decide() context keys.
## ctx.download=false only decides (no pack download).
func check(ctx: Dictionary) -> Dictionary:
	if busy:
		return _fail("check already running")
	busy = true
	var r: Dictionary = await _check(ctx)
	busy = false
	return r


func _check(ctx: Dictionary) -> Dictionary:
	var channel := String(ctx.get("channel", "stable"))
	var base := String(ctx.get("base_url", Policy.base_url()))
	var url := Fetcher.join(base, Policy.manifest_name(channel))
	var body: Dictionary = await fetcher.fetch(url)
	if not body["ok"]:
		return _fail(body["error"])
	var sig: Dictionary = await fetcher.fetch(url + ".sig")
	if not sig["ok"]:
		return _fail(sig["error"])
	var data: PackedByteArray = body["body"]
	if not Manifest.verify_signature(data, (sig["body"] as PackedByteArray).get_string_from_utf8(),
			String(ctx.get("public_key", ""))):
		return _fail("manifest signature invalid")
	var parsed := Manifest.parse(data, channel)
	if not parsed["ok"]:
		return _fail(parsed["error"])
	var m: Dictionary = parsed["manifest"]
	var dctx := ctx.duplicate()
	dctx["staged_version"] = store.slot_version("staged")
	dctx["skip_version"] = String(store.get_state("skip_version", ""))
	var d := Policy.decide(m, dctx)
	var out := {"ok": true, "error": "", "decision": d, "manifest": m}
	if d["action"] == Policy.PACK and ctx.get("download", true):
		var dl: Dictionary = await download_pack(m, base)
		if not dl["ok"]:
			out["ok"] = false
			out["error"] = dl["error"]
		else:
			d["action"] = Policy.READY
	return out


## Downloads manifest.pack to staged/diceroll.pck.part, verifies size + sha256, renames it
## into place and writes staged/meta.json.
func download_pack(m: Dictionary, base: String) -> Dictionary:
	var pack: Dictionary = m["pack"]
	var part := store.begin_staging()
	var r: Dictionary = await fetcher.download(Fetcher.join(base, String(pack["url"])), part)
	if not r["ok"]:
		DirAccess.remove_absolute(part)
		return r
	return store.finish_staging(part, {"version": m["version"], "sha256": pack["sha256"],
		"size": pack["size"], "engine": m["engine"]})


static func _fail(msg: String) -> Dictionary:
	return {"ok": false, "error": msg, "decision": {"action": Policy.NONE}, "manifest": {}}
