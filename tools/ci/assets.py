#!/usr/bin/env python3
"""Per-unit encrypted asset bundles for CI (see docs/ASSETS.md, "CI asset bundles").

Third-party assets (KayKit FREE + paid EXTRA packs, Kenney SFX, CC0 music (OpenGameArt), fonts) are never
committed to the public game repo. CI gets them from a PRIVATE store as individually encrypted,
content-addressed bundles, one per "unit" (a runtime asset folder such as assets/kaykit/forest),
so a changed pack only re-uploads and re-downloads its own unit.

  unit hash  = sha256 over sorted lines "<relpath>\\t<sha256(file)>\\n" of the unit's files
  bundle     = bundles/<unit>/<unit>-<hash[:16]>.tar.zst.age  (deterministic tar, zstd, age X25519)
  lock file  = tools/ci/assets.lock.json (committed, public: unit names, hashes, sizes only)
  manifest   = manifest.json in the store (the union of all bundles ever uploaded)

Old bundles are never deleted from the store, so every past commit's lock file stays buildable.

Commands
  units                         list discovered units with their current hash
  pack   [--out DIR]            encrypt changed units into DIR (default build/asset-bundles) and
                                rewrite the lock file (only new hashes are re-packed)
  upload --repo PATH [--push]   copy new bundles + manifest into a local clone of the private
                                assets repo, commit (and push) them
  upload --s3 s3://bucket/pfx   ... or to an S3-compatible bucket (aws CLI; R2: AWS_ENDPOINT_URL)
  fetch  [--git URL | --dir PATH | --s3 URI | --gh-release OWNER/REPO@TAG] [--cache DIR]
                                download the lock file's bundles that aren't cached yet, verify
                                the ciphertext sha256, decrypt, extract, verify the plaintext hash
  verify                        check the working tree's units against the lock file
  seal DIR OUT / unseal IN DIR  encrypt / decrypt any directory (the CI .godot import cache)

Secrets (environment only; never printed, written to 0600 temp files that are removed after use)
  ASSETS_AGE_KEY     the age identity ("AGE-SECRET-KEY-1...") that decrypts the bundles
  ASSETS_DEPLOY_KEY  an SSH private key (read-only deploy key on the assets repo) for --git
  GH_TOKEN           a token with read access to the assets repo, for --gh-release
  AWS_*              credentials (+ AWS_ENDPOINT_URL for Cloudflare R2) for --s3
The public age recipient is tools/ci/assets_recipient.txt (packing needs no secret).

Requires: python3 >= 3.10, zstd, age (and git / aws / gh for the matching source).
"""

from __future__ import annotations

import argparse
import contextlib
import hashlib
import io
import json
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOCK = ROOT / "tools/ci/assets.lock.json"
RECIPIENT = ROOT / "tools/ci/assets_recipient.txt"
SKIP_NAMES = {".DS_Store", "Thumbs.db"}

# (unit prefix, runtime dir relative to the project, split into one unit per sub-folder?, file filter)
UNIT_ROOTS = [
    ("kaykit", "assets/kaykit", True, None),
    ("sfx", "assets/audio/sfx", True, None),
    ("music", "assets/audio/music", False, None),
    ("fonts", "assets/fonts", False, None),
    # Rendered UI icons derive from paid models (tools/render_icons.sh); only the PNGs are ignored.
    ("rendered-icons", "ui/icons/rendered", False, (".png", ".png.import")),
]


def log(msg: str) -> None:
    print(f"assets: {msg}", flush=True)


def die(msg: str) -> None:
    print(f"assets: ERROR: {msg}", file=sys.stderr, flush=True)
    sys.exit(1)


# --- units -------------------------------------------------------------------------------------

def unit_files(path: Path, suffixes: tuple[str, ...] | None) -> list[Path]:
    out = []
    for p in sorted(path.rglob("*")):
        if not p.is_file() or p.name in SKIP_NAMES:
            continue
        if suffixes and not p.name.endswith(suffixes):
            continue
        out.append(p)
    return out


