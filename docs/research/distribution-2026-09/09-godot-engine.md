# 09: Godot engine research for Diceroll content packs (Godot 4.7.2)

Date: 2026-09-29. Engine under test: `godot --version` = `4.7.2.stable.official.ed1daf0bf` (headless, Linux x86_64, 4 vCPU Intel Xeon @ 2.1 GHz VM, OpenSSL 3.0.13).
Source reading: `godotengine/godot` tag `4.7.2-stable`, plus `master` (4.8-dev; dev7 was published today, "feature freeze").

Legend: **[V-exp]** verified by an experiment in this session. **[V-src]** verified by reading 4.7.2 engine source or the class reference. **[V-doc]** stated in official docs or blog. **[U]** uncertain, inferred, or taken from a secondary source.

Experiment workspace (throwaway): a throwaway scratch project (not kept)

- `core/`: the "core game" project (`defs/weapon_def.gd` = `class_name WeaponDef extends Resource`)
- `content_a/`, `content_b/`, `content_evil/`: content-authoring projects. Their import cache (`.godot/imported`) is the pack source.
- `core/tools/build_pack.gd`: headless PCKPacker builder for data-only packs
- `core/tests/t_*.gd`: experiments. `core/crypto/*.gd`: pure-GDScript SHA-512 and Ed25519 prototypes.
- `pckls.py` / `pckutil.py`: a Python PCK v4 lister and writer, used for header experiments.

---

## 0. Executive summary (the outcomes that matter)

| Topic | Outcome |
|---|---|
| Script injection from a pack `.tres` | **[V-exp] Yes: code runs on `load()`.** A `.tres` with `[sub_resource type="GDScript"]` + `script/source` runs `_static_init`, `_init`, and property setters during `ResourceLoader.load()`. It wrote a file to `user://`. A `.tres` whose `ext_resource` points to a `.gd` shipped in the same pack also runs. A `.tscn` with an embedded script runs on `instantiate()`. There is no ResourceLoader flag to block scripts. The same holds in `--main-pack` (exported-like) mode. |
| Other "data" parsers | **[V-exp] `str_to_var()` and `ConfigFile.parse()` also run code**: `Object(Resource,"script":Resource("res://mods/evil.gd"))` ran `_init`. **`JSON.parse_string()` is safe** (it returns only primitives, and all numbers come back as float). `JSON.to_native(x, false)` and `bytes_to_var()` refuse objects. |
| Crypto.verify | **[V-exp]** Works: RSA PKCS#1 v1.5 (SHA-256), ECDSA P-256/SHA-256 (DER signature only), ECDSA secp256k1. Fails: RSA-PSS (verify returns false), RSA-PSS key type (key load error -15488), **Ed25519 and Ed448 (the key does not even load: `Error parsing key '-15488'`, mbedTLS 3.6.7 has no EdDSA)**, ES384 (no SHA-384 in `HashingContext`). A JWS ES256 raw `r‖s` signature must be re-encoded to DER first. The GDScript helper for that is tested. |
| Ed25519 in GDScript | **[V-exp] A pure-GDScript Ed25519 verify (TweetNaCl port + GDScript SHA-512) works**, checked against an OpenSSL signature. Naive version: 233 ms per verify. With the field multiply unrolled: **~74 ms per verify** on this VM. GDScript SHA-512 runs at 2.2 MB/s. The alternatives are the GDExtension `freehuntx/gd-ed25519` (Monocypher; lists Linux, Win, mac, Android, iOS, Web) and WebCrypto Ed25519 on Web. |
| Pack override | **[V-exp]** `replace_files=false` means first mounted wins. The core files (main pack or project dir) can never be overridden. `true` means last mounted wins. |
| Resource cache | **[V-exp]** After mounting an overriding pack, `load()` (REUSE) still returns the old cached object. `CACHE_MODE_REPLACE` updates the *held* object in place but keeps old sub-dependencies. `REPLACE_DEEP` also refreshes dependencies. |
| Unload | **[V-src] No unload API in 4.7 or in master.** **[V-exp] Workaround:** a runtime-built "tombstone" pack (`PCKPacker.add_file_removal`) hides files, but cannot restore a shadowed earlier version. |
| UIDs in PCKPacker packs | **[V-exp]** A pack's `uid://` references do not resolve by default. With `replace_files=false`, the pack's `uid_cache.bin` is shadowed by the core's copy, and at runtime `ResourceLoader.get_resource_uid()` only consults the in-memory cache. Text `ext_resource` falls back to `path=` with a warning. `ResourceUID.add_id()` from a per-pack uid map fixes this (verified). |
| Mount cost | **[V-exp]** About 3 µs per file entry: 5k files in 14–22 ms, 50k in 140–170 ms. **Each mount also re-reads the whole `res://.godot/uid_cache.bin` and the global class cache.** With 20k UIDs + 300 classes that is **~9–10 ms per mount** (50 packs = 450–530 ms). With a tiny cache it is 0.3 ms per pack. |
| Delta patches (4.6+) | **[V-exp]** A zstd "patch-from" per file, flagged `DELTA` in the PCK. A one-line change in a 592 KB JSON produced a **416-byte patch PCK**. **Requires the exact base bytes mounted underneath at runtime.** Without the base: file reads as empty. Wrong base: zstd checksum error and a 0-length read. PCKPacker cannot write delta entries; only the editor export (`--export-patch`) can. |
| Version gating | **[V-exp]** Header minor 8 is rejected by 4.7: `Pack created with a newer version of the engine: 4.8.x`. An older minor is accepted. Pack format v5 is rejected. **[V-src]** The PCK, binary-resource (v6), text-resource (v4/compat 3) and ctex (v1) versions and all pack code are identical between 4.7.2 and master (4.8-dev). |

---

## 1. Resource packs in 4.7

### 1.1 API and semantics [V-src, V-exp]

```gdscript
ProjectSettings.load_resource_pack(pack: String, replace_files: bool = true, offset: int = 0) -> bool
```

- Accepts `.pck` or `.zip`. `offset` applies to `.pck` only. A self-contained executable with a non-zero offset is refused.
- **Paths:** any path `FileAccess` can open works.
  - [V-exp] `user://packs/x.pck`, absolute OS paths, and **a `.pck` stored inside another mounted pack** (`res://packs/pack_a.pck`) all mounted fine.
  - [V-exp] Missing files and garbage files return `false` without crashing.
