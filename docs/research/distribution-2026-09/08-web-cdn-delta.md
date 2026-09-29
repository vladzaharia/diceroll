# 08: Web distribution, CDN hosting for content packs, and delta updates

Date: 2026-09-29. Engine: Godot 4.7.2 (`4.7.2.stable.official.ed1daf0bf`). Scope: Diceroll's plan to split
the ~73–85 MB PCK into data-only content packs of 1–20 MB, served from our own CDN to web, direct-desktop
and sideload builds, with per-pack delta updates.

Legend: **[V: url]** means verified against that source today. **[E#]** means verified by an experiment in
this session (appendix). **[S: file]** means read in the Godot 4.7-stable source. **[?]** means uncertain
or inferred.

---

## 0. Summary and recommendations

1. **Hosting: use Cloudflare R2 behind a custom domain as the pack CDN. Keep GitHub Releases for binaries
   and as an archive or mirror.**
   - GitHub release downloads send **no CORS headers** on either hop, so a web build cannot fetch them [E10].
   - R2 has zero egress cost [V: R2 pricing]. At 100k monthly active installs (MAI) the bill is about
     **$0–1/month** (§B.4).
   - Workers static assets cannot host the web build as it is. The limit is 25 MiB per file and
     `index.wasm` is 37.7 MiB (39.5 MB) [V: Workers limits][E9]. Put wasm and packs in R2, and use the
     Worker (Polaris Key) for `index.html`, manifests and, optionally, staged rollout and auth.

2. **Delta scheme: content-addressed immutable full packs, plus optional Godot-native delta patch packs,
   rehydrated on native clients.**
   - Real releases show content packs almost never change. Across rc.1→rc.2→rc.3, **0 asset files changed**.
     All changes were code, caches and UI (0.5–1.2 MB of files out of 85 MB) [E1].
   - When content does change, Godot's own `PACK_FILE_DELTA` entries (zstd `--patch-from` per file, "GDDL")
     are as small as bsdiff, xdelta3 or HDiffPatch. On the synthetic forest pack: 52 KB zstd vs 51–59 KB,
     against 8.3 MB for the full compressed pack [E4].
   - The engine applies these deltas itself at load time, on desktop **and web** [E5][E8].
   - `PCKPacker` can't write delta entries. A roughly 60-line Python writer in CI can, and its output mounts
     fine over PCKPacker-built data packs [E5].
   - Native clients then **rehydrate**: mount base + patch, re-pack all files with `PCKPacker`, and get a
     full pack that is **byte-identical** (same SHA-256) to the CI-built one [E6]. So each client keeps
     exactly one verified full pack per pack id. No chains, no GDExtension.
   - Binary diff tools (need a GDExtension, which on web means the dlink template plus COOP/COEP) and
     content-defined chunking (3–10× bigger deltas here) aren't worth it [E1][E4].

3. **Transport compression matters more than deltas for first installs.**
   - Store packs as `*.pck.zst` and decompress with `PackedByteArray.decompress(size, COMPRESSION_ZSTD)`:
     17 ms desktop, about 20 ms wasm for 20 MB [E7][E8].
   - The forest unit shrinks **59%** (20.0 → 8.2 MB). All units go from 80.9 to 61.6 MB [E3].
   - Godot's native HTTP client only auto-decodes gzip/deflate, and gzip saves only 11%.
   - `.zst` is also a default-cached extension on Cloudflare, but `.pck` isn't [V: default cache behavior].

4. **Web-specific findings (Godot 4.7.2, nothreads):**
   - **`HTTPRequest.download_file` is broken on web.** It returns `RESULT_SUCCESS`/200 but the file is
     deleted. The cause is that the web HTTP client always reports body length −1, and the EOF branch never
     sets `download_complete`. It's fixed on `master`, not on the `4.7` branch [E8][S]. Workaround: download
     into memory, then `FileAccess.store_buffer`.
   - Anything in `user://` (IDBFS) is **loaded fully into memory at every page start** (`FS.syncfs(true)`).
     Measured: JS heap at boot went 49 → 88 MB with one 20 MB pack persisted [E8]. So on web, keep packs in
     the **browser HTTP cache or Cache Storage** (immutable, content-hashed URLs) and mount them per session
     from a non-persistent MEMFS path (`/tmp/packs`). Verified: 1 server request across 2 page loads, boot
     heap stays at 53 MB [E8].
   - HTTPRequest throughput on web is about `download_chunk_size × fps`. The default 64 KiB chunk meant
     20 MB took 5.5 s from localhost; 1 MiB chunks took 0.6–1.5 s. Set `download_chunk_size = 1–4 MiB` [E8].
   - Stay on the nothreads build: no COOP/COEP needed, and iframes and embedding just work. There's still
     no WebGPU; Compatibility renderer only [V: web export docs].

5. **Resumable downloads:** `HTTPRequest.download_file` truncates the target and **deletes it on any
   error or cancel** [S], so it can't resume.
   - Download in Range segments (4–8 MiB) and append to a `.part` file yourself.
   - Range headers survive redirects and give 206 [E11].
   - GitHub supports `bytes=a-b` and `bytes=a-`, but **not suffix ranges** (`bytes=-N` → 501) [E10].
   - SHA-256 through `HashingContext` runs at about 220 MB/s on desktop and in wasm (x86 VM) [E7][E8].
     Hashing a 20 MB pack costs about 0.1 s. On phones it should be under 0.5 s [?].

---

## Experiments (details in appendix)

| # | What | Key result |
|---|---|---|
| E1 | File-level and binary deltas between the **real** release PCKs v0.1.0-rc.1/rc.2/rc.3 (85 MB, 6.6k files) | 0 asset changes. Code-only deltas 0.29–0.68 MB with any binary tool |
| E2 | PCKPacker determinism | Two builds of the forest unit are byte-identical |
| E3 | Compression ratios (whole PCK, per unit, wasm) | zstd −27% whole, −59% forest, −1% music. wasm 39.5 MB → 7.1 MB br / 10.1 MB gz |
| E4 | Synthetic data-pack update (forest 20.3 MB: 5 scenes re-saved with tweaks, +10 new files, −3 removed) | Full 8.29 MB zst; file-level 166 KB; GDDL 52 KB; bsdiff/xdelta/zstd/HDiffPatch 51–59 KB; CDC 425 KB–0.97 MB |
| E5 | Runtime mount on 4.7.2 desktop: base + file-level overlay; base + Python-built GDDL delta pack; delta over the wrong base | Overlay and GDDL both give exact v2 bytes and removals are honored. Wrong base → zstd checksum error, file unreadable |
| E6 | Rehydrate: base + GDDL patch → re-pack with PCKPacker | 2,661 files in 136 ms, **SHA-256 identical** to the CI-built v2 |
| E7 | GDScript zstd decompress, SHA-256/MD5 speed (desktop) | 8.3→20.3 MB in 17 ms; SHA-256 160–222 MB/s; MD5 about 450–484 MB/s |
| E8 | **Web export** (4.7.2 nothreads template, headless Chromium 153): download to `user://`, mount, GDDL overlay, reload persistence, HTTP-cache variant | See §A.6 |
| E9 | Web export sizes (rc.3 release zip) | `index.wasm` 39,514,754 B; `index.pck` = desktop PCK 85,253,008 B |
| E10 | GitHub release download headers (CORS, Range, ETag, redirect) | No CORS. 206 OK. Suffix range 501. Signed redirect URL with about 1 h expiry |
| E11 | HTTPRequest Range + 302 redirect + `download_file` (desktop, local server) | Range kept across redirect → 206, file = remainder only |

---

## A. Web

### A.1 State of the Godot 4.7 web export

| Topic | State | Source |
|---|---|---|
| Docs version | The "stable" web export page is 4.7 | [V: docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html] |
| Threads vs nothreads | Single-threaded export is the default and preferred since 4.3. Threaded builds need `SharedArrayBuffer`, a secure context and `COOP: same-origin` + `COEP: require-corp`. That breaks many third-party embeds and ad networks | [V: same] |
| GDExtension on web | Needs the `dlink` template, which "produces bigger binaries", and cross-origin isolation, like threads | [V: same][S: platform/web/detect.py] |
| Official 4.7.2 web templates | `web`, `web_nothreads`, `web_dlink`, `web_dlink_nothreads`, each debug and release (~10–12 MB zipped). **No wasm64 template.** | [E9: listed from the official .tpz] |
| wasm64 | `detect.py` accepts `arch=wasm64` (`-sMEMORY64=1`), but only for custom builds. The claim that "4.7 ships wasm64 exports" (cinevva.com) is **not** reflected in the official templates or the 4.7 release page | [S][V: godotengine.org/releases/4.7/] [?] |
| WASM SIMD | On by default (`wasm_simd=True`) | [S: detect.py] |
| Memory | `ALLOW_MEMORY_GROWTH=1`, initial 32 MiB. Threaded builds cap at `WASM_MEM_MAX=2048MB` | [S: detect.py] |
| Renderer | **Compatibility (WebGL 2) only.** "Forward+/Mobile are not supported on the web platform"; "Godot currently does not support WebGPU." Diceroll already sets `rendering_method.web="gl_compatibility"` | [V: web export docs] |
| Audio | Default is Web Audio *sample* playback (low latency, no AudioEffects). *Stream* mode has full features but more latency, especially without threads | [V: web export docs] |
| Safari | "Safari has several issues with WebGL 2.0 support". Single-threaded export runs well on iOS | [V: web export docs] |
| WASM size (our build) | `index.wasm` **39.5 MB** raw → **10.1 MB gzip-9 / 7.1 MB brotli-11 / 7.5 MB zstd-19**. `index.js` 280 KB → 68 KB gz / 60 KB br | [E9] |
| First load today | The HTML shell preloads the **whole main pack** (`index.pck` = 85 MB, same bytes as the desktop PCK) plus about 10 MB of wasm before the first frame | [E9][S: engine.js `preloadFile(mainPack)`] |

### A.2 PWA option and service worker (4.7 template)

Read from `misc/dist/html/service-worker.js` and `platform/web/export/export_plugin.cpp` [S]:

- **Precaches** `index.html`, `index.js`, `index.wasm`, the audio worklets and icons. It also *optionally*
  caches `index.pck` (and `.side.wasm` / GDExtension libs) on first load.
- It serves those files **cache-first**. On a navigation it checks that everything is cached, falls back to
  the network, and shows the offline page if that fails.
- `CACHE_VERSION` is the **export time** (`unix_time|ticks`). Every export yields a byte-different
  `service-worker.js`, so the browser installs a new SW and deletes the old caches on `activate`.
  - The old SW keeps control until reload or claim.
  - Godot exposes this through `JavaScriptBridge.pwa_needs_update()` / `pwa_update()` and the
    `pwa_update_available` signal [S: os_web.cpp `pwa_update`, `pwa_is_waiting`].
- **Anything else** (for example packs fetched by `HTTPRequest` from other paths) is not cached by the SW.
  With `ensure_cross_origin_isolation_headers=true` it is only passed through, with COOP/COEP injected.
  To cache packs offline you'd extend the SW with a cache-first rule for `/packs/*` (content-hashed, so
  never stale).
