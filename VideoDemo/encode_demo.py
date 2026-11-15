"""Encode demo/frames/*.jpg (from record_demo.py) into PathOGen_demo.mp4: H.264 via Chrome WebCodecs, MP4 written here (no ffmpeg needed)."""
import asyncio, base64, json, shutil, struct, subprocess, sys, time
from pathlib import Path

import requests
import websockets

HERE = Path(__file__).resolve().parent
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
PORT, HTTP = 9334, 5182
SHORT = "--short" in sys.argv
VERTICAL = "--vertical" in sys.argv
OUT = HERE / ("PathOGen_demo_60s_vertical" if VERTICAL else "PathOGen_demo_60s" if SHORT else "PathOGen_demo")
META = "frames_vertical.json" if VERTICAL else "frames_short.json" if SHORT else "frames.json"
PAGE = "encode_vertical.html" if VERTICAL else "encode.html"


async def main():
    srv = subprocess.Popen([sys.executable, "-m", "http.server", str(HTTP), "--bind", "127.0.0.1", "--directory", str(HERE)],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    prof = HERE / "chrome-encode"
    shutil.rmtree(prof, ignore_errors=True)
    chrome = subprocess.Popen([CHROME, "--headless=new", f"--remote-debugging-port={PORT}", f"--user-data-dir={prof}",
                               "--window-size=1920,1080", "--no-first-run", "--disable-background-timer-throttling",
                               "--disable-renderer-backgrounding", "about:blank"])
    try:
        for _ in range(50):
            try:
                page = next(t for t in requests.get(f"http://127.0.0.1:{PORT}/json", timeout=1).json() if t["type"] == "page")
                break
            except Exception:
                time.sleep(0.2)
        async with websockets.connect(page["webSocketDebuggerUrl"], max_size=2 ** 29) as ws:
            i = 0

            async def call(method, **params):
                nonlocal i
                i += 1
                my = i
                await ws.send(json.dumps({"id": my, "method": method, "params": params}))
                while True:
                    m = json.loads(await ws.recv())
                    if m.get("id") == my:
                        return m

            async def js(expr):
                m = await call("Runtime.evaluate", expression=expr, awaitPromise=True, returnByValue=True)
                r = m.get("result", {})
                if "exceptionDetails" in r:
                    raise RuntimeError(r["exceptionDetails"])
                return r.get("result", {}).get("value")

            await call("Page.navigate", url=f"http://127.0.0.1:{HTTP}/{PAGE}")
            await asyncio.sleep(1.5)
            info = await js(f"encode(30, {12000000 if VERTICAL else 14000000}, '{META}')")
            print(f"encoded {info['frames']} frames, {info['size'] // 1024} KB, {sum(info['keys'])} keyframes")
            data, pos, n = bytearray(), 0, 4 * 1024 * 1024
            while pos < info["size"]:
                data += base64.b64decode(await js(f"chunk({pos},{n})"))
                pos += n
            out = OUT.with_suffix(".mp4")
            write_mp4(out, bytes(data), info, *((1080, 1920) if VERTICAL else (1920, 1080)))
            print("wrote", out, out.stat().st_size // 1024, "KB")
    finally:
        chrome.terminate()
        srv.terminate()


def box(t, payload):
    return struct.pack(">I4s", 8 + len(payload), t.encode()) + payload


def full(t, ver, flags, payload):
    return box(t, struct.pack(">I", (ver << 24) | flags) + payload)


def write_mp4(path, data, info, w=1920, h=1080):
    fps, sizes, keys = info["fps"], info["sizes"], info["keys"]
    n, ts, d = len(sizes), fps * 1000, 1000           # timescale 30000, 1000 ticks per frame
    total = n * d
    avcc = box("avcC", bytes(info["desc"]))
    avc1 = box("avc1", bytes(1) * 6 + struct.pack(">H", 1) + bytes(1) * 16 + struct.pack(">HHIIIH", w, h, 0x480000, 0x480000, 0, 1)
               + bytes(1) * 32 + struct.pack(">Hh", 0x18, -1) + avcc)
    stsd = full("stsd", 0, 0, struct.pack(">I", 1) + avc1)
    stts = full("stts", 0, 0, struct.pack(">III", 1, n, d))
    sync = [i + 1 for i, k in enumerate(keys) if k]
    stss = full("stss", 0, 0, struct.pack(">I", len(sync)) + b"".join(struct.pack(">I", i) for i in sync))
    stsc = full("stsc", 0, 0, struct.pack(">IIII", 1, 1, 1, 1))
    stsz = full("stsz", 0, 0, struct.pack(">II", 0, n) + b"".join(struct.pack(">I", s) for s in sizes))
    matrix = struct.pack(">9I", 0x10000, 0, 0, 0, 0x10000, 0, 0, 0, 0x40000000)
    hdlr = full("hdlr", 0, 0, bytes(1) * 4 + b"vide" + bytes(1) * 12 + b"VideoHandler" + bytes(1))
    vmhd = full("vmhd", 0, 1, bytes(1) * 8)
    dinf = box("dinf", full("dref", 0, 0, struct.pack(">I", 1) + full("url ", 0, 1, b"")))

    def moov(data_start):
        offs, o = [], data_start
        for s in sizes:
            offs.append(o); o += s
        co64 = full("co64", 0, 0, struct.pack(">I", n) + b"".join(struct.pack(">Q", x) for x in offs))
        stbl = box("stbl", stsd + stts + stss + stsc + stsz + co64)
        mdia = box("mdia", full("mdhd", 0, 0, struct.pack(">IIII", 0, 0, ts, total) + struct.pack(">HH", 0x55C4, 0)) + hdlr + box("minf", vmhd + dinf + stbl))
        tkhd = full("tkhd", 0, 3, struct.pack(">IIIII", 0, 0, 1, 0, total) + bytes(1) * 8 + struct.pack(">hhhH", 0, 0, 0, 0) + matrix + struct.pack(">II", w << 16, h << 16))
        mvhd = full("mvhd", 0, 0, struct.pack(">IIII", 0, 0, ts, total) + struct.pack(">IH", 0x10000, 0x100) + bytes(1) * 10 + matrix + bytes(1) * 24 + struct.pack(">I", 2))
        return box("moov", mvhd + box("trak", tkhd + mdia))

    ftyp = box("ftyp", b"isom" + struct.pack(">I", 0x200) + b"isomiso2avc1mp41")
    mdat_hdr = struct.pack(">I4sQ", 1, b"mdat", 16 + len(data))
    m = moov(0)
    m = moov(len(ftyp) + len(m) + len(mdat_hdr))
    with open(path, "wb") as f:
        f.write(ftyp); f.write(m); f.write(mdat_hdr); f.write(data)


asyncio.run(main())