- **offset** [V-exp]: I prepended 4096 junk bytes (for example a signature block) to a PCK. `offset=0` returns false; `offset=4096` returns true and the content loads. This makes a "signed envelope + PCK" single-file format possible.
- **Override rules** [V-src `PackedData::add_path`, V-exp]:
  - An entry is inserted if the path is new, or if `replace_files` is true.
  - The main pack (or the project directory when not exported) is mounted first with `replace=false`.

  Experiment (`t_mount.gd noreplace|replace`):

  ```
  noreplace: mount A(false), B(false) -> sword.tres = "sword (A)" 64x64 icon; manifest.json = A; axe.tres/b_only.json (B-only) available
  replace:   mount A(false), B(true)  -> sword.tres = "sword (B)" 32x32 icon; manifest.json = B
  ```

  Consequence: with `replace_files=false`, **no pack can shadow any core file**. Collisions between content packs resolve by mount order: the first one wins.
- **Imported asset collisions:** the imported file name is `<file>-<md5(res path)>.ctex`, so two packs that both contain `res://content/weapons/sword.png` produce the **same** `.godot/imported/sword.png-6a35….ctex` path. That is fine, because the override is consistent. Namespace content per pack (for example `res://content/<pack_id>/…`) to avoid accidental collisions.
- **DirAccess** [V-exp]: after a mount, `DirAccess.get_files_at("res://content")` **does** list files from the pack, in both project-dir mode and `--main-pack` mode. The class-ref note "DirAccess will not show changes made to res://" did not reproduce. `ResourceLoader.list_directory()` also merges and strips `.import`/`.remap`.
- **The pack file is not held open** [V-src `FileAccessPack` ctor, V-exp]. Every file read re-opens the `.pck`. Deleting a mounted pack made later reads fail (`Can't open pack-referenced file … File not found`). **Never overwrite a mounted pack in place.** Write updates to new, content-addressed file names and switch on the next boot.
- **First-mount directory scan** [V-src `_load_resource_pack`, V-exp]:
  - When there is no main pack (running from a project dir, or the editor), the first `load_resource_pack` call registers `res://` as a `PackedSourceDirectory` and recursively scans the whole project tree. It ignores `.gdignore`.
  - Measured: 20k files gave a 60 ms first mount, against 0.5 ms for the small core.
  - This landed in 4.4 [V-src] and matches the Android regression in **godot#105009** ("load_resource_pack hangs UI on Android", still **open**, no linked PR [V-doc: GitHub page]).
  - Since **4.5**, Android exports mount `res://assets.sparsepck` as the main pack at startup [V-src], so `using_datapack` is already true and the scan should not happen on 4.5+ exports. **[U]** Not device-tested.
- **Unloading** [V-src]: there is no `unload_resource_pack` in 4.7 or master. `PackedData::clear()` exists but is internal, used only by the editor's patch exporter. Workarounds:
  1. A tombstone pack [V-exp]: `PCKPacker.add_file_removal(path)` (present since ≥4.4) writes `PACK_FILE_REMOVAL` entries. Mounting such a pack removes the paths from the index. `FileAccess.file_exists`, `ResourceLoader.exists` and `DirAccess` all stop seeing them. It **cannot restore** a lower-priority version.
  2. Restart the game to re-mount a different set. This is the cleanest approach for "disable DLC".

### 1.2 Mount timing [V-exp]

Setup: `gen_bulk.gd` builds packs of N JSON files with `add_file_from_buffer`, and `t_mount.gd timing` mounts them. Three runs each:

| Case | Mount time |
|---|---|
| 1 pack × 5,000 files | 13.7–21.9 ms |
| 1 pack × 50,000 files | 139–170 ms |
| 50 packs × 100 files (tiny core caches) | 16.5–17.4 ms (~0.33 ms/pack) |
| 50 packs × 100 files, main pack with **20k-entry uid_cache.bin + 300 global classes** | **452–533 ms (9–10.7 ms/pack)** |
| same, only the 20k uid cache | 372 ms (7.4 ms/pack) |
| same, only the 300-class cache | 145 ms (2.9 ms/pack) |
| read+parse 200 JSON defs from a mounted pack | 5–8 ms |

**Why [V-src]:** after every successful mount, `_load_resource_pack` calls `refresh_global_class_list()` (re-reads `res://.godot/global_script_class_cache.cfg`) and `ResourceUID::load_from_cache(false)` (re-reads the whole `res://.godot/uid_cache.bin`).

**Recommendations:**
- Keep the number of packs mounted at boot moderate (tens, not hundreds), or keep the core's UID and class caches small.
- Expect mobile to be 2–5× slower **[U]**.

### 1.3 PCK format 4.7 [V-src, V-exp]

- Magic `GDPC`, `PACK_FORMAT_VERSION` **4**. The reader accepts v2, v3 and v4.
- Header: engine major, minor and patch of the *writer*; flags (`PACK_DIR_ENCRYPTED`, `PACK_REL_FILEBASE`, `PACK_SPARSE_BUNDLE`); file base; directory offset; and a 16×u32 reserved block (V4 adds a 32-byte salt for encrypted sparse bundles).
- Directory entries: path, offset, size, md5, and flags (`ENCRYPTED`, `REMOVAL`, `DELTA`).
- Data comes first and the directory sits at the end.
- **No compression inside PCK.** ZIP packs are supported and deflate-compressed. [V-exp] A `.zip` equivalent of pack_b mounted and loaded `.tres`, `.ctex` and `.json`.
- The per-file md5 is **not** verified on read [V-src]. Do integrity checking yourself: SHA-256 of the whole pack file before mounting.
- Rejection rules [V-exp with patched headers]:
  - Pack minor > engine minor: rejected (`Pack created with a newer version of the engine: 4.8.2.`).
  - Older minor: accepted.
  - Format 5: rejected (`Pack version unsupported: 5.`).

### 1.4 PCKPacker API (4.7) [V-src]