- Browsers may evict the caches when disk is low or after long non-use. The optional offline page covers
  that [V: web export docs].
- **Recommendation:** leave PWA **off** until offline play is a goal. Nothreads doesn't need the COI header
  trick, and a cache-first SW makes "always latest" slower to reach players.

### A.3 Persistence, memory and OPFS

- `user://` on web is **Emscripten IDBFS** mounted at `/userfs` [S: library_godot_os.js `GodotFS`].
  - At startup, `FS.syncfs(true)` **copies every persisted file from IndexedDB into the in-memory FS**.
  - After a file opened for writing under `/userfs` is closed, `idb_needs_sync` is set, and the next frame
    runs `FS.syncfs(false)` [S: os_web.cpp].
  - Measured: boot JS heap 49 MB with nothing stored, **88 MB** once a 20 MB pack plus a 67 KB delta were
    stored [E8].
  - Every pack kept in `user://` therefore costs RAM on every page load, whether or not it is mounted.
- **OPFS / WasmFS:** Godot 4.7 doesn't use them; only IDBFS is wired up [S]. OPFS is widely available
  (Chrome 86, Firefox 111, Safari 15.2) [V: developer.mozilla.org/.../Origin_private_file_system]. Using it
  would mean custom JS via `JavaScriptBridge`, and a pack still has to be copied into MEMFS to be mounted,
  because `load_resource_pack` goes through Godot's `FileAccess`.
- **Mounted packs live in memory.** A pack in MEMFS (`/tmp` or `/userfs`) is a JS `Uint8Array`, and loaded
  resources also occupy the wasm heap. Budget roughly the sum of mounted packs plus the working set.
- **iOS Safari:**
  - WebKit bug 269777: "Only ~300 MB of RAM is reliably available to WebAssembly pages". Safari kills the
    tab rather than failing `memory.grow` [V: bugs.webkit.org/show_bug.cgi?id=269777].
  - Storage: since Safari 17 the origin quota is up to 60% of disk for browser apps (15% for other apps).
    After **7 days of browser use without user interaction**, all script-writable storage (IndexedDB,
    Cache Storage, SW registrations) is deleted [V: webkit.org/blog/14403 "Updates to Storage Policy"].
    The 7-day rule applies to browser tabs; Home Screen web apps are treated differently [?].
  - **So on web, treat every pack as possibly missing at every start, and mount only what the current run
    needs.**
- Browsers need IndexedDB (and third-party storage when embedded in an iframe, as on itch.io) for
  `user://` to persist [V: web export docs].

### A.4 Lazy-loading packs on web: what works (verified)

Pipeline tested in headless Chromium with the official 4.7.2 `web_nothreads_release` template [E8]:

