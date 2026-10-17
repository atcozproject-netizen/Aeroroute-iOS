#!/usr/bin/env python3
"""Build Aeroroute with Godot 4.5.1 for iPhone Safari (single-threaded Web)."""
import io, os, platform, struct, subprocess, sys, urllib.request, zipfile, zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = "https://github.com/godotengine/godot/releases/download/4.5.1-stable/"
CACHE = ROOT / ".godot-build-cache"
VERSION = "4.5.1.stable"

def download(url, start=None, end=None):
    head = {"User-Agent": "Aeroroute-Godot-CI"}
    if start is not None:
        head["Range"] = f"bytes={start}-{end}"
    req = urllib.request.Request(url, headers=head)
    with urllib.request.urlopen(req, timeout=120) as r:
        if start is not None and r.status != 206:
            raise RuntimeError(f"Expected HTTP 206; received {r.status}")
        return r.read()

def template_at(destination):
    url = BASE + "Godot_v4.5.1-stable_export_templates.tpz"
    with urllib.request.urlopen(urllib.request.Request(url, method="HEAD"), timeout=100) as response:
        length = int(response.headers["Content-Length"])
    tail_bytes = 160000
    tail = download(url, length-tail_bytes, length-1)
    eocd = tail.rfind(b"PK\x05\x06")
    if eocd < 0:
        raise RuntimeError("Export template ZIP has no directory")
    directory_size, directory_pos = struct.unpack_from("<II", tail, eocd + 12)
    directory = download(url, directory_pos, directory_pos + directory_size - 1)
    offset = 0
    while offset < len(directory):
        if directory[offset:offset + 4] != b"PK\x01\x02":
            raise RuntimeError("Invalid ZIP directory entry")
        method = struct.unpack_from("<H", directory, offset + 10)[0]
        compressed = struct.unpack_from("<I", directory, offset + 20)[0]
        name_len, extra_len, comment_len = struct.unpack_from("<HHH", directory, offset + 28)
        location = struct.unpack_from("<I", directory, offset + 42)[0]
        name = directory[offset+46:offset+46+name_len].decode()
        if name == "templates/web_nothreads_release.zip":
            segment = download(url, location, location + compressed + 8192)
            if segment[:4] != b"PK\x03\x04":
                raise RuntimeError("Invalid ZIP local entry")
            local_name, local_extra = struct.unpack_from("<HH", segment, 26)
            start = 30 + local_name + local_extra
            payload = segment[start:start + compressed]
            result = zlib.decompress(payload, -15) if method == 8 else payload
            with zipfile.ZipFile(io.BytesIO(result)) as z:
                if z.testzip():
                    raise RuntimeError("Corrupted Web export template")
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(result)
            return
        offset += 46 + name_len + extra_len + comment_len
    raise RuntimeError("Single-threaded Godot Web release template not found")

def main():
    arch = platform.machine().lower()
    arch = "x86_64" if arch in ("x86_64", "amd64") else ("arm64" if arch in ("arm64", "aarch64") else arch)
    if sys.platform != "linux" or arch not in ("x86_64", "arm64"):
        raise RuntimeError(f"Unsupported build environment: {sys.platform}/{arch}")
    CACHE.mkdir(exist_ok=True)
    filename = f"Godot_v4.5.1-stable_linux.{arch}"
    executable = CACHE / filename
    if not executable.is_file():
        with zipfile.ZipFile(io.BytesIO(download(BASE + filename + ".zip"))) as archive:
            executable.write_bytes(archive.read(filename))
        executable.chmod(0o755)
    template = Path.home() / ".local/share/godot/export_templates" / VERSION / "web_nothreads_release.zip"
    if not template.is_file():
        template_at(template)
    (ROOT / "build").mkdir(exist_ok=True)
    processes = (
        ["--headless", "--path", str(ROOT), "--editor", "--quit"],
        ["--headless", "--path", str(ROOT), "--quit-after", "90"],
        ["--headless", "--path", str(ROOT), "--export-release", "Web", "build/index.html"],
    )
    for args in processes:
        print("Running Godot", args, flush=True)
        p = subprocess.run([str(executable), *args], text=True, capture_output=True, timeout=150)
        print(p.stdout, flush=True)
        print(p.stderr, file=sys.stderr, flush=True)
        errors = [line for line in (p.stdout + "\n" + p.stderr).splitlines()
                  if ("SCRIPT ERROR" in line or "Parse Error" in line or
                      "Invalid polygon" in line or "Invalid call" in line or
                      ("ERROR:" in line and "fontconfig" not in line))]
        if p.returncode != 0 or errors:
            raise RuntimeError("Godot validation failed: " + " | ".join(errors[:15]))
    for n in ("index.html", "index.js", "index.wasm", "index.pck"):
        file = ROOT / "build" / n
        if not file.is_file() or file.stat().st_size == 0:
            raise RuntimeError(f"Missing Godot Web export: {file}")
    print("Successfully built Aeroroute Godot Web", flush=True)

if __name__ == "__main__":
    main()