```gdscript
var p := PCKPacker.new()
p.pck_start(path, alignment := 32, key := "0"*64, encrypt_directory := false)
p.add_file(target_res_path, source_path, encrypt := false)
p.add_file_from_buffer(target_res_path, bytes, encrypt := false)  # handy for generated manifests
p.add_file_removal(target_res_path)                               # tombstone
p.flush(verbose := false)
```

- The header records the version of the engine running the packer. **Build packs with the same minor version as the oldest runtime you ship to.**
- Encryption uses the AES key compiled into the export template (`script_encryption_key`). It is only useful with custom-built templates and is not a security boundary.
- **Alignment and deltas** [V-exp]:

  | Pack | Size |
  |---|---|
  | 5k small JSON files, align 1 | 1.72 MB |
  | same, align 32 | 1.78 MB |
  | same, align 4096 | **20.8 MB** (padding) |

  Alignment only matters if an external binary-diff or chunking system (Steam depots, bsdiff) should see stable offsets. PCKPacker writes files in call order. **Add files in sorted, stable order** so unchanged files keep their offsets up to the first change. Small per-pack replacement is simpler than diffing.
- My builder (`core/tools/build_pack.gd`) packs:
  - `*.tres`, `*.json`, and friends as-is;
  - for each `*.import`, a *trimmed* `.import` (only the `[remap]` section, like export does) plus each `dest_files` entry from `.godot/imported/`;
  - it skips the source assets (`.png`).

  Result: pack_a has 6 files, 2,188 bytes, and takes 1.4 ms to build.
- **VRAM-compressed textures** [V-exp]: `.import` gets `path.s3tc=` and `path.etc2=` variants, and `dest_files` contains both `.s3tc.ctex` and `.etc2.ctex`. The runtime picks by feature tag. Either ship per-platform packs (desktop s3tc_bptc, mobile etc2_astc) or both variants (bigger).

### 1.5 `--export-pack`, `--export-patch`, `--patches`, delta encoding [V-src, V-doc, V-exp]

- `--export-pack <preset> <path>` **works headless with no export templates installed** [V-exp].
- Exported packs differ from PCKPacker packs [V-exp, `pckls.py`]:
  - `.tres` becomes a binary `.res` under `.godot/exported/<hash>/export-<md5>-name.res`, plus a `.tres.remap`;
  - `.gd` becomes `.gdc` plus a `.gd.remap`;
  - the pack includes `.godot/global_script_class_cache.cfg`, `.godot/uid_cache.bin` and `project.binary`.
- `--export-patch <preset> <path> --patches a.pck,b.pck` exports only changed files relative to the listed base packs. The `patches` preset key is used when `--patches` is omitted. `.apk` and `.aab` bases are also accepted (their assets are extracted) [V-src].
- **Delta encoding (4.6+)**. The preset keys are:

  ```
  patch_delta_encoding=true
  patch_delta_compression_level_zstd=19
  patch_delta_min_reduction=0.1
  patch_delta_include_filters="*"
  patch_delta_exclude_filters=""
  ```

  - The encoder is `DeltaEncoding::encode_delta`: zstd with the old file as a **prefix dictionary** (`ZSTD_CCtx_refPrefix`), a content-size and checksum flag, and a 5-byte header `GDDL` + version 1.
  - The entry is stored with `PACK_FILE_DELTA` and kept in a separate `delta_patches` list, not in `files`.
  - At runtime `FileAccessPatched` reads the **entire** base file, applies each delta in mount order, and serves the result from RAM. The cost repeats on every open.
  - Experiment [V-exp]: I changed one number in a 592 KB JSON and one field in a `.tres`.

    | Patch | Size |
    |---|---|
    | no delta | 592,592 bytes |
    | **delta** | **416 bytes** |

    Runtime results:

    | Scenario | Result |
    |---|---|
    | `--main-pack base.pck` + patch mounted | correct content, 3.0 ms to read the 592 KB file |
    | patch mounted **without** the base | `big.json` reads as 0 bytes (the delta entry is not a file entry), and `sword.tres` gives "Cannot open file" |
    | patch mounted over a **different** base | `Failed to decode delta … Data corruption detected`, and FileAccess length 0 |
  - Conclusion: delta patches **require the exact base PCK bytes at runtime, mounted earlier**. The docs add that re-exported base packs may differ because of non-determinism. Deltas fit "patch the already-installed pack" flows. They do not fit independent content packs. PCKPacker cannot emit delta entries.

---

## 2. Data definitions in packs, and security

### 2.1 What works [V-exp]

- **JSON in a pack.** `FileAccess.open("res://content/manifest.json")` and `FileAccess.get_file_as_string` work, and so do `file_exists` and DirAccess listing. `JSON.parse_string` returns ints as floats (`{"a":1}` gives `1.0`), so cast explicitly.
- **`.tres` custom Resources whose script lives in the core.** The pack `.tres` has `[ext_resource type="Script" path="res://defs/weapon_def.gd"]`, and the core contains the script. Loaded fine, with the icon texture from the same pack. In an exported core the `.gd` is `.gdc` + `.gd.remap`, and remapping resolves the path [V-src/V-exp: base.pck contents].
- **By uid:** `ext_resource uid="uid://…" path="…"`. If the uid is unknown, the text loader warns and **falls back to the path**: `WARNING: … invalid UID … using text path instead`. With a wrong path and an unregistered uid it fails. After `ResourceUID.add_id()` it succeeds (see §3).
- Script *class* resolution: `script_class="WeaponDef"` in the header is informational. The script is resolved through ext_resource. A new `class_name` inside a pack is only picked up if the pack's `global_script_class_cache.cfg` wins (replace=true). Data-only packs do not need this.

### 2.2 Script injection: exact outcome [V-exp]

Pack `pack_evil.pck`, built with PCKPacker and mounted with `replace_files=false`, contains:

```ini
# res://content/weapons/evil_embedded.tres
[gd_resource type="Resource" load_steps=2 format=3]
[sub_resource type="GDScript" id="GDScript_evil"]
script/source = "extends Resource
static func _static_init():
	print(\"[EVIL] static_init ran from embedded GDScript\")
func _init():
	print(\"[EVIL] _init ran from embedded GDScript; OS=\", OS.get_name())
	var f = FileAccess.open(\"user://pwned_embedded.txt\", FileAccess.WRITE)
	f.store_string(\"pwned\")
@export var damage: int = 0:
	set(v):
		print(\"[EVIL] setter ran, v=\", v)
		damage = v
"
[resource]
script = SubResource("GDScript_evil")
damage = 999
```