1. `HTTPRequest` with `download_file=""` and `download_chunk_size = 1 MiB`: the body arrives in memory
   (20 MB in 0.6–1.0 s from localhost). **Don't use `download_file` on web in 4.7.x (bug).**
2. `FileAccess.open(path, WRITE).store_buffer(body)`, then `ProjectSettings.load_resource_pack(path)`.
   Mount took 16–19 ms for 20 MB, and `load()` of a scene from it works.
   - With `path` under `user://`: it persists across reloads, but costs boot memory.
   - With `path` under **`/tmp/packs/`** (MEMFS, not persisted): nothing is loaded at boot.
3. A **GDDL delta overlay** pack mounted with `replace_files=true` patches files correctly on web.
   SHA-256 matches v2, and a patched scene loads.
4. **HTTP cache as the persistent layer:** serve packs at content-hashed URLs with
   `Cache-Control: public, max-age=31536000, immutable`. With a persistent browser profile, the second
   page load fetched the pack from the browser cache (server saw 1 request for 2 loads). The fetch still
   takes about 1.2 s for 20 MB because Godot reads one chunk per frame. Use 4 MiB chunks for cached packs.
5. zstd transport decompression in wasm: 8.3 → 20.3 MB in 19–27 ms. SHA-256 of 20 MB in wasm: 88–99 ms.

Earlier forum reports of `load_resource_pack` "not working on web" (forum.godotengine.org threads 59718
and 47301) are consistent with the `download_file` bug above. One reporter had it working with
single-threaded 4.3.

**Recommended web design:**

- The main `index.pck` shrinks to the code/UI/boot pack. Today's non-asset share is about 2.6 MB plus UI
  imports, so roughly 4–5 MB.
- Content packs come from `https://cdn.<domain>/packs/<id>/<sha16>.pck.zst`. On every run, fetch into memory
  (browser HTTP cache hit most of the time), decompress, write to `/tmp/packs/<id>.pck`, and mount.
- Mount only the packs the route needs. There's no unmount API in 4.x, so a session only grows. A page
  reload resets it.
- Optional later: a custom SW or `JavaScriptBridge` Cache Storage layer for offline play and for asking
  "which pack hashes do I have?", which enables patch downloads on web.

### A.5 Hosting the web build

| Host | Fit for Diceroll web | Notes |
|---|---|---|
| **Cloudflare Workers static assets** | **Not as-is.** Max **25 MiB per file** on both Free and Paid; `index.wasm` is 37.7 MiB | 20k files (Free) / 100k (Paid); `_headers` (100 rules); requests to static assets free and unlimited [V: developers.cloudflare.com/workers/platform/limits/, /workers/platform/pricing/]. Good for `index.html`, `index.js`, worklets, icons |
| **Cloudflare Pages** | Same 25 MiB limit | Cloudflare now says "Workers supports most Pages use cases… Start new projects with Workers" [V: developers.cloudflare.com/pages/migrations/, /pages/platform/limits/] |
| **R2 custom domain** | **Yes**, for `index.wasm` (no size issue; the CDN compresses `application/wasm` on the fly with br/gzip, and zstd via a compression rule) and for packs | Needs a CORS policy if the page is on another origin. Can also serve the whole site: link directly to `/index.html`, since public buckets don't serve directory indexes [V: developers.cloudflare.com/r2/buckets/public-buckets/, /rules/compression-rules/examples/enable-zstandard/] |
| GitHub Pages | OK for a demo | 1 GB site, **100 GB/month soft bandwidth**, 10 builds/h soft, "not… for… commercial" hosting [V: docs.github.com/.../github-pages-limits]. No custom headers (fine for nothreads) [?]. Git's 100 MB file limit is close to today's 85 MB `index.pck` [?] |
| itch.io HTML5 | OK as a secondary channel | ≤1,000 files, ≤500 MB extracted, ≤200 MB per file; `.br` files served as Brotli; auto gzip [V: itch.io/docs/creators/html5]. Runs in a cross-origin iframe, so the CDN needs CORS for the itch origin, and storage may be partitioned [?] |
| GitHub Releases | **No** | No `Access-Control-Allow-Origin` on the github.com 302 or on `release-assets.githubusercontent.com`; OPTIONS → 405 [E10] |

**Proposed layout (single origin, no CORS):**

- `play.<domain>` points to the Polaris Key Worker.
- The Worker serves `index.html` (`Cache-Control: no-cache`) from static assets, plus `/v/<build>/index.js`
  and the worklets.
- It routes `/v/<build>/index.wasm` and `/packs/*` to R2, either through an R2 binding (same origin; each
  request is a Worker invocation) or a Cloudflare Cloud Connector / route to the bucket's custom domain.
- Alternative: two origins (`play.` on Workers, `cdn.` on the R2 custom domain) with an R2 CORS policy
  (`AllowedOrigins`: play and itch origins; `AllowedMethods` GET/HEAD; `AllowedHeaders` range;
  `ExposeHeaders` content-length/content-range/etag). This is simpler and avoids Worker requests for bytes.
  Cloudflare notes CORS headers only show when the request has `Origin`, and cached assets must be purged
  after a CORS change [V: developers.cloudflare.com/r2/buckets/cors/].

### A.6 Updating web builds ("always latest") and cache busting

- The export uses fixed names (`index.js`, `index.wasm`, `index.pck`). The engine config has
  `executable` (the base path for `.wasm`, the audio worklets and `.side.wasm`) and `mainPack`
  [S: platform/web/js/engine/config.js `locateFile`].
- **Recommendation:** upload each web build to an immutable directory `/v/<version-or-hash>/` with
  `Cache-Control: public, max-age=31536000, immutable`.
  - Serve a tiny root `index.html` with `no-cache` (revalidated by ETag). It loads `/v/<id>/index.js` with
    `GODOT_CONFIG.executable = "/v/<id>/index"` and `mainPack = "/v/<id>/index.pck"` [?: derived from the
    source; to be smoke-tested].
  - A new deploy is one `index.html` change. Players get it on the next reload, and old builds stay valid
    for open tabs.
  - Workers static assets default to `Cache-Control: public, max-age=0, must-revalidate` + ETag, which
    suits `index.html` [V: developers.cloudflare.com/workers/static-assets/headers/].
- The PWA SW (if enabled later) needs the `pwa_update_available` → "Reload to update" UX (§A.2).
- Web never runs the updater (as today). Pack freshness comes from the manifest fetched at boot. Keep
  that manifest at `max-age=60` or `no-cache`.

---

## B. Hosting and CDN

### B.1 Cloudflare R2 (verified 2026-09-29)