def file_sha(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def unit_hash(path: Path, suffixes) -> tuple[str, int, int]:
    """Returns (hash, file count, plaintext bytes) of a unit folder."""
    h = hashlib.sha256()
    n = size = 0
    for p in unit_files(path, suffixes):
        rel = p.relative_to(path).as_posix()
        h.update(f"{rel}\t{file_sha(p)}\n".encode())
        n += 1
        size += p.stat().st_size
    return h.hexdigest(), n, size


def discover(root: Path = ROOT) -> dict[str, dict]:
    units: dict[str, dict] = {}
    for prefix, rel, split, suffixes in UNIT_ROOTS:
        base = root / rel
        if not base.is_dir():
            continue
        dirs = sorted(d for d in base.iterdir() if d.is_dir()) if split else [base]
        for d in dirs:
            if not unit_files(d, suffixes):
                continue
            name = f"{prefix}-{d.name}" if split else prefix
            units[name] = {"dest": d.relative_to(root).as_posix(), "filter": list(suffixes or [])}
    return units


def bundle_rel(name: str, digest: str) -> str:
    return f"bundles/{name}/{name}-{digest[:16]}.tar.zst.age"


# --- crypto / archive helpers --------------------------------------------------------------------

def need(tool: str) -> None:
    if shutil.which(tool) is None:
        die(f"'{tool}' not found on PATH")


@contextlib.contextmanager
def secret_file(env: str, required: bool = True):
    """Writes a secret from the environment to a private temp file; yields its path or None."""
    value = os.environ.get(env, "")
    if not value.strip():
        if required:
            die(f"{env} is not set")
        yield None
        return
    fd, path = tempfile.mkstemp(prefix="dr_", dir=os.environ.get("RUNNER_TEMP"))
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w") as f:
            f.write(value.strip() + "\n")
        yield path
    finally:
        with contextlib.suppress(FileNotFoundError):
            os.remove(path)


def recipient() -> str:
    if not RECIPIENT.exists():
        die(f"missing {RECIPIENT.relative_to(ROOT)} (age-keygen -y key.txt > it)")
    lines = [ln.strip() for ln in RECIPIENT.read_text().splitlines()]
    keys = [ln for ln in lines if ln.startswith("age1")]
    if not keys:
        die("no age1... recipient in assets_recipient.txt")
    return keys[0]


def run(cmd: list[str], data: bytes | None = None) -> bytes:
    r = subprocess.run(cmd, input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if r.returncode != 0:
        # stderr of age/zstd never contains key material; still keep it short.
        die(f"{cmd[0]} failed: {r.stderr.decode(errors='replace')[:300]}")
    return r.stdout


def tar_dir(path: Path, suffixes) -> bytes:
    """Deterministic tar (sorted, mtime 0, no owners) of a unit's files."""
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w", format=tarfile.PAX_FORMAT) as tar:
        for p in unit_files(path, suffixes):
            info = tarfile.TarInfo(p.relative_to(path).as_posix())
            info.size = p.stat().st_size
            info.mtime = 0
            info.mode = 0o644
            info.uid = info.gid = 0
            info.uname = info.gname = ""
            with p.open("rb") as f:
                tar.addfile(info, f)
    return buf.getvalue()


def encrypt_dir(path: Path, suffixes, out: Path) -> None:
    need("zstd")
    need("age")
    packed = run(["zstd", "-q", "-19", "-T0", "-c"], tar_dir(path, suffixes))
    out.parent.mkdir(parents=True, exist_ok=True)
    tmp = out.with_suffix(out.suffix + ".part")
    run(["age", "-r", recipient(), "-o", str(tmp)], packed)
    tmp.replace(out)


def decrypt_to(bundle: Path, dest: Path, identity: str, suffixes=None) -> None:
    need("zstd")
    need("age")
    plain = run(["age", "-d", "-i", identity, str(bundle)])
    raw = run(["zstd", "-q", "-d", "-c"], plain)
    if dest.exists():
        if suffixes:  # shared folder (e.g. ui/icons/rendered): only replace the unit's files
            for p in unit_files(dest, tuple(suffixes)):
                p.unlink()
        else:
            shutil.rmtree(dest)
    dest.mkdir(parents=True, exist_ok=True)
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r") as tar:
        tar.extractall(dest, filter="data")


# --- lock / manifest -----------------------------------------------------------------------------

def load_json(p: Path, default):
    return json.loads(p.read_text()) if p.exists() else default


def write_json(p: Path, data) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")


def lock_hash(lock: dict) -> str:
    """Short digest of the lock's unit set (CI cache keys)."""
    s = "".join(f"{k}:{v['sha256']}\n" for k, v in sorted(lock["units"].items()))
    return hashlib.sha256(s.encode()).hexdigest()[:16]


# --- commands ------------------------------------------------------------------------------------

def cmd_units(_args) -> None:
    for name, u in discover().items():
        digest, n, size = unit_hash(ROOT / u["dest"], tuple(u["filter"]) or None)
        print(f"{name:32} {digest[:16]} {n:5d} files {size / 1e6:8.1f} MB  {u['dest']}")


def cmd_pack(args) -> None:
    out = Path(args.out).resolve()
    manifest = load_json(out / "manifest.json", {"schema": 1, "bundles": {}})
    lock = {"schema": 1, "units": {}}
    units = discover()
    if not units:
        die("no asset units found (run tools/import_assets.sh first)")
    packed = 0
    for name, u in units.items():
        suffixes = tuple(u["filter"]) or None
        digest, n, size = unit_hash(ROOT / u["dest"], suffixes)
        rel = bundle_rel(name, digest)
        target = out / rel
        if not target.exists():
            log(f"pack {name} ({n} files, {size / 1e6:.1f} MB)")
            encrypt_dir(ROOT / u["dest"], suffixes, target)
            packed += 1
        entry = {"sha256": digest, "file": rel, "dest": u["dest"], "files": n, "plain_bytes": size,
                 "bundle_sha256": file_sha(target), "bundle_bytes": target.stat().st_size}
        if u["filter"]:
            entry["filter"] = u["filter"]
        lock["units"][name] = entry
        manifest["bundles"].setdefault(rel, {**entry, "unit": name, "added": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())})
    write_json(out / "manifest.json", manifest)
    lock["lock_hash"] = lock_hash(lock)
    write_json(Path(args.lock), lock)
    total = sum(u["bundle_bytes"] for u in lock["units"].values())
    log(f"{len(units)} units ({packed} newly packed, {total / 1e6:.1f} MB encrypted) -> {out}")
    log(f"lock file: {Path(args.lock).resolve()} (commit it with the code that needs these assets)")


def cmd_upload(args) -> None:
    src = Path(args.out).resolve()
    manifest = load_json(src / "manifest.json", None)
    lock = load_json(Path(args.lock), None)
    if manifest is None or lock is None:
        die("nothing packed yet (run: tools/ci/assets.py pack)")
    wanted = [u["file"] for u in lock["units"].values()]
    if args.s3:
        need("aws")
        base = args.s3.rstrip("/")
        for rel in wanted:
            r = subprocess.run(["aws", "s3", "ls", f"{base}/{rel}"], capture_output=True)
            if r.returncode == 0 and r.stdout.strip():
                continue
            log(f"upload {rel}")
            run(["aws", "s3", "cp", "--only-show-errors", str(src / rel), f"{base}/{rel}"])
        run(["aws", "s3", "cp", "--only-show-errors", str(src / "manifest.json"), f"{base}/manifest.json"])
        log("uploaded to S3")
        return
    repo = Path(args.repo).resolve()
    if not (repo / ".git").exists():
        die(f"{repo} is not a git clone of the assets repo")
    added = []
    for rel in wanted:
        dst = repo / rel
        if dst.exists():
            continue
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src / rel, dst)
        added.append(rel)
    remote_manifest = load_json(repo / "manifest.json", {"schema": 1, "bundles": {}})
    for rel, e in manifest["bundles"].items():
        if (repo / rel).exists():
            remote_manifest["bundles"].setdefault(rel, e)
    write_json(repo / "manifest.json", remote_manifest)
    subprocess.run(["git", "-C", str(repo), "add", "manifest.json", *added], check=True)
    if subprocess.run(["git", "-C", str(repo), "diff", "--cached", "--quiet"]).returncode == 0:
        log("assets repo already up to date")
        return
    msg = f"bundles: {len(added)} new ({', '.join(sorted({Path(a).parent.name for a in added})) or 'manifest'})"
    subprocess.run(["git", "-C", str(repo), "commit", "-q", "-m", msg], check=True)
    log(f"committed {len(added)} bundles in {repo}")
    if args.push:
        subprocess.run(["git", "-C", str(repo), "push", "-q"], check=True)
        log("pushed")