Output of plain `load("res://content/weapons/evil_embedded.tres")`, identical with `--path core` and with `--main-pack base.pck`:

```
[EVIL] static_init ran from embedded GDScript
[EVIL] _init ran from embedded GDScript; OS=Linux
[EVIL] setter ran, v=999
pwned_embedded exists: true
[EVIL] _init ran from pack-shipped evil.gd (ext_resource)      <- evil_ext.tres -> res://mods/evil.gd inside the pack
pwned_ext exists: true
PackedScene loaded; instantiating ...
[EVIL] scene node _init ran on instantiate                       <- .tscn with embedded GDScript
```

Also [V-exp]:

- `str_to_var('Object(Resource,"script":Resource("res://mods/evil.gd"))')` gives `[EVIL] _init ran`.
- `ConfigFile.parse()` of `payload=Object(Resource,"script":Resource("res://mods/evil.gd"))` gives `[EVIL] _init ran`.
- `bytes_to_var` on an object payload refuses: `ERR_UNAUTHORIZED`, returns null.
- `JSON.to_native(obj, allow_objects=false)` refuses.
- `ResourceLoader.get_dependencies(path)` lists ext deps **without** loading (it returned `["res://mods/evil.gd"]`). Sub-resource types cannot be listed without parsing.

[V-src] The ResourceLoader API in 4.7 is `load(path, type_hint, cache_mode)` only. It has no "no scripts" flag.

Community mitigation: `derkork/godot-safe-resource-loader` scans `.tres` text for GDScript sub-resources and for ext-resources outside `res://`. That check is **useless for packs**, because pack files *are* `res://` (see `evil_ext.tres`). It is blacklist-based and text-only.

**Implications for Diceroll:**

1. Content **definitions** in packs should be **JSON**, parsed with `JSON.parse_string` / `JSON.new().parse` into typed GDScript objects that the core constructs. Do not use `.tres`, `str_to_var`, `ConfigFile` or `var_to_str` for anything that is not fully trusted.
2. Assets (textures, audio, meshes) can still come from packs. They are imported binary resources whose loaders do not execute scripts, unless a scene or resource references a script.
3. **Signature verification before mounting is the real control.** A signed manifest lists pack SHA-256 values, and only verified packs are mounted.
4. Add a **CI gate**. For each pack, reject:
   - any `*.gd`, `*.gdc`, `*.gde`, `*.cs`, `*.gdextension`, `*.remap`, `project.binary`, `.godot/uid_cache.bin` or `global_script_class_cache.cfg`;
   - any text resource containing `type="GDScript"`, `script/source`, `type="Script"`, or `Object(`;
   - any binary `.res`/`.scn` unless it comes from the importer (`.ctex`, `.oggvorbisstr`, `.mesh`, and so on). Prefer keeping scenes and resources out of packs, or allowlist them after a text scan before conversion.
5. Store policy: a pack that executes code would be "downloaded executable code" (Apple Guideline 2.5.2). Data-only JSON and assets keep you clear of that. The CI gate above is what makes "data-only" a checkable property.

---

## 3. UIDs

- [V-src] Since 4.4, scripts and shaders have `.uid` sidecar files. Imported assets keep `uid=` in `.import`, and text resources keep it in the header. In exports the `.uid` files are **not** shipped; `res://.godot/uid_cache.bin` is (confirmed in `base.pck`). 4.5 added dropping a resource with Ctrl held to create a `preload("uid://…")` [V-doc 4.5 notes].
- [V-src] Format of `uid_cache.bin`: `u32 count`, then per entry `i64 id, i32 len, bytes path`. After each mount, `ResourceUID::load_from_cache(false)` merges `res://.godot/uid_cache.bin`, which resolves to whichever pack won that path.
- [V-exp] PCKPacker pack **without** a uid cache: pack uids unknown (`has_id=false`), and `load("uid://bswordauid01")` gives `Unrecognized UID`. A pack **with** `.godot/uid_cache.bin` mounted with `replace=false` is still unknown, because the core's file shadows it. With `replace=true` it would *replace the core's file path*. `load_from_cache(false)` merges rather than resets, but this is fragile, so avoid it.
- [V-src, V-exp] At runtime (non-editor), `ResourceLoader.get_resource_uid(path)` **only consults the ResourceUID cache**. It does not read `.import` or `.tres` headers, so it returns INVALID for unregistered pack files.
- **Working pattern [V-exp]:** at pack build time, emit `res://packs/<id>/uids.json` mapping `uid://… -> res://…`. After mount:

```gdscript
for u in uid_map:
    var id := ResourceUID.text_to_id(u)
    if ResourceUID.has_id(id): ResourceUID.set_id(id, uid_map[u])
    else: ResourceUID.add_id(id, uid_map[u])
# registered 2 uids in 0.024 ms; load("uid://bswordauid01") -> OK; uid-only ext_resource -> OK
```

Simplest: reference pack content by `res://` path from JSON definitions, and let text resources keep `path=`. Path fallback works.

---

## 4. Crypto (Godot 4.7.2, mbedTLS 3.6.7)

`Crypto.verify(hash_type, hash, signature, key)` wraps `mbedtls_pk_verify` [V-src]. `HashingContext.HashType` has only `HASH_MD5`, `HASH_SHA1` and `HASH_SHA256` [V-src/V-exp].
Keys and signatures were made with OpenSSL 3.0.13. The message was `msg.bin`, 67 bytes (`core/tests/t_crypto.gd`).