| Item | Value | Source |
|---|---|---|
| Storage (Standard) | **$0.015/GB-month**, first 10 GB-month free | [V: developers.cloudflare.com/r2/pricing/ (updated 2026-08-07)] |
| Class A (writes, lists) | $4.50/million, 1M free per month | same |
| Class B (reads: Get/Head) | **$0.36/million, 10M free per month** | same |
| Egress | **Free** (Workers API, S3 API, r2.dev, custom domains) | same |
| Rounding | Usage rounded **up** to the next unit (1,000,001 ops → 2M) | same |
| Unauthorized requests (401) | Not billed | same |
| Infrequent Access | $0.01/GB-month, $9 (A) / $0.90 (B) per million, plus $0.01/GB retrieval, no free tier. Not for hot packs | same |
| Object size | 5 TiB per object (5 GiB single-part upload) | [V: developers.cloudflare.com/r2/platform/limits/] |
| Custom domains per bucket | 100 | same |
| r2.dev | "not intended for production", variable rate limit (429 at hundreds of req/s), bandwidth throttled. **Use a custom domain** | same |
| Caching | Custom domains use Cloudflare Cache. Enable **Smart Tiered Cache**. "By default, only certain file types are cached"; `.pck` and `.json` aren't, **`.zst` is** | [V: /r2/buckets/public-buckets/, /cache/concepts/default-cache-behavior/] |
| Max cacheable file | 512 MB on Free/Pro/Business | [V: default cache behavior] |
| Access control | WAF token auth or Zero Trust Access on the custom domain. Disable r2.dev when using them | [V: public buckets] |
| Conditional requests | Workers binding supports conditional headers except `If-Range`. ETag and MD5 checksum exist for non-multipart objects | [V: /r2/api/workers/workers-api-reference/] |
| Large-file policy | Cloudflare's CDN terms restrict serving a disproportionate share of large files *unless* the content is hosted on R2, Stream or Images | [V: blog.cloudflare.com/updated-tos/, developers.cloudflare.com/fundamentals/reference/policies-compliances/delivering-videos-with-cloudflare/] |
| Access logs | R2 Data Access Logs GA (2026-09-04), best effort | [V: Cloudflare changelog] |

**Serving packs directly from the R2 custom domain vs through a Worker:**

- **Direct (recommended for pack bytes):**
  - Cache Rule: `hostname eq cdn.<domain> and starts_with(path, "/packs/")` → eligible for cache,
    Edge TTL 1 year (content-addressed keys never change).
  - Browser TTL 1 year, `immutable`.
  - No per-request cost beyond R2 Class B on cache misses. Supports Range (cache docs cover origin range
    requests [V: /cache/reference/range-requests/]).
- **Worker (recommended for manifests only, optional):**
  - Staged rollout by cohort (hash of install id).
  - Private beta channel auth (bearer token → 401 costs nothing on R2).
  - Kill switch and update-success telemetry.
  - A Worker in front of pack bytes buys nothing and adds per-request billing. Workers Caching (2026)
    bills cache hits as requests [V: /workers/platform/pricing/].
  - Alternative with no Worker: static signed manifests on R2 with a client-side rollout field
    (`rollout.percent`, `salt`). The client computes `hash(install_id+salt) % 100`. The manifest is
    already RSA-signed, so it can't be tampered with.

### B.2 Workers (verified)

- Paid: **$5/month** includes 10M requests and 30M CPU-ms, then **$0.30/M requests** and $0.02/M CPU-ms.
- Free: **100,000 requests/day**, 10 ms CPU.
- Static-asset requests are free and unlimited.

[V: developers.cloudflare.com/workers/platform/pricing/, /workers/platform/limits/]

### B.3 GitHub Releases as a game CDN

| Aspect | Finding | Source |
|---|---|---|
| Asset limits | Each file < 2 GiB; up to 1,000 assets per release | [V: docs.github.com/.../about-releases] |
| Bandwidth | "There is no limit on the total size of a release, nor bandwidth usage" | same |
| …but AUP | "If we determine your bandwidth usage to be significantly excessive in relation to other users of similar features, we reserve the right to suspend your Account, throttle your file hosting…"; no "excessive automated bulk activity" | [V: docs.github.com/.../github-acceptable-use-policies] |
| Rate limits | Unauthenticated limits tightened in 2025 for anonymous traffic including `raw.githubusercontent.com`. Community reports of 429s on `*.githubusercontent.com` | [V: github.blog/changelog/2025-05-08-updated-rate-limits-for-unauthenticated-requests/; github.com/orgs/community/discussions/157887] |
| Redirect | `github.com/.../releases/download/<tag>/<file>` → **302** (`Cache-Control: no-cache`) → `release-assets.githubusercontent.com/github-production-release-asset/...` with a **signed query string expiring in about 40–60 min** (`se=`), served by `Windows-Azure-Blob` behind Varnish/Fastly (`X-Cache: HIT`) | [E10] |
| Range / ETag | `Accept-Ranges: bytes`; `bytes=100-199` → 206; `bytes=a-` → 206; **`bytes=-N` → 501 "Unsupported client range"**. `ETag: "0x8DF1E50E20F075A"` (Azure blob version, not a content hash) | [E10] |
| CORS | **None** on either hop, even with `Origin:`; OPTIONS → 405. **Web builds can't use it** | [E10] |
| Throughput | 85 MB in about 2 s from this datacenter (not representative) | [E10] |

**Verdict:** GitHub Releases are acceptable for desktop and sideload binaries, Obtainium/AltStore feeds,
signed manifests (today) and an **archive or mirror** of packs. They aren't acceptable as the primary game
CDN:

- There's no CORS, so web can't use them.
- There's no cache control, and every download goes through a redirect.
- Rate limiting and AUP enforcement are discretionary.
- 1,000 assets per release means rotating "packs" releases over time.
- At 100k MAI with 6-hourly manifest checks you'd be making about 12M requests/month to github.com from one
  repo. That's the "excessive automated bulk" profile [?].

### B.4 Cost estimate

Assumptions per month:

- Each MAI makes up to **120 manifest checks** (every 6 h while running, worst case). The manifest is
  about 3 KB with an inline signature (one request).
- **20% of MAI are new installs**, each downloading **100 MB** in about 10 pack objects. With zstd this is
  really about 75 MB; not counted.
- Every MAI downloads **5 MB of updates** in about 2 objects.
- Storage: all bases, patches and web builds kept, **≤10 GB** in year one. About 2 GB/year for packs plus
  about 50 MB per web build.

| | 1k MAI | 10k MAI | 100k MAI |
|---|---|---|---|
| Bytes served | ~25 GB | ~254 GB | ~2.5 TB |
| Manifest requests | 120k | 1.2M | 12M |
| Pack GETs | 4k | 40k | 400k |
| **R2 storage** (≤10 GB) | $0 | $0 | $0 (30 GB would be $0.30) |
| **R2 Class A** (CI uploads) | $0 | $0 | $0 |
| **R2 Class B**, worst case: nothing cached at the edge | $0 (124k) | $0 (1.24M) | **$1.08** (12.4M → 2.4M billable → rounded 3M × $0.36) |
| R2 Class B, packs cached (1 y) + manifests cached 60 s | ~$0 | ~$0 | ~$0 (misses only) |
| **R2 egress** | $0 | $0 | $0 |
| **Worker for manifests** (optional) | $0 (≈4k/day < 100k/day free) | $0 (≈40k/day) | **$5.60** on Paid ($5 + 2M × $0.30; CPU ≈12M ms < 30M incl.). **$0.60 marginal** if Polaris Key already pays $5 |
| Web shell on Workers static assets | $0 | $0 | $0 |
| **Total, R2 direct + static manifests** | **$0** | **$0** | **$0–1.08** |
| **Total, R2 + Worker manifests** | $0 | $0 | $0.60–6.70 |
| GitHub Releases (for comparison) | $0 | $0 | $0, **but no web, AUP risk** |
| Metered CDN at ~$0.05–0.09/GB (context only) | ~$1–2 | ~$13–23 | ~$125–230 | 