def fetch_missing(args, missing: list[str], cache: Path) -> None:
    if not missing:
        return
    if args.dir:
        for rel in missing:
            (cache / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(Path(args.dir) / rel, cache / rel)
    elif args.s3:
        need("aws")
        for rel in missing:
            run(["aws", "s3", "cp", "--only-show-errors", f"{args.s3.rstrip('/')}/{rel}", str(cache / rel)])
    elif args.gh_release:
        need("gh")
        repo, _, tag = args.gh_release.partition("@")
        for rel in missing:
            (cache / rel).parent.mkdir(parents=True, exist_ok=True)
            run(["gh", "release", "download", tag or "bundles", "-R", repo, "-p", Path(rel).name,
                 "-O", str(cache / rel), "--clobber"])
    else:
        need("git")
        url = args.git or os.environ.get("ASSETS_GIT_URL", "")
        if not url:
            die("no source: pass --git URL, --dir, --s3 or --gh-release (or set ASSETS_GIT_URL)")
        with secret_file("ASSETS_DEPLOY_KEY", required=False) as key, tempfile.TemporaryDirectory() as tmp:
            env = dict(os.environ)
            if key:
                env["GIT_SSH_COMMAND"] = f"ssh -i {key} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
            clone = Path(tmp) / "store"

            def git(*a):
                r = subprocess.run(["git", *a], env=env, capture_output=True, text=True)
                if r.returncode != 0:
                    die(f"git {a[0]} failed: {r.stderr.strip()[:300]}")

            # Blobless, depth-1 clone: only the bundles we check out below are downloaded.
            git("clone", "-q", "--filter=blob:none", "--no-checkout", "--depth", "1", url, str(clone))
            git("-C", str(clone), "checkout", "-q", "HEAD", "--", *missing)
            for rel in missing:
                (cache / rel).parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(clone / rel), cache / rel)


