extends Node
## One small fetch abstraction for update files: http(s) via HTTPRequest, or local files
## (absolute path, file:// URL, res:// / user://) for dev fixtures and tests. No class_name.
##
##   var r: Dictionary = await fetcher.fetch(url)                 # {"ok", "body", "error"}
##   var r: Dictionary = await fetcher.download(url, dest_path)   # {"ok", "error"}; emits progress
##
## Local sources complete synchronously (the awaits return immediately), which keeps the
## headless tests free of frames and network.

signal progress(done: int, total: int)

const MANIFEST_LIMIT := 1 << 20
const TIMEOUT := 30.0
const CHUNK := 1 << 20

## Extra request headers (e.g. "Authorization: Bearer ..." from DICEROLL_UPDATE_TOKEN).
var headers: PackedStringArray = []


static func is_local(url: String) -> bool:
	if url.begins_with("file://") or url.begins_with("res://") or url.begins_with("user://"):
		return true
	if url.begins_with("/"):
		return true
	return url.length() > 2 and url[1] == ":" and (url[2] == "/" or url[2] == "\\")


## Local filesystem path for a local URL.
static func local_path(url: String) -> String:
	if url.begins_with("file://"):
		return url.substr(7).uri_decode()
	return url


## Resolves `ref` against `base` (a directory URL/path) unless it is already absolute.
static func join(base: String, ref: String) -> String:
	if ref.contains("://") or is_local(ref):
		return ref
	return base.trim_suffix("/") + "/" + ref


func fetch(url: String) -> Dictionary:
	if is_local(url):
		var p := local_path(url)
		if not FileAccess.file_exists(p):
			return {"ok": false, "body": PackedByteArray(), "error": "not found: " + p}
		return {"ok": true, "body": FileAccess.get_file_as_bytes(p), "error": ""}
	var req := _request()
	req.body_size_limit = MANIFEST_LIMIT
	var err := req.request(url, headers)
	if err != OK:
		req.queue_free()
		return {"ok": false, "body": PackedByteArray(), "error": "request failed: " + error_string(err)}
	var res: Array = await req.request_completed
	req.queue_free()
	return _result(res, url)


func download(url: String, dest: String) -> Dictionary:
	if is_local(url):
		return _copy_local(local_path(url), dest)
	var req := _request()
	req.timeout = 0.0  # large file; the stall watchdog below handles dead connections
	req.download_file = dest
	var err := req.request(url, headers)
	if err != OK:
		req.queue_free()
		return {"ok": false, "error": "request failed: " + error_string(err)}
	var done := [false, []]
	req.request_completed.connect(func(a: int, b: int, c: PackedStringArray, d: PackedByteArray) -> void:
		done[0] = true
		done[1] = [a, b, c, d])
	var last := -1
	var stalled := 0.0
	while not done[0]:
		await get_tree().create_timer(0.25, true, false, true).timeout
		var got := req.get_downloaded_bytes()
		progress.emit(got, maxi(req.get_body_size(), 0))
		stalled = 0.0 if got != last else stalled + 0.25
		last = got
		if stalled > TIMEOUT:
			req.cancel_request()
			req.queue_free()
			return {"ok": false, "error": "download stalled"}
	req.queue_free()
	var r := _result(done[1], url)
	return {"ok": r["ok"], "error": r["error"]}


func _request() -> HTTPRequest:
	var req := HTTPRequest.new()
	req.use_threads = true
	req.timeout = TIMEOUT
	req.max_redirects = 10  # GitHub release assets redirect to a CDN
	add_child(req)
	return req


static func _result(res: Array, url: String) -> Dictionary:
	var result: int = res[0]
	var code: int = res[1]
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "body": PackedByteArray(), "error": "http result %d for %s" % [result, url]}
	if code < 200 or code >= 300:
		return {"ok": false, "body": PackedByteArray(), "error": "http %d for %s" % [code, url]}
	return {"ok": true, "body": res[3], "error": ""}


func _copy_local(src: String, dest: String) -> Dictionary:
	var i := FileAccess.open(src, FileAccess.READ)
	if i == null:
		return {"ok": false, "error": "not found: " + src}
	var o := FileAccess.open(dest, FileAccess.WRITE)
	if o == null:
		return {"ok": false, "error": "cannot write " + dest}
	var total := i.get_length()
	var left := total
	while left > 0:
		var n := mini(CHUNK, left)
		o.store_buffer(i.get_buffer(n))
		left -= n
		progress.emit(total - left, total)
	return {"ok": true, "error": ""}