The last row uses typical list egress prices, not verified here [?].

Takeaway: on R2, cost is essentially **request-driven, not byte-driven**. Put a 60–300 s edge cache on
manifests, or send `If-None-Match`, and it rounds to zero.

---

## C. Delta technology for pack files

### C.1 How Godot's patch and delta mechanism actually works (4.6+, in 4.7.2)

Sources: PR godotengine/godot#112011 (Mikael Hermansson, merged 2025-11-26, 4.6) [V: github.com/godotengine/godot/pull/112011];
docs [V: docs.godotengine.org/en/4.7/tutorials/export/exporting_pcks.html]; source `core/io/delta_encoding.cpp`,
`core/io/file_access_patched.cpp`, `core/io/file_access_pack.cpp`, `editor/export/editor_export_platform.cpp` [S].

**Export options** (already in Diceroll's presets) [S: editor_export_platform.cpp 498–542]:

| Option | Meaning |
|---|---|
| `patch_delta_encoding` (bool, default off) | When exporting a patch (`--export-patch`), try delta-encoding each changed file against its base version |
| `patch_delta_compression_level_zstd` (default 19; negative = fast) | zstd level for the delta |
| `patch_delta_min_reduction` (default 0.1) | Use the delta only if it's ≥10% smaller than the full file; otherwise store the full file |
| `patch_delta_include_filters` / `_exclude_filters` (default `*` / empty) | Globs that pick which files may be delta-encoded |

**Format:**

- A delta entry is a normal PCK directory entry with flag **`PACK_FILE_DELTA = 1<<2`**. Other flags are
  `PACK_FILE_REMOVAL = 1<<1` and `PACK_FILE_ENCRYPTED = 1<<0`.
- Its payload is `"GDDL"` + version byte `1` + a zstd frame compressed with the **old file as a raw
  prefix** (`ZSTD_CCtx_refPrefix`). This is exactly `zstd --patch-from`, per file, with content-size and
  checksum flags.
- PCK format version is 4 [S].

**Runtime:**

- `PackedData::add_path()` appends delta entries to a per-path list. A later full (non-delta) entry with
  `replace_files` clears that list.
- When a file with deltas is opened, `FileAccessPatched` reads the *whole* current base file, applies each
  delta in mount order, and serves the result from memory.
- It does this **lazily, every time the file is opened**, with no caching on disk. Measured overhead is
  about 50–60 µs per small file [E5]; the PR reports about 66 µs on average.

**Base dependency:**

- The delta decodes against *whatever bytes currently back that path*.
- On a wrong base, zstd's checksum fails ("Restored data doesn't match checksum"), the file reads as empty,
  and the resource fails to load [E5]. There's no silent corruption, but the resource is broken.
- The docs say the Base Packs used for export "must be the exact same files that are loaded by the game at
  runtime, in the exact order".
- Sparse bundles can't be delta bases (`ERR_FAIL_COND_V(delta_patch.bundle)`) [S].

**Can we use it for data packs built outside the export?**

- `PCKPacker` (4.7) only has `add_file`, `add_file_from_buffer`, `add_file_removal` and `flush`. There's
  **no delta option** [S: pck_packer.cpp].
- GDScript has no zstd-with-prefix compressor either: `PackedByteArray.compress` takes no dictionary.
- `--export-patch` works only from an export preset against exported base PCKs, and (per the
  content-streaming design doc's experiment) drags in project caches and autoloads.
- **But the runtime doesn't care who wrote the pack.** A small Python writer (`pckwrite.py`, PCK v4 +
  GDDL via `python-zstandard` raw-content dict) produced delta packs that mount over **PCKPacker-built**
  data packs and decode correctly on **desktop and web** [E5][E8].
- Risk: the format is internal (`DELTA_VERSION_NUMBER=1`, `PACK_FORMAT_VERSION_V4`). Pin the engine
  version and run a CI mount test on every engine bump.

### C.2 Measurements

**Real releases** [E1]: desktop PCKs from GitHub Releases, 4.7.2, format v4.

| | rc.1 → rc.2 | rc.2 → rc.3 |
|---|---|---|
| New PCK size | 84,806,720 | 85,253,008 |
| Files changed + added / total | 20 / 6,624 | 124 / 6,709 |
| **Asset (`.godot/imported` content) files changed** | **0** | **0** (6 new UI `.ctex`, 27 `.svg`) |
| What changed | 15 `.gdc`, `uid_cache.bin`, `global_script_class_cache.cfg`, `project.binary`, `main.scn`, 1 json | 30 `.gdc` changed, 22 `.gdc` added, shaders, UI icons |
| Whole-pack replacement (zstd-19 --long) | ~61.9 MB | 61.9 MB |
| File-level patch (changed+added), raw / zstd-19 | 528,721 / 335,983 | 1,165,282 / 754,718 |
| Godot-style GDDL per-file (min_reduction 0.1), raw | 290,991 (6 of 20 delta'd) | 891,144 (9 of 124; new files stored raw) |
| xdelta3 -9 (VCDIFF) | 291,647 | 682,461 |
| zstd -19 --patch-from (whole file) | 312,189 | 718,307 |
| zstd -3 --patch-from | 318,098 | 732,892 |
| HDiffPatch (zstd-19) | 288,693 | 673,945 |
| bsdiff4 | 292,505 | 686,920 |
| FastCDC avg 16 KiB (new chunks raw / zstd, + ~212 KB index) | 928,476 / 795,029 | 2,173,398 / 1,680,935 |
| FastCDC avg 64 KiB (+ ~52 KB index) | 1,947,201 / 1,493,428 | 3,724,489 / 2,516,605 |

Tool costs on the 85 MB pair (4-vCPU VM):

| Tool | Encode | Decode |
|---|---|---|
| xdelta3 | 1.2–1.5 s, 245 MB RSS | 0.09 s, 77 MB |
| zstd-19 `--patch-from` | 16–18 s, 425 MB | 0.12 s, 169 MB |
| HDiffPatch | 8–9 s, ~500 MB | 0.10 s |
| bsdiff4 | 58 s, **1.47 GB** | 0.56 s |

**Synthetic data-pack update** [E4]. Base: the forest unit extracted from rc.3, packed with PCKPacker
(2,654 files, 20,310,196 B). v2: 5 imported `.scn` re-saved by Godot after a small tweak, +10 new
`.scn`, −3 removed (2,661 files).

| Scheme | Bytes to download |
|---|---|
| Whole new pack, raw | 20,298,520 |
| **Whole new pack, zstd-19** | **8,292,751** |
| File-level patch pack (PCKPacker; changed + new + 3 removals), raw | 181,776 |
| File-level patch pack, zstd-19 | 166,208 |
| **Godot GDDL delta patch pack** (4 of 5 modified files delta'd), raw | 66,672 |
| **Godot GDDL delta patch pack, zstd-19** | **52,488** |
| xdelta3 -9 (whole pack) | 56,720 |
| zstd -19 --patch-from (whole pack) | 58,928 |
| HDiffPatch zstd-19 (whole pack) | 50,985 |
| bsdiff4 (whole pack) | 57,107 |
| FastCDC 16 KiB: new chunks raw / zstd (30 of 1,212 chunks, +48 KB index) | 670,083 / 425,112 |
| FastCDC 64 KiB (14 of 285, +11 KB index) | 1,729,319 / 967,380 |

What the numbers show:

- **Imported content changes are file-granular.**
  - New assets are brand-new files; no scheme beats "send the new file".
  - Re-saved scenes (`RSCC`, block-compressed) still delta well, because unchanged blocks survive.
  - Audio (`mp3str`, `oggvorbisstr`) is incompressible.
- Every byte-level method lands within ±10% of the others. The **engine-native per-file delta is as good as
  whole-file bsdiff/xdelta/HDiffPatch**, and it's the only one the client can apply without native code.
- CDC is 3–10× worse at this scale. PCK files are small and aligned, so one changed 2 KB `.gdc` dirties a
  16–64 KiB chunk. CDC would also need a chunk index and many small requests.
- **Transport compression dominates first-install cost.** Per-unit zstd-19 results [E3]:
  - forest 20.0 → 8.2 MB (−59%; the forest colour variants are near-duplicates, see the content-streaming
    doc §2.2)
  - music 18.8 → 18.7 MB (−1%)
  - animations −14%, foes −18%, SFX packs −50–63%
  - all 36 units 80.9 → 61.6 MB
  - whole PCK: gzip-9 −11%, zstd-19 −26%, zstd --long / xz / brotli-11 about −27%

### C.3 Option-by-option evaluation

| # | Scheme | Size savings | Client complexity (GDScript) | Server/CI complexity | Robustness |
|---|---|---|---|---|---|
| 1 | **Whole-pack replacement**, content-addressed and immutable (append-only: new content → new pack; changed pack → new hash) | None within a pack. Wins when changes stay inside small packs; forest change = 8.3 MB | **Trivial**: download, verify, swap | Trivial (already planned) | Excellent. One file, one hash |
| 2 | **File-level overlay patch pack** (changed files + `add_file_removal`), mounted after the base with `replace_files=true` | 50–120× vs zstd full pack (166 KB vs 8.3 MB) | Low: mount order base → patch. Patches must be cumulative (base → latest) to avoid chains. No unmount API, so overlays are boot-time/session-time | Low: PCKPacker in CI, diff by file hash | Good. Needs "patch.from == local base sha" |
| 3 | **Godot GDDL delta patch pack** (engine-native, 4.6+) | Best-in-class here (52 KB) | **Same as #2.** The engine applies deltas at load time. Adds about 50–100 µs per patched file load and a wrong-base failure mode (checksum error) | Medium: needs our Python PCK writer (PCKPacker can't), or `--export-patch` for export-built packs | Good with a `from` hash check; internal format, so pin the engine |
| 3b | **#2/#3 + client-side rehydrate** (mount base+patch → PCKPacker re-pack → verify SHA-256 == new full pack → replace) | Same as #2/#3 | +40 lines: list the pack's files (from the manifest or an index file in the pack), `add_file_from_buffer` each. **136 ms for 20 MB** on desktop [E6] | CI must build full packs deterministically (verified [E2]) | **Excellent**: the client ends with the canonical full pack, verified bit-exact. No chains, no permanent overlays |
| 4 | Binary diff of whole packs (bsdiff, xdelta3/VCDIFF, HDiffPatch, zstd --patch-from) | ≈ #3 | **Needs a GDExtension** (e.g. NodotProject/godot-binary-patcher wraps HDiffPatch [V: github.com/NodotProject/godot-binary-patcher]). Web needs the dlink template + COOP/COEP. iOS needs a static xcframework. Plus disk space for old+new and a crash-safe swap. GDScript can't do it: `decompress()` has no dictionary/prefix input | Medium (diff per old version) | Good, but a native dependency on 6+ platforms |
| 5 | Content-defined chunking (casync/desync, FastCDC; Steam uses about 1 MB chunks [V: partner.steamgames.com/doc/sdk/uploading]) | Worse here (425 KB–1 MB on synthetic, 0.8–2.5 MB on real) | High: chunk index, many ranged/object requests, reassembly and verification in GDScript | High: chunk store, GC of chunks | Good, but lots of moving parts. Pays off for GB-scale depots |

### C.4 Recommendation for Diceroll

**Phase 1** (with the content-pack split): **scheme 1**.

- Immutable, content-addressed full packs.
- `.pck.zst` transport.
- One signed manifest per channel.
- Nothing else. It's already what the content-streaming design proposes. Our data shows content packs
  rarely change, and code updates ride in the main/code pack.

**Phase 2** (cheap add-on, backwards compatible): **scheme 3 + 3b**.

- CI emits, for each pack that changed, **direct patches from the last K=3 full versions to the new full**.
  - Per file: GDDL if ≥10% smaller, else the full file; removals via `PACK_FILE_REMOVAL`; zstd transport.
- Clients that have one of those bases download the patch.
  - **Native** (desktop, Android, iOS sideload): mount base+patch, **rehydrate** into the canonical full
    pack, verify its SHA-256 against the manifest, atomically replace, and mount only the full pack from
    then on.
  - **Web**: mount base+patch as an overlay for the session. Only possible when the base is known to be
    in Cache Storage; otherwise just fetch the full pack, since egress is free.
- Old clients that ignore `patches` still work.

**Skip** bsdiff/HDiffPatch GDExtensions and CDC unless packs grow past about 100 MB and change often.

**For the code/main pack** (desktop `--main-pack` updater, out of this report's core scope):

- The same trick applies. Build `--export-patch --patches <last full main pck>` with
  `patch_delta_encoding=true` (about 0.3–0.9 MB per release instead of 85 MB [E1]).
- The Updater mounts old main + patch, rehydrates a full new main PCK with PCKPacker, verifies it,
  then `--main-pack` relaunches.
- Caveat: the exported main PCK isn't PCKPacker-built. Verify against a manifest SHA-256 of the
  rehydrated output (CI builds it the same way), not the original export bytes [?: to be tested].

### C.5 Manifest structure (schema 2 sketch)

The manifest is signed as today (RSA-SHA256 over exact bytes). Put the signature inline or keep `.sig`
alongside; inline halves the requests.

```json
{
  "schema": 2,
  "channel": "stable",
  "version": "0.3.0",
  "published": "2026-10-05T12:00:00Z",
  "engine": "4.7.2",
  "min_binary": "0.2.0",
  "rollout": { "percent": 25, "salt": "0.3.0" },
  "mirrors": ["https://cdn.example.gg/", "https://github.com/vladzaharia/diceroll/releases/download/packs-2026q4/"],
  "code": { "...": "existing desktop main-pack entry (url, sha256, size), plus optional patches" },
  "packs": {
    "forest": {
      "stage": 2, "required": true,
      "prefixes": ["assets/kaykit/forest/"],
      "index": "res://packs/forest.files",
      "full": {
        "sha256": "212f62e3841bff29…", "size": 20298520, "files": 2661,
        "obj": { "path": "packs/forest/212f62e3841bff29.pck.zst", "enc": "zstd",
                 "sha256": "<sha of .zst>", "size": 8284457 }
      },
      "patches": [
        { "from": "a36db1bcf5b40db8…", "kind": "gddl",
          "obj": { "path": "patches/forest/a36db1bc-212f62e3.pck.zst", "enc": "zstd",
                   "sha256": "…", "size": 52488 }, "size": 66672 }
      ]
    },
    "music": { "...": "..." }
  }
}
```

- **Everything is keyed by content hash.** Object paths embed the hash, so every URL is immutable and
  CDN-cacheable forever. Only `channels/*.json` changes.
- `full.sha256` is the hash of the **decompressed canonical PCK**. That's what the client stores, mounts
  and rehydrates to. `obj.sha256` is the hash of the transport file, checked while downloading and used
  to resume.
- `index` is a sorted file list inside the pack (shipped in it, and updated by patches). It lets the client
  rehydrate without the manifest carrying thousands of paths. `.godot/imported/` is shared by every pack,
  so the pack's own list is the only reliable scope.
- `patches[].from` must equal the local full pack's hash before mounting. That's the guard against
  GDDL's wrong-base failure.
- `mirrors`: try in order. The same hashes make any mirror safe.
- `rollout`: the client computes `sha256(install_id + salt)[0:4] % 100 < percent`. No server logic needed.

**Client algorithm per pack:**

1. Is `have == full.sha256`? Done.
2. Otherwise, if a patch has `from == have`: download it, then either rehydrate (native) or overlay
   (web session).
3. Otherwise, download `full.obj`.
4. Decompress, verify `full.sha256`, write to `packs/<id>.pck.new`, rename, record, and GC the old file.

---

## D. Resumable downloads and integrity

- **Godot `HTTPRequest`** [S: scene/main/http_request.cpp 4.7-stable][E11]:
  - Custom headers (e.g. `Range`) are **kept across redirects** for GET. Verified: `Range: bytes=20000000-`
    through a 302 gives 206 with the remainder.
  - `download_file` opens the target with `WRITE`, which **truncates** it. On any failure or cancel,
    `cancel_request()` **deletes** the partial file.
  - So resume must be implemented as **segments**: request `Range: bytes=a-b` (4–8 MiB) into memory or a
    temp file, append it to `<pack>.part` with `FileAccess.open(READ_WRITE)` + `seek_end()`, and persist
    progress (the `.part` length). On restart, rehash the existing `.part` into a fresh `HashingContext`
    and continue.
  - If a server ignores Range and returns **200**, discard the `.part` and take the full body.
  - Check `response_code` yourself. `download_file` writes whatever body arrives, even for 404 pages [S].
  - On **native**, set `use_threads = true` (otherwise one chunk per frame) and `download_chunk_size`
    of 256 KiB–1 MiB. On **web**, `use_threads` isn't available; use 1–4 MiB chunks [E8] and never
    `download_file` in 4.7.x.
  - Set `accept_gzip = false` for pack downloads. `.zst` is already compressed, and it keeps
    Range/Content-Length semantics simple.
- **R2**:
  - Range is served, including from cache [V: /cache/reference/range-requests/].
  - ETag is present and equals the MD5 for single-part uploads [V: Workers API reference].
  - Content-addressed immutable keys make `If-Range` unnecessary. If the bytes behind a URL never change,
    a resumed range can't mix versions.
  - The Workers binding doesn't support `If-Range` [V].
- **GitHub Releases** [E10]:
  - `bytes=a-b` and `bytes=a-` → 206; **`bytes=-N` → 501**.
  - The ETag is an Azure blob version string.
  - The redirect URL expires in about 1 h, so always re-request the `github.com/.../download/...` URL (Godot
    follows the 302 each time) rather than caching the signed URL.
- **Integrity chain:**
  - The signed manifest (existing RSA key in `update_keys.gd`) holds SHA-256 for every transport object and
    every canonical pack.
  - The zstd frame checksum is an extra safety net.
  - GDDL deltas carry their own zstd checksum (wrong base → hard failure) [E5].
  - Rehydrated packs are verified bit-exact against `full.sha256` [E6].
- **Hashing cost** (`HashingContext` SHA-256, 1 MiB chunks):
  - 160–222 MB/s on desktop (x86 VM, official 4.7.2) and about 225 MB/s in wasm (Chromium, same host)
    [E7][E8]. MD5 is about 2× faster but not a security hash.
  - Phones: expect 50–200 MB/s [?]; mbedTLS may or may not use ARMv8 SHA instructions in official builds.
    Either way, 20 MB is ≤0.4 s, negligible next to the download.
  - Hash while downloading (per segment) so verification costs no extra I/O.
  - `FileAccess.get_sha256(path)` exists for whole-file checks [E7].

---

## Risks and open questions

1. The **`download_file` web bug** is fixed on `master` but not on the 4.7 branch (checked 2026-09-29).
   Check each 4.7.x/4.8 release; the in-memory workaround is harmless anyway.
2. **GDDL is an internal format.** CI must run a mount-and-verify test (like E5) on every engine upgrade. If
   the format ever changes, fall back to file-level patches (#2), which need only PCKPacker.
3. **No unmount API.** Overlays and mounted packs persist until restart or reload. Web memory grows with
   every pack mounted in a session; design routes to need few packs and keep the iOS budget in mind
   (about 300 MB).
4. **Deterministic packs**: PCKPacker output depends on the file order and alignment. Always add files in
   sorted path order with alignment 32. Verified deterministic for identical input [E2].
5. **UID warnings**: scenes loaded from PCKPacker packs log `invalid UID … using text path instead`
   warnings for external textures (seen in E4). Loads succeed. To silence them, ship a small `uids` list
   per pack and call `ResourceUID.add_id()` at mount (as the content-streaming doc notes).
6. **Cloudflare cache rules**: `.pck` and `.json` aren't cached by default. Name objects `.pck.zst`, or add
   explicit Cache Rules; set a short TTL for manifests.
7. Not verified here:
   - GitHub Pages compression and headers for `.wasm`.
   - Chrome's HTTP-cache entry size limits for 20 MB responses on low-storage devices (the persistent
     profile cached it in E8).
   - Safari's behaviour on the same web test (no WebKit run).

---

## Appendix: experiment details and reproduction

The experiment files lived in a throwaway scratch workspace (not kept).

- `pck.py`: PCK v2–v4 directory reader. `pckwrite.py`: PCK v4 writer with GDDL (`encode = b"GDDL\x01" +
  zstd(level 19, raw-content dict=old, content size + checksum)`) and removal entries.
- **E1** `filediff.py`, `bench_bin.py`, `bench_file.py`, run on `desktop-rc.{1,2,3}.pck`, downloaded from the
  public v0.1.0-rc.* releases. Tools: xdelta3 3.0.11 (apt), zstd 1.5.5, bsdiff4 1.2.6, hdiffpatch 2.4.0
  (pip), fastcdc 1.7.0, python-zstandard 0.25.0.
- **E2/E4** `proj/build_pack.gd` (PCKPacker, sorted, alignment 32). Unit files extracted from rc.3 into
  `units/`. v2 made by `proj/mod_scenes.gd` (re-saves 5 `.scn` with a position/name tweak,
  `FLAG_COMPRESS`), plus 10 dungeon_x scenes copied in as new files and 3 files removed. `bench_synth.py`
  measures all schemes.
- **E5** `proj/test_mount.gd`: base + overlay (file-level and GDDL), plus the wrong-base case.
  - Results: 1334/1334 imported files match v2 and removals are honoured.
  - Mount times: 20 MB base 9.5–11.9 ms; overlay 0.1–0.2 ms.
  - GDDL read overhead: small files 95–122 µs vs 43–79 µs plain.
- **E6** `proj/rehydrate.gd`: sha256 of the rehydrated pack =
  `212f62e3841bff292a809d2699cc8202b21826a363787f3c454d9ddf6efa25f2` = the CI-built `forest_v2.pck`.
- **E7** `proj/test_util.gd`: `decompress(20298520, COMPRESSION_ZSTD)` works for both plain and
  `--long=27` frames (17 ms).
- **E8** `webtest/` project (gl_compatibility; preset Web, nothreads). Official 4.7.2 templates were
  extracted from the .tpz via HTTP Range (`remotezip`, with suffix ranges disabled because of GitHub's 501).
  Served by `serve.py` and driven by Playwright (`run_web.py`: user:// variant; `run_web2.py`: /tmp +
  HTTP-cache variant) in chromium-headless-shell 153 with SwiftShader.
  - Log excerpts:
    - `download_file() result=0 code=200 -> file exists afterwards? false`
    - `in-memory download … bytes=20310196 ms=958`
    - `mount base ok=true us=16600`
    - `sha … match=true`
    - run 2: `base pack already in user:// (persisted across reload)`, boot `js_heap=88MB`
    - /tmp variant: `server requests for pack: 1` over 2 loads, boot heap 53 MB
    - 64 KiB chunk: `ms=5535`; 1 MiB chunk: `ms=1248–1535` (from HTTP cache / network, localhost)
- **E10** `curl` with `-H "Origin: …"` and Range against release assets. E11: `proj/t2.gd` + `rangeserve.py`
  (local server with 302 + Range).

## Sources

- Godot web export docs (4.7): https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html
- Godot packs/patches docs (4.7): https://docs.godotengine.org/en/4.7/tutorials/export/exporting_pcks.html
- Delta-encoding PR #112011: https://github.com/godotengine/godot/pull/112011 ; 4.6 dev5 post: https://godotengine.org/article/dev-snapshot-godot-4-6-dev-5/ ; 4.6 release page: https://godotengine.org/releases/4.6/ ; 4.7 release page: https://godotengine.org/releases/4.7/
- Godot source (4.7-stable): core/io/{delta_encoding,file_access_patched,file_access_pack,pck_packer}.cpp, editor/export/editor_export_platform.cpp, scene/main/http_request.cpp (and master for the fix), platform/web/{http_client_web.cpp,os_web.cpp,detect.py,export/export_plugin.cpp,js/libs/library_godot_os.js,js/libs/library_godot_fetch.js,js/engine/{engine,config,preloader}.js}, misc/dist/html/service-worker.js — https://github.com/godotengine/godot/tree/4.7-stable
- Third-party claim on 4.7 wasm64 (unverified): https://app.cinevva.com/news/2026-06-19-godot-4-7-released
- Forum reports on web packs: https://forum.godotengine.org/t/multiple-pcks-within-web-export/59718 ; https://forum.godotengine.org/t/lazy-loading-scenes-resources-from-a-server/47301
- Cloudflare R2 pricing: https://developers.cloudflare.com/r2/pricing/ ; limits: https://developers.cloudflare.com/r2/platform/limits/ ; public buckets: https://developers.cloudflare.com/r2/buckets/public-buckets/ ; CORS: https://developers.cloudflare.com/r2/buckets/cors/ ; Workers API: https://developers.cloudflare.com/r2/api/workers/workers-api-reference/
- Cloudflare cache: https://developers.cloudflare.com/cache/concepts/default-cache-behavior/ ; range requests: https://developers.cloudflare.com/cache/reference/range-requests/ ; compression rules: https://developers.cloudflare.com/rules/compression-rules/ , https://developers.cloudflare.com/rules/compression-rules/examples/enable-zstandard/
- Workers pricing/limits/static assets: https://developers.cloudflare.com/workers/platform/pricing/ ; https://developers.cloudflare.com/workers/platform/limits/ ; https://developers.cloudflare.com/workers/static-assets/headers/ ; static asset limit changelog: https://developers.cloudflare.com/changelog/post/2025-09-02-increased-static-asset-limits/
- Pages limits / Workers-first guidance: https://developers.cloudflare.com/pages/platform/limits/ ; https://developers.cloudflare.com/pages/migrations/ ; https://developers.cloudflare.com/workers/static-assets/migration-guides/migrate-from-pages/
- Cloudflare large-file terms: https://blog.cloudflare.com/updated-tos/ ; https://developers.cloudflare.com/fundamentals/reference/policies-compliances/delivering-videos-with-cloudflare/
- GitHub releases limits: https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases ; AUP: https://docs.github.com/en/site-policy/acceptable-use-policies/github-acceptable-use-policies ; rate limits: https://github.blog/changelog/2025-05-08-updated-rate-limits-for-unauthenticated-requests/ , https://github.com/orgs/community/discussions/157887 ; Pages limits: https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits
- itch.io HTML5: https://itch.io/docs/creators/html5
- WebKit wasm memory bug: https://bugs.webkit.org/show_bug.cgi?id=269777 ; WebKit storage policy: https://webkit.org/blog/14403/updates-to-storage-policy/ ; MDN OPFS: https://developer.mozilla.org/en-US/docs/Web/API/File_System_API/Origin_private_file_system ; MDN quotas: https://developer.mozilla.org/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria
- Steam chunking: https://partner.steamgames.com/doc/sdk/uploading ; Godot HDiffPatch GDExtension: https://github.com/NodotProject/godot-binary-patcher ; HDiffPatch: https://github.com/sisong/HDiffPatch ; casync: https://github.com/systemd/casync ; desync: https://github.com/folbricht/desync
- Existing Diceroll design: docs/design/2026-09-29-content-streaming.md (repo)