def cmd_fetch(args) -> None:
    lock = load_json(Path(args.lock), None)
    if lock is None:
        die(f"no lock file at {args.lock}")
    cache = Path(args.cache).resolve()
    todo = {}
    for name, u in lock["units"].items():
        dest = ROOT / u["dest"]
        suffixes = tuple(u.get("filter") or []) or None
        if dest.is_dir() and unit_hash(dest, suffixes)[0] == u["sha256"]:
            continue  # already extracted and intact
        todo[name] = u
    if not todo:
        log(f"all {len(lock['units'])} units present")
        return
    missing = []
    for u in todo.values():
        f = cache / u["file"]
        if not (f.exists() and file_sha(f) == u["bundle_sha256"]):
            missing.append(u["file"])
    log(f"{len(todo)} units to extract, {len(missing)} bundles to download, {len(todo) - len(missing)} cached")
    fetch_missing(args, missing, cache)
    with secret_file("ASSETS_AGE_KEY") as identity:
        for name, u in todo.items():
            f = cache / u["file"]
            if file_sha(f) != u["bundle_sha256"]:
                die(f"{name}: bundle checksum mismatch (store corrupted or lock out of date)")
            suffixes = tuple(u.get("filter") or []) or None
            decrypt_to(f, ROOT / u["dest"], identity, suffixes)
            if unit_hash(ROOT / u["dest"], suffixes)[0] != u["sha256"]:
                die(f"{name}: extracted content does not match the lock hash")
    log(f"extracted {len(todo)} units")


