#!/usr/bin/env python3
"""Retarget an arm64 *device* iOS static library to the arm64 *simulator* platform.

Why: the official Godot 4.7.2 iOS template ships its "ios-arm64_x86_64-simulator"
libgodot.a with only an x86_64 slice, which needs Rosetta to run in the Simulator on
Apple Silicon. The arm64 device objects run fine in an arm64 Simulator once their
LC_BUILD_VERSION platform is switched from IOS (2) to IOSSIMULATOR (7) (patched in
place: `vtool -set-build-version` fails with "not enough space to hold load commands").

Usage: ios_sim_retarget.py <device_lib.a> <out_sim_lib.a>

Extracts every member (the archive has duplicate member names, so `ar x` can't be
used), patches the platform field, adds stubs for device-only Metal symbols the
Simulator SDK lacks (STUBS), and re-archives with `libtool`.
"""
import os
import struct
import subprocess
import sys
import tempfile

LC_BUILD_VERSION = 0x32
LC_VERSION_MIN_IPHONEOS = 0x25
PLATFORM_IOS = 2
PLATFORM_IOSSIMULATOR = 7

# Device-only Metal symbols referenced by libgodot that the iPhoneSimulator SDK doesn't
# export (MTLIO* / MTLTensor aren't usable in the Simulator anyway).
STUBS = """
#import <Foundation/Foundation.h>
NSString *const MTLIOErrorDomain = @"MTLIOErrorDomain";
NSString *const MTLTensorDomain = @"MTLTensorDomain";
"""


def members(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b"!<arch>\n":
        sys.exit(f"{path}: not an ar archive")
    pos = 8
    while pos + 60 <= len(data):
        hdr = data[pos:pos + 60]
        name = hdr[:16].decode().strip()
        size = int(hdr[48:58].decode().strip())
        body = data[pos + 60:pos + 60 + size]
        if name.startswith("#1/"):
            n = int(name[3:])
            name = body[:n].rstrip(b"\0").decode()
            body = body[n:]
        pos += 60 + size + (size & 1)
        if name.startswith("__.SYMDEF"):
            continue
        yield name, body


def patch(f, name):
    """Flips LC_BUILD_VERSION.platform IOS (2) -> IOSSIMULATOR (7) in a thin arm64 Mach-O object."""
    hdr = f.read(32)
    magic, _cpu, _sub, _ftype, ncmds, _size = struct.unpack("<IiiIII", hdr[:24])
    if magic != 0xFEEDFACF:
        sys.exit(f"{name}: not a 64-bit Mach-O object")
    off = 32
    found = False
    for _ in range(ncmds):
        f.seek(off)
        cmd, cmdsize = struct.unpack("<II", f.read(8))
        if cmd == LC_VERSION_MIN_IPHONEOS:
            sys.exit(f"{name}: has LC_VERSION_MIN_IPHONEOS, can't retarget in place")
        if cmd == LC_BUILD_VERSION:
            platform = struct.unpack("<I", f.read(4))[0]
            if platform not in (PLATFORM_IOS, PLATFORM_IOSSIMULATOR):
                sys.exit(f"{name}: unexpected platform {platform}")
            f.seek(off + 8)
            f.write(struct.pack("<I", PLATFORM_IOSSIMULATOR))
            found = True
        off += cmdsize
    if not found:
        sys.exit(f"{name}: no LC_BUILD_VERSION")


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    src, out = sys.argv[1], sys.argv[2]
    with tempfile.TemporaryDirectory() as tmp:
        files = []
        for i, (name, body) in enumerate(members(src)):
            p = os.path.join(tmp, f"{i:05d}_{name}")
            with open(p, "wb") as f:
                f.write(body)
            files.append(p)

        for p in files:
            with open(p, "r+b") as f:
                patch(f, os.path.basename(p))
        stub_src = os.path.join(tmp, "zz_sim_stubs.m")
        with open(stub_src, "w") as f:
            f.write(STUBS)
        stub_obj = os.path.join(tmp, "zz_sim_stubs.o")
        subprocess.check_call(["xcrun", "--sdk", "iphonesimulator", "clang", "-c", "-fobjc-arc",
                               "-target", "arm64-apple-ios15.0-simulator", "-o", stub_obj, stub_src])
        files.append(stub_obj)
        lst = os.path.join(tmp, "files.txt")
        with open(lst, "w") as f:
            f.write("\n".join(files))
        os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
        subprocess.check_call(["libtool", "-static", "-no_warning_for_no_symbols", "-o", out, "-filelist", lst])
    print(f"retargeted {len(files)} objects -> {out}")


if __name__ == "__main__":
    main()