| Algorithm | Key load | Verify | Notes |
|---|---|---|---|
| RSA-2048, PKCS#1 v1.5, SHA-256 | OK | **true**; tampered gives false | ~0.1 ms/op |
| RSA-2048 key, **PSS** signature (saltlen 32) | OK | **false** | Crypto always uses v1.5 padding |
| RSA-PSS key type (`id-RSASSA-PSS` OID) | **ERR (-15488)** | n/a | `MBEDTLS_ERR_PK_UNKNOWN_PK_ALG` |
| ECDSA P-256 / SHA-256, **DER** signature | OK | **true**; tampered gives false | ~0.9 ms/op; Godot-side `sign` gives a 70-byte DER |
| ECDSA P-256, **raw r‖s (JWS ES256)** | OK | **false** | re-encoding to DER in GDScript gives **true** |
| ECDSA secp256k1 / SHA-256 | OK | **true** | ES256K is possible |
| ECDSA P-384 / SHA-384 | OK | cannot pass a SHA-384 digest | no `HASH_SHA384`, so ES384/ES512 are impossible natively |
| **Ed25519** | **ERR `Error parsing key '-15488'`** (both public and private PEM) | n/a | mbedTLS 3.x has no EdDSA |
| Ed448 | ERR (-15488) | n/a | |
| HMAC-SHA256 | n/a | `Crypto.hmac_digest` works | |

Raw r‖s to DER helper (tested):

```gdscript
func raw_to_der(raw: PackedByteArray) -> PackedByteArray:
	var n := raw.size() / 2
	var body := PackedByteArray()
	for part in [raw.slice(0, n), raw.slice(n)]:
		var v: PackedByteArray = part
		while v.size() > 1 and v[0] == 0 and (v[1] & 0x80) == 0: v = v.slice(1)
		if v[0] & 0x80: v.insert(0, 0)
		body.append(0x02); body.append(v.size()); body.append_array(v)
	var out := PackedByteArray([0x30])
	if body.size() >= 0x80: out.append(0x81)
	out.append(body.size()); out.append_array(body)
	return out
```

### 4.1 Ed25519 options

1. **Pure GDScript** [V-exp]: `core/crypto/sha512.gd` (SHA-512, checked against `sha512sum` for "", "abc" and 1000×"x") and `core/crypto/ed25519_verify*.gd` (TweetNaCl `crypto_sign_open` port with 16×16-bit limbs in int64, plus an `S < L` malleability check).
   - GDScript ints wrap on overflow, `>>` is arithmetic, and Packed arrays are passed by reference [V-exp].
   - Verified the OpenSSL-generated Ed25519 signature: valid gives true; tampered message gives false; tampered signature gives false.

   | Variant | Time per verify (this VM) |
   |---|---|
   | naive loops | 233 ms |
   | unrolled `M()` (generated by a Python script, 256 explicit multiply-adds) | **73–75 ms** |

   - GDScript SHA-512 runs at **2.19 MB/s**. JWS EdDSA signs the whole `base64url(header).base64url(payload)`, so a 100 KB manifest adds about 45 ms. Keep the signed manifest small.
   - Further speedups are possible (Straus/Shamir double-scalar multiplication, fewer allocations): perhaps 2× more **[U]**. Mobile will likely be 2–5× slower **[U]**. That is acceptable for a one-time boot verify on a thread.
   - This is not audited code, so keep it as a fallback.
2. **GDExtension**:
   - `freehuntx/gd-ed25519` (Monocypher; Ed25519 RFC 8032 + X25519 + XChaCha20-Poly1305 + BLAKE2b; MIT; lists Linux, Windows, macOS, Android, iOS and Web/WASM; small project with about 8 stars) [V-doc GitHub/Asset Library].
   - Libsodium bindings exist in the ecosystem but I did not verify a maintained 4.7 build **[U]**.
   - On Web, GDExtension needs the `dlink` templates (§6).
3. **Web**: WebCrypto Ed25519 via `JavaScriptBridge` (`crypto.subtle.importKey("raw", pk, {name:"Ed25519"}, …)` / `verify`). Supported in Firefox 129+, Safari 17+ and Chrome 137+ [V-doc secondary: IPFS blog / Igalia].
4. **Native layer**: the per-platform plugins could verify for us (CryptoKit `Curve25519.Signing` on Apple; Tink/BouncyCastle/JDK 15+ `Ed25519` on Android via the plugin or `JavaClassWrapper`). This adds per-platform code paths.
5. **Pragmatic alternative**: have Polaris Key (or our CDN) also emit **ES256** (P-256), which Godot verifies natively in about 1 ms after raw-to-DER conversion. Or wrap the manifest in RSA-PKCS1 v1.5. This decision belongs to the signing-format owner.

### 4.2 SHA-256 throughput [V-exp] (`t_hash.gd`, 256 MB random file)

| Method | Throughput |
|---|---|
| `HashingContext` SHA-256, chunk 16 KB | 220 MB/s |
| chunk 64 KB | 207 MB/s |
| chunk 1 MB | 204 MB/s |
| chunk 4 MB | 222 MB/s |
| `FileAccess.get_sha256(path)` | 206 MB/s |
| in-memory, 1 MB slices | 210 MB/s |
| OpenSSL `speed sha256` on the same CPU (SHA-NI) | ~1,340 MB/s |

Godot's mbedTLS config does not enable the SHA-256 hardware paths [V-src `godot_module_mbedtls_config.h`]. Budget about 5 ms/MB on desktop and more on mobile. That is fine for 10–100 MB packs, and should run on a `Thread`/`WorkerThreadPool`.

---

## 5. HTTPRequest (4.7) [V-src, V-exp]

- Properties: `download_file`, `download_chunk_size` (256 B–16 MB), `use_threads`, `accept_gzip`, `body_size_limit`, `max_redirects`, `timeout`, `set_tls_options(TLSOptions)`, `set_http(s)_proxy`, plus `get_downloaded_bytes()` and `get_body_size()`. Custom headers go in `request(url, headers)`.
- **HTTP/1.1 only** in `HTTPClientTCP`: the request line is `HTTP/1.1`, with no HTTP/2 [V-src]. On Web, `HTTPClient` is fetch-based, so the browser negotiates h2/h3.
- **Range** [V-exp, local Range server]: `Range: bytes=524288-` gives `code=206`, a 524,288-byte body and a correct `Content-Range`.
- **Resume caveats** [V-src, V-exp]:
  - `download_file` is opened with `FileAccess.WRITE`, which **truncates**. A 3-byte existing file plus `Range: bytes=3-` ended up as 1,048,573 bytes, overwritten rather than appended.
  - On a dropped connection (`result=4`, `RESULT_CONNECTION_ERROR`) HTTPRequest **deletes the partial file**.
  - To resume, either download each range to its own part file and concatenate, or write a small downloader on `HTTPClient` + `FileAccess.open(path, READ_WRITE)`/`seek_end()`.