def cmd_verify(args) -> None:
    lock = load_json(Path(args.lock), None)
    if lock is None:
        die(f"no lock file at {args.lock}")
    bad = 0
    for name, u in lock["units"].items():
        dest = ROOT / u["dest"]
        suffixes = tuple(u.get("filter") or []) or None
        got = unit_hash(dest, suffixes)[0] if dest.is_dir() else "missing"
        if got != u["sha256"]:
            bad += 1
            log(f"{name}: {got[:16]} != lock {u['sha256'][:16]}")
    extra = set(discover()) - set(lock["units"])
    for name in sorted(extra):
        log(f"{name}: present locally but not in the lock (run pack)")
    if bad or extra:
        sys.exit(1)
    log(f"all {len(lock['units'])} units match the lock")


def cmd_hash(args) -> None:
    lock = load_json(Path(args.lock), None)
    print(lock_hash(lock) if lock else "none")


def cmd_seal(args) -> None:
    src = Path(args.src)
    if not src.is_dir():
        die(f"{src} is not a directory")
    encrypt_dir(src, None, Path(args.out))
    log(f"sealed {src} -> {args.out} ({Path(args.out).stat().st_size / 1e6:.1f} MB)")


def cmd_unseal(args) -> None:
    with secret_file("ASSETS_AGE_KEY") as identity:
        decrypt_to(Path(args.bundle), Path(args.dest), identity)
    log(f"unsealed {args.bundle} -> {args.dest}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--lock", default=str(LOCK), help="lock file (default tools/ci/assets.lock.json)")
    ap.add_argument("--out", default=str(ROOT / "build/asset-bundles"), help="local bundle store")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("units").set_defaults(fn=cmd_units)
    sub.add_parser("pack").set_defaults(fn=cmd_pack)
    sub.add_parser("hash", help="print the lock's short digest (cache keys)").set_defaults(fn=cmd_hash)
    up = sub.add_parser("upload")
    up.add_argument("--repo", help="local clone of the private assets repo")
    up.add_argument("--s3", help="s3://bucket/prefix (aws CLI; set AWS_ENDPOINT_URL for R2)")
    up.add_argument("--push", action="store_true")
    up.set_defaults(fn=cmd_upload)
    fe = sub.add_parser("fetch")
    src = fe.add_mutually_exclusive_group()
    src.add_argument("--git", help="assets repo URL (ssh; ASSETS_DEPLOY_KEY) [env ASSETS_GIT_URL]")
    src.add_argument("--dir", help="local store directory (tests / offline)")
    src.add_argument("--s3", help="s3://bucket/prefix")
    src.add_argument("--gh-release", help="OWNER/REPO@TAG with flat bundle assets (GH_TOKEN)")
    fe.add_argument("--cache", default=str(ROOT / ".ci-cache"), help="encrypted bundle cache dir")
    fe.set_defaults(fn=cmd_fetch)
    sub.add_parser("verify").set_defaults(fn=cmd_verify)
    se = sub.add_parser("seal")
    se.add_argument("src")
    se.add_argument("out")
    se.set_defaults(fn=cmd_seal)
    us = sub.add_parser("unseal")
    us.add_argument("bundle")
    us.add_argument("dest")
    us.set_defaults(fn=cmd_unseal)
    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