- **TLS**:
  - `TLSOptions.client(trusted_chain: X509Certificate = null, common_name_override := "")`. Passing your own CA or leaf chain as `trusted_chain` gives trust-anchor pinning.
  - There is no SPKI-hash pinning API.
  - `TLSOptions.client_unsafe()` exists; do not ship it.
- Integrity should not depend on TLS. Verify the SHA-256 in the signed manifest before mounting.

---

## 6. Native platform bridges (4.5–4.7)

### Android [V-doc 4.7 docs, V-src]

- **Plugin v2** (since 4.2; v1 `.gdap` is deprecated):
  - An AAR library that depends on `godot-lib`, declared by an `EditorExportPlugin` (`_get_android_libraries`, `_get_android_dependencies`, `_get_android_dependencies_maven_repos`, manifest hooks).
  - The manifest meta-data is `org.godotengine.plugin.v2.<Name>`.
  - Requires the **Gradle build**.
- GDScript calls `Engine.get_singleton("Name").method(...)`. Kotlin/Java methods need `@UsedByGodot`, and names are matched exactly, with no snake/camel conversion.
- Signals: declare them in `getPluginSignals()` and emit with `emitSignal(...)`.
- Threading [V-src]:
  - `nativeEmitSignal` runs `emit_signalp` **synchronously on the calling Java thread**. When emitting from a Play Core callback or executor thread, wrap it in `runOnRenderThread { emitSignal(...) }`, or connect with `CONNECT_DEFERRED` in GDScript.
  - `runOnUiThread` is deprecated in favour of `runOnHostThread`.
  - Plugin methods called from GDScript run on the Godot (render) thread, so do not block there.
- GDExtension inside a v2 plugin is supported (`android_aar_plugin = true` in `.gdextension`, plus `getPluginGDExtensionLibrariesPaths()`).
- **4.4+ `JavaClassWrapper` + `AndroidRuntime` plugin**: call arbitrary Java/Kotlin from GDScript and implement Java interfaces through proxies (`JavaClassWrapper.create_proxy`). Gradle exports auto-include `.jar`/`.aar` files found in `addons/`. This may be enough to drive `AssetPackManager` without writing a plugin **[U]**; dependency AARs still need the Gradle setup.
- 4.7 release notes mention "Support for implementing and overriding Java interfaces in GDScript" and GABE (the Gradle build on the Android editor). 4.8-dev7 adds "Export project as an Android Archive (AAR)" [V-doc blog].
- **Play Asset Delivery** [V-src]:
  - Godot 4.7's AAB export already places **all project files in an install-time asset pack** (`assetPackInstallTime/src/main/assets`, `assetPacks = [":assetPackInstallTime"]`), stored as loose files plus the `assets.sparsepck` index.
  - For **fast-follow / on-demand** packs, add further `com.android.asset-pack` modules to the Gradle template in CI, then use AssetPackManager (`com.google.android.play:asset-delivery`). Pack location: `getPackLocation(name).assetsPath()` gives an absolute path on internal storage, and `load_resource_pack(abs_path + "/x.pck")` uses plain `FileAccessUnix`. **[U]** Not device-tested, but the same code path as my absolute-path test.
  - An install-time asset pack or APK assets can be mounted as `res://path/x.pck`: the nested-pck mount is [V-exp] on desktop; on Android it goes through `FileAccessAndroid`. **[U]** AAPT compresses unknown extensions, and seeking in a compressed asset is slow, so add `noCompress += ['pck']` (androidResources) in the Gradle template or keep packs uncompressed.
- **No official PAD or In-App-Updates plugin** exists. `godot-sdk-integrations` has google-play-billing, play-game-services, admob, ios-plugins, storekit2 and meta-toolkit [V-doc GitHub org page]. Community In-App Update plugins: `dcryptoniun/Godot-Android-InAppUpdate` (4.5+) and `icecube092/GodotInAppUpdate` (4.6) [V-doc Asset Library, unaudited]. I found no maintained Godot Play Asset Delivery plugin **[U]**, so plan to write one (Kotlin, small).

### iOS / "Apple Embedded" (iOS + visionOS) [V-src, V-doc]

- 4.5 refactored iOS into an "apple_embedded" driver and added visionOS. The `EditorExportPlugin` methods are now `add_apple_embedded_platform_{framework, embedded_framework, plist_content, linker_flags, bundle_file, cpp_code, project_static_lib}`; `add_ios_*` is deprecated.
- **4.7 adds `_end_generate_apple_embedded_project(path, will_build_archive)`**, called after Xcode project generation and before the build [V-src class ref; absent in 4.6]. It is the hook for adding a **Background Assets downloader extension target** (run Ruby `xcodeproj`, XcodeGen or a script from `OS.execute`).
- Alternatively, set the preset option `application/export_project_only=true` and post-process the `.xcodeproj` in CI before calling `xcodebuild`.
- Legacy `.gdip` plugins (static `.a`/`.xcframework`) still exist; the docs page is flagged `article_outdated` [V-doc].
- **GDExtension on iOS** [V-src export plugin]: `.dylib`, `.xcframework` (static or dylib) and `.framework` are supported, and dylibs are auto-wrapped into `.framework` for App Store compliance.
- Swift: **SwiftGodot** (GDExtension in Swift, macOS + iOS device) [V-doc secondary]. `migueldeicaza/GodotApplePlugins` is a SwiftGodot GDExtension covering GameCenter, StoreKit2, Sign-in with Apple, file picker, ARKit, CoreMotion and AVAudioSession; it targets iOS 17+, macOS 14+ and visionOS; latest asset-lib v1.10 from 2026-06-07 [V-doc]. Official `godot-sdk-integrations/godot-storekit2` was updated 2026-04 [V-doc]. **No Background Assets / ODR Godot plugin found [U]**, so this is custom Swift work.
- **Paths** [V-src `os_apple_embedded.mm`]:
  - `user://` = **Documents** (iCloud-backed-up and user-visible if file sharing is on).
  - `OS.get_cache_dir()` = `Library/Caches` (purgeable).
  - Store re-downloadable packs in `Library/Application Support/…` (path = `OS.get_user_data_dir().get_base_dir() + "/Library/Application Support"`) with `NSURLIsExcludedFromBackupKey` set natively, or in Caches if they can be re-fetched.
  - `load_resource_pack` takes any readable absolute path. A path handed over by Background Assets (inside the app's container or app-group container) should work the same way **[U]**; nothing Godot-specific is known.

### GDExtension per platform [V-src/V-doc]

- Desktop: `.dll`/`.so`/`.dylib`/`.framework`.
- Android: `.so` via AAR or the `.gdextension` file.
- iOS: see above.
- **Web**: requires the "Extensions Support" option, which uses the `web_dlink[_nothreads]_{debug,release}.zip` templates [V-src]. The 4.7 docs say this "requires cross-origin isolation headers". dlink_nothreads templates do exist [V-src]. **[U]** Whether COI is strictly needed for nothreads must be tested.

### Community plugins (status 2026-09)

- **GodotSteam**: per the godotsteam.com blog on 2026-08-22, "GodotSteam 4.22 / 4.11" for Godot 4.7.2 merged the module and GDExtension code; Steamworks SDK 1.65 was adopted on 2026-07-29; a patch followed on 2026-09-03. Which of 4.22 / 4.11 is standard and which is Server is **[U]**.
- DLC API (docs page) [V-doc]: `isDLCInstalled(id)`, `installDLC(id)`, `uninstallDLC(id)`, `getDLCDownloadProgress(id) -> {ret, downloaded, total}`, `getAppInstallDir(app_id)`, `getInstalledDepots(app_id)`, `getDLCData()`, signal `dlc_installed`.
- Steam DLC depots land in the install dir, so mount `getAppInstallDir(appid).path_join("dlc/x.pck")` or `OS.get_executable_path().get_base_dir()`.
- **Velopack / Sparkle**: no Godot integration found **[U]**. Treat them as external launchers/updaters (Sparkle via a small macOS Swift or ObjC GDExtension or `libMacSparkle` C API; Velopack wraps the exe).

---

## 7. Web

- [V-src `library_godot_os.js`, `os_web.cpp`]:
  - `user://` lives under `/userfs`, an Emscripten **IDBFS** mount.
  - At startup `FS.syncfs(true)` **copies the whole IndexedDB content into memory**, and writes set `idb_needs_sync` for a later `syncfs(false)`.
  - `load_resource_pack("user://packs/x.pck")` therefore works (it is ordinary FileAccess), **[U]** not browser-tested here. Every persisted pack costs RAM at every boot and is re-synced on changes.
  - Persistence needs IndexedDB permission (third-party iframe caveats), and `OS.is_userfs_persistent()` can give false positives [V-doc].
- Better pattern [U, design]:
  1. Keep packs in the **Cache Storage API**: fetch through `JavaScriptBridge` (`get_interface("caches")` / `eval`) or `HTTPRequest`, which uses fetch.
  2. On boot, copy the bytes with `JavaScriptBridge.js_buffer_to_packed_byte_array` to a **non-persistent** MEMFS path (for example `/tmp/packs/x.pck` via `FileAccess` on an absolute path).
  3. Mount only what the session needs.
  4. Verify Ed25519 with WebCrypto.

  JavaScriptBridge 4.7 methods: `eval`, `get_interface`, `create_callback`, `create_object`, `is_js_buffer`, `js_buffer_to_packed_byte_array`, `download_buffer`, `force_fs_sync`, `pwa_needs_update`, `pwa_update`, and signal `pwa_update_available` [V-src].
- The export JS `Engine` config can preload files before start (`preloadFile`) [U, from memory; check the `html/…` docs].

## 8. Android and iOS path specifics

- Android: see §6. PAD fast-follow and on-demand packs sit on internal storage, and absolute paths work. APK and install-time assets use `res://` paths. godot#105009 is open, and the first-mount directory scan is the likely cause (§1.1). On 4.5+ exports the sparse main pack should avoid it **[U]**.
- iOS: `user://` is Documents, so do not put multi-MB re-downloadable packs there without excluding them from backup (App Review data-storage guidelines). Put them in Application Support with the do-not-back-up flag. No Godot-specific sandbox issue is known **[U]**.

---

## 9. Prior art: mods and DLC

- **Godot Mod Loader** (GodotModding): mods are ZIPs loaded with `load_resource_pack`, and code changes use script extensions (`take_over_path`) and, since v7, script *hooks* to work around `class_name` in Godot 4. Used by Brotato, Dome Keeper, Windowkill and others. Latest GitHub release seen: v7.0.1 (June 2024, Godot 4.1–4.3); a newer release may exist **[U]** [V-doc GitHub].
  - Lesson: code mods are hard in 4.x (class cache, UIDs), and data or asset packs are easy.
- **Cassette Beasts** (Godot 3.5) [V-doc wiki]:
  - Mods are `.pck` files built by a **custom editor plugin, not the normal export**. The game mounts all detected packs at startup, then scans `res://mods/*/metadata.tres` (`ContentInfo`: id, version, save-format tag, network-protocol tag, modified files).
  - Autoloads, `project.godot` changes and `class_name` are prohibited.
  - They note Godot "doesn't (and can't) know if two mods replace the same resource before irreversibly loading them both".
  - Lessons: a per-pack metadata file in a namespaced dir, save-compat tags, and no project-level changes. All three match our plan, but our metadata should be **JSON**, not `.tres` (§2.2).
- Brotato DLC, Dome Keeper DLC and Halls of Torment: I found no primary technical write-ups **[U]**.

## 10. Engine-version compatibility of packs

- [V-src]
  - The PCK header check rejects packs whose writer has a **higher minor** than the runtime (verified by header patch).
  - Binary resources check only `format ≤ 6` and `major ≤ 4` (not minor).
  - Text resources check `format ≤ 4`; files are written as format 3 unless new features are used.
  - `.ctex` is `FORMAT_VERSION 1`.
  - **All of these, and every line of `file_access_pack.cpp`, `pck_packer.cpp` and the pack code in `project_settings.cpp`, are identical in master (4.8-dev7).**
  - So 4.7-built packs should load in 4.8 **[U: not run on a 4.8 binary]**, and 4.8-built packs will **not** load in 4.7.
- What invalidates a pack:
  1. **PCK tool version**: build with the oldest supported engine minor.
  2. **Core schema changes**: renamed or removed `@export` properties in core scripts are silently dropped when a `.tres` loads. With JSON definitions, validate against a versioned schema.
  3. Engine class or property renames (compat handlers usually exist).
  4. Import-format changes (a new ctex format or VRAM format support). Reimport happens only in the editor, and old `.ctex` keep loading unless a format version bump drops support.
  5. **Delta patches** are invalid if the base pack bytes differ.
  6. Encrypted packs depend on the template's compiled key.
- 4.8-dev2 changed text serialization to put Object properties on separate lines [V-doc blog]. The text format version is still 4 in master [V-src].

---

## 11. Recommended shape for Diceroll (from the evidence)

1. **Content packs = assets + JSON definitions only.**
   - Build them with PCKPacker from the import cache: trimmed `.import` + `.ctex`/audio + JSON, sorted, per-platform texture variants.
   - Namespace each pack under `res://content/<pack_id>/`.
   - Include `res://content/<pack_id>/pack.json` (id, version, min_core, schema version, uid map if needed).
   - Mount with `replace_files=false`.
2. **Before mounting:**
   - Read the signed manifest.
   - Verify the signature: ES256 native, RSA natively, or Ed25519 via GDScript fallback or GDExtension or WebCrypto or the native plugin.
   - Stream SHA-256 over the pack file (~200 MB/s).
   - Then mount. Optionally use the `offset` param to keep a signed header in the same file.
3. **CI gate** that fails the build if a pack contains any script or code-bearing resource (§2.2 list), `project.binary` or the `.godot/*cache*` files.
4. **Mount early** (autoload `_init`) and in bounded numbers. Measure mount cost against the real core `uid_cache.bin` size, which is roughly 0.37 µs per UID entry per mount on desktop.
5. **Never mutate a mounted pack file.** Download to a new content-addressed name, then switch on the next launch. Use tombstone packs or a restart to "disable".
6. **Resumable downloads** need a small `HTTPClient` downloader, not `HTTPRequest.download_file`.
7. Delta patches are only worth using for the core pack (patching the shipped base). They are not for independent content packs.

---

## Sources

- Engine source, tag 4.7.2-stable:
  - https://github.com/godotengine/godot/blob/4.7.2-stable/core/config/project_settings.cpp
  - https://github.com/godotengine/godot/blob/4.7.2-stable/core/io/file_access_pack.cpp and `file_access_pack.h`
  - https://github.com/godotengine/godot/blob/4.7.2-stable/core/io/pck_packer.cpp
  - https://github.com/godotengine/godot/blob/4.7.2-stable/core/io/delta_encoding.cpp and `file_access_patched.cpp`
  - `core/io/resource_uid.cpp`, `core/io/resource_loader.cpp`, `scene/resources/resource_format_text.cpp`, `core/io/resource_format_binary.cpp`
  - `modules/mbedtls/crypto_mbedtls.cpp`, `thirdparty/README.md` (mbedTLS 3.6.7), `thirdparty/mbedtls/include/godot_module_mbedtls_config.h`
  - `scene/main/http_request.cpp`, `core/io/http_client_tcp.cpp`
  - `editor/export/editor_export_platform.cpp`, `editor/export/editor_export_preset.cpp`
  - `platform/android/export/export_plugin.cpp`, `platform/android/java/app/build.gradle`, `platform/android/plugin/godot_plugin_jni.cpp`, `platform/android/java/lib/src/main/java/org/godotengine/godot/plugin/GodotPlugin.java`
  - `drivers/apple_embedded/os_apple_embedded.mm`, `editor/export/editor_export_platform_apple_embedded.cpp`
  - `platform/web/os_web.cpp`, `platform/web/js/libs/library_godot_os.js`, `platform/web/export/export_plugin.cpp` / `.h`
  - Class reference XML: ProjectSettings, EditorExportPlugin, ResourceLoader, ResourceUID, TLSOptions, HTTPRequest, JavaScriptBridge
- Engine source, `master` (4.8-dev): the same pack, packer, text and binary format files; `version.py` = 4.8 dev.
- Docs (godot-docs 4.7 branch):
  - `tutorials/export/exporting_pcks.rst` (https://docs.godotengine.org/en/4.7/tutorials/export/exporting_pcks.html)
  - `tutorials/export/exporting_for_web.rst`
  - `tutorials/platform/android/android_plugin.rst`
  - `tutorials/platform/android/javaclasswrapper_and_androidruntimeplugin.rst`
  - `tutorials/platform/ios/ios_plugin.rst`
- Blog:
  - https://godotengine.org/releases/4.5/
  - https://godotengine.org/releases/4.6/
  - https://godotengine.org/releases/4.7/
  - https://godotengine.org/article/dev-snapshot-godot-4-8-dev-2/
  - https://godotengine.org/article/dev-snapshot-godot-4-8-dev-7/
  - https://godotengine.org/blog/
- Issue: https://github.com/godotengine/godot/issues/105009 (open)
- https://github.com/freehuntx/gd-ed25519
- https://github.com/derkork/godot-safe-resource-loader
- https://github.com/migueldeicaza/GodotApplePlugins and https://godotengine.org/asset-library/asset/4552
- https://github.com/orgs/godot-sdk-integrations/repositories
- https://github.com/GodotModding/godot-mod-loader
- https://wiki.cassettebeasts.com/wiki/Modding:Mod_Developer_Guide
- https://godotsteam.com/blog/ and https://godotsteam.com/classes/apps/
- Asset Library: InAppUpdate https://godotengine.org/asset-library/asset/5407 and https://github.com/dcryptoniun/Godot-Android-InAppUpdate
- WebCrypto Ed25519 support: https://blog.ipfs.tech/2025-08-ed25519/
