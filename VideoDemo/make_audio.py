"""Add background music (+ optional voiceover) to the demo videos. No ffmpeg: music is synthesised with numpy,
voice comes from Windows TTS, AAC is encoded by Chrome WebCodecs and muxed into the existing MP4 here.

  python make_audio.py              # all three videos
  python make_audio.py vertical     # just one: full | short | vertical
  --voice "Microsoft David Desktop" # pick another installed SAPI voice

Writes <video>_music.mp4 and <video>_voiceover.mp4 next to the originals (the silent files are left alone).
"""
import asyncio, base64, hashlib, html, json, re, shutil, struct, subprocess, sys, time, wave
from pathlib import Path

import numpy as np
import requests
import websockets

HERE = Path(__file__).resolve().parent
AUDIO = HERE / "audio"
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
SR = 48000
PORT, HTTP = 9337, 5184
VOICE = sys.argv[sys.argv.index("--voice") + 1] if "--voice" in sys.argv else "Microsoft Zira Desktop"

VIDEOS = {
    "full": ("PathOGen_demo.mp4", "frames.json"),
    "short": ("PathOGen_demo_60s.mp4", "frames_short.json"),
    "vertical": ("PathOGen_demo_60s_vertical.mp4", "frames_vertical.json"),
}

# Voiceover cues: (anchor, offset s, line). Anchor = text found in a caption ("#card0" / "#card1" = title / end card).
# "Path oh jen" is how the TTS voice says PathOGen correctly.
VO_SHORT = [
    ("#card0", 0.25, "Meet Path oh jen."),
    ("real Grasshopper script", 0.0, "Every level is a real Grasshopper script."),
    ("4 levels", 0.0, "Four levels take you from base shape to facade."),
    ("3 difficulties", 0.0, "Three difficulties, three different methods."),
    ("Meet the monster", 0.0, "Meet the monster, and check the goal."),
    ("glowing node", 0.0, "Fill the glowing node: pick a card, and place it."),
    ("Field notes", 0.0, "Field notes explain why."),
    ("Wrong card", 0.0, "Wrong card? The monster strikes!"),
    ("lifesaver", 0.0, "Stuck? Use a lifesaver."),
    ("lifesaver", 2.6, "Then keep building, node by node."),
    ("Wire checks", 0.0, "Wire checks: plug into the right input."),
    ("Wire checks", 5.2, "Every card is a real Grasshopper component."),
    ("3D preview", 0.0, "The 3D preview grows live."),
    ("solid tower", 0.0, "Loft, cap, and you've got a solid tower."),
    ("stars, XP", 0.0, "Win to earn stars and X P, and rank up."),
    ("fully parametric", 0.0, "Then drag a slider. It's fully parametric."),
    ("#card1", -0.9, "Build the script, survive the monster, master Grasshopper."),
]
VO_FULL = [
    ("#card0", 0.2, "Path oh jen: learn Grasshopper by beating monsters."),
    ("real Grasshopper script", 0.0, "Every level is built from a real Grasshopper script."),
    ("4 levels", 0.0, "Four levels take you from the base shape all the way to the facade."),
    ("different method", 0.0, "And each difficulty is a different method for building it."),
    ("Meet the monster", 0.0, "Meet the monster, and see the goal you're building toward."),
    ("one node at a time", 0.0, "Your job: rebuild the definition, one node at a time."),
    ("glowing node", 0.0, "The glowing node is your next step."),
    ("Pick a card", 0.0, "Pick a card from your hand,"),
    ("place it", 0.0, "and place it."),
    ("Field notes", 0.0, "Field notes explain why it works."),
    ("wrong</span> one", 0.0, "But pick the wrong one,"),
    ("strikes", 0.0, "and the monster strikes!"),
    ("what went wrong", 0.0, "You still learn what went wrong."),
    ("lifesaver", 0.0, "Stuck? Use a lifesaver."),
    ("Hints", 0.0, "Hints, potions, fifty fifty, shields, and second chances."),
    ("Wire checks", 0.0, "Wire checks ask you to plug into the right input."),
    ("Wire checks", 5.5, "Every card you place is a real Grasshopper component."),
    ("3D preview", 0.0, "The 3D preview grows with every move."),
    ("solid tower", 0.0, "Loft, cap holes, and you've got a solid tower."),
    ("stars, XP", 0.0, "Win to earn stars and X P, and rank up."),
    ("fully parametric", 0.0, "Then drag the sliders. It's fully parametric."),
    ("fully parametric", 5.0, "Each slider is a parameter from the original script."),
    ("switch views", 0.0, "Orbit, zoom, and switch views."),
    ("#card1", -0.6, "Build the script, survive the monster, master Grasshopper."),
]


# ---------------------------------------------------------------- voice
def tts(lines):
    """lines: list of text -> list of float32 arrays (48 kHz mono), cached in audio/tts/."""
    out_dir = AUDIO / "tts"
    out_dir.mkdir(parents=True, exist_ok=True)
    jobs, paths = [], []
    for t in lines:
        p = out_dir / (hashlib.md5(f"{VOICE}|{t}".encode()).hexdigest()[:12] + ".wav")
        paths.append(p)
        if not p.exists():
            jobs.append({"text": t, "out": str(p)})
    if jobs:
        jf = out_dir / "jobs.json"
        jf.write_text(json.dumps(jobs), encoding="utf-8")
        ps = f"""Add-Type -AssemblyName System.Speech
$jobs = Get-Content -Raw -Encoding UTF8 '{jf}' | ConvertFrom-Json
$fmt = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo({SR},[System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen,[System.Speech.AudioFormat.AudioChannel]::Mono)
foreach ($j in $jobs) {{ $s = New-Object System.Speech.Synthesis.SpeechSynthesizer; $s.SelectVoice('{VOICE}'); $s.Rate = 1
  $s.SetOutputToWaveFile($j.out, $fmt); $s.Speak($j.text); $s.Dispose() }}"""
        subprocess.run(["powershell", "-NoProfile", "-Command", ps], check=True)
    res = []
    for p in paths:
        with wave.open(str(p)) as w:
            a = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float32) / 32768
        nz = np.nonzero(np.abs(a) > 0.01)[0]                       # trim leading/trailing silence
        a = a[max(0, nz[0] - 480): nz[-1] + 2400] if len(nz) else a
        res.append(a / (np.abs(a).max() + 1e-9) * 0.89)
    return res


def plain(h):
    return html.unescape(re.sub(r"<[^>]+>", "", h))


def schedule(events, cues):
    """Place each cue at its anchor time (+offset), pushed later if the previous line is still speaking."""
    caps = [e for e in events if e["type"] == "cap"]
    cards = [e for e in events if e["type"] == "card"]
    placed = []
    for anchor, off, line in cues:
        if anchor.startswith("#card"):
            k = int(anchor[5:])
            t = cards[k]["t"] if k < len(cards) else None
        else:
            hit = [e for e in caps if anchor.lower() in e["html"].lower() or anchor.lower() in plain(e["html"]).lower()]
            t = hit[0]["t"] if hit else None
        if t is None:
            print("  ! no caption for cue", anchor)
            continue
        placed.append([t + off, line])
    placed.sort(key=lambda x: x[0])
    clips = tts([p[1] for p in placed])
    out, end = [], 0.0
    for (t, line), clip in zip(placed, clips):
        start = max(t, end + 0.12)
        if start - t > 0.4:
            print(f"  ~ '{line}' starts {start - t:.1f}s after its caption")
        out.append((start, clip, line))
        end = start + len(clip) / SR
    return out


# ---------------------------------------------------------------- music
def music(dur, seed=7):
    """Light, original loop: Cmaj7-Am7-Fmaj7-G6 at 112 bpm. Marimba arp, soft pad, sine bass, gentle drums."""
    rng = np.random.default_rng(seed)
    n = int(dur * SR) + SR
    L, R = np.zeros(n, np.float32), np.zeros(n, np.float32)
    bpm = 112.0
    beat = 60 / bpm
    bar = 4 * beat
    mtof = lambda m: 440.0 * 2 ** ((m - 69) / 12)
    chords = [[48, 55, 59, 64, 67], [45, 52, 55, 60, 64], [41, 48, 52, 57, 60], [43, 50, 55, 59, 64]]

    def add(sig, t0, gl, gr):
        i = int(t0 * SR)
        if i >= n:
            return
        m = min(len(sig), n - i)
        L[i:i + m] += sig[:m] * gl
        R[i:i + m] += sig[:m] * gr

    def tone(f, d, partials=((1, 1.0),), atk=0.005, dec=None):
        t = np.arange(int(d * SR)) / SR
        s = sum(a * np.sin(2 * np.pi * f * k * t) for k, a in partials)
        env = np.minimum(1, t / atk) * (np.exp(-t / dec) if dec else 1)
        return (s * env).astype(np.float32)

    nbars = int(dur / bar) + 2
    drums_from, drums_to = bar * 1, dur - 3.5
    for b in range(nbars):
        t0 = b * bar
        ch = chords[b % 4]
        # pad: chord tones, slow swell, slightly detuned per side
        pd = bar + 0.6
        t = np.arange(int(pd * SR)) / SR
        env = np.minimum(1, t / 0.9) * np.minimum(1, np.maximum(0, (pd - t) / 0.7))
        for m in ch[1:]:
            f = mtof(m + 12)
            for side, det in ((0, 0.997), (1, 1.003)):
                s = (np.sin(2 * np.pi * f * det * t) + 0.25 * np.sin(4 * np.pi * f * det * t)) * env * 0.022
                add(s.astype(np.float32), t0, 1 if side == 0 else 0, 0 if side == 0 else 1)
        # bass: root on 1, fifth-ish push on the "and" of 3
        root = ch[0] - 12
        for bt, m, d in ((0, root, 1.4), (2.5, root, 0.5), (3, root + 7, 0.9)):
            add(tone(mtof(m), d * beat, ((1, 1.0), (2, 0.18)), 0.01, 0.35) * 0.16, t0 + bt * beat, 1, 1)
        # marimba arpeggio in 8ths, alternating pan
        pat = [0, 2, 3, 4, 3, 2, 1, 2]
        for k in range(8):
            if b == nbars - 1 and k > 0:
                break
            m = ch[1 + pat[k] % 4] + 12 + (12 if pat[k] == 4 else 0)
            s = tone(mtof(m), 0.9, ((1, 1.0), (4, 0.22), (9.8, 0.05)), 0.003, 0.22) * 0.085
            pan = 0.35 if k % 2 else -0.35
            add(s, t0 + k * beat / 2 + rng.normal(0, 0.003), 1 - max(0, pan), 1 + min(0, pan))
        # drums
        if drums_from <= t0 < drums_to:
            for bt in (0, 2):                                        # soft kick
                kt = np.arange(int(0.25 * SR)) / SR
                f = 50 + 70 * np.exp(-kt / 0.03)
                k = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-kt / 0.09) * 0.32
                add(k.astype(np.float32), t0 + bt * beat, 1, 1)
            for bt in (1, 3):                                        # brushed snare
                st = np.arange(int(0.22 * SR)) / SR
                nz = rng.normal(0, 1, len(st))
                nz = nz - np.convolve(nz, np.ones(6) / 6, "same")
                s = (nz * 0.6 + np.sin(2 * np.pi * 190 * st)) * np.exp(-st / 0.06) * 0.07
                add(s.astype(np.float32), t0 + bt * beat, 0.9, 1)
            for k in range(8):                                       # hats
                ht = np.arange(int(0.06 * SR)) / SR
                nz = rng.normal(0, 1, len(ht))
                nz = np.diff(np.diff(nz, prepend=0), prepend=0)
                g = 0.022 if k % 2 else 0.012
                add((nz * np.exp(-ht / 0.012) * g).astype(np.float32), t0 + k * beat / 2, 0.8, 1.1)

    # small room reverb (FFT convolution with decaying noise)
    ir_t = np.arange(int(1.4 * SR)) / SR
    ir = rng.normal(0, 1, (2, len(ir_t))) * np.exp(-ir_t / 0.35) * 0.012
    ir[:, 0] = 0
    nfft = 1 << int(np.ceil(np.log2(n + len(ir_t))))
    wet = [np.fft.irfft(np.fft.rfft(x, nfft) * np.fft.rfft(h, nfft), nfft)[:n] for x, h in ((L, ir[0]), (R, ir[1]))]
    out = np.stack([L + wet[0], R + wet[1]])[:, :int(dur * SR)]
    t = np.arange(out.shape[1]) / SR
    fade = np.minimum(1, t / 0.6) * np.minimum(1, np.maximum(0, (dur - t) / 2.5))
    out *= fade
    return (out / (np.abs(out).max() + 1e-9)).astype(np.float32)


def mix(dur, vo):
    m = music(dur)
    n = m.shape[1]
    voice = np.zeros(n, np.float32)
    for start, clip, _ in vo:
        i = int(start * SR)
        k = min(len(clip), n - i)
        if k > 0:
            voice[i:i + k] += clip[:k]
    # duck the music under the voice (fast attack, slow release)
    active = (np.abs(voice) > 0.02).astype(np.float32)
    win = int(0.25 * SR)
    cs_ = np.concatenate([[0], np.cumsum(active)])                # moving average via cumulative sum
    lo, hi = np.clip(np.arange(n) - win // 2, 0, n), np.clip(np.arange(n) + win // 2, 0, n)
    active = (cs_[hi] - cs_[lo]) / win > 0.02
    env = active.astype(np.float32)
    a_up, a_dn = 1 - np.exp(-1 / (0.06 * SR)), 1 - np.exp(-1 / (0.45 * SR))
    sm = np.empty_like(env)
    y = 0.0
    step = 48                                                     # envelope at 1 kHz, then upsample
    coarse = env[::step]
    cs = np.empty_like(coarse)
    au, ad = 1 - (1 - a_up) ** step, 1 - (1 - a_dn) ** step
    for i, x in enumerate(coarse):
        y += (x - y) * (au if x > y else ad)
        cs[i] = y
    sm = np.repeat(cs, step)[:n]
    music_gain = 0.30 * (1 - 0.6 * sm) if vo else 0.42           # ~-10 dB music, a further -8 dB under speech
    out = m * music_gain + voice[None, :] * 0.92
    peak = np.abs(out).max()
    if peak > 0.97:
        out *= 0.97 / peak
    return out.astype(np.float32)


# ---------------------------------------------------------------- AAC via Chrome
async def encode_aac(pcm_files):
    srv = subprocess.Popen([sys.executable, "-m", "http.server", str(HTTP), "--bind", "127.0.0.1", "--directory", str(HERE)],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    prof = HERE / "chrome-audio"
    shutil.rmtree(prof, ignore_errors=True)
    ch = subprocess.Popen([CHROME, "--headless=new", f"--remote-debugging-port={PORT}", f"--user-data-dir={prof}",
                           "--no-first-run", "--disable-background-timer-throttling", "about:blank"])
    res = {}
    try:
        for _ in range(60):
            try:
                page = next(t for t in requests.get(f"http://127.0.0.1:{PORT}/json", timeout=1).json() if t["type"] == "page")
                break
            except Exception:
                time.sleep(0.25)
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
                r = (await call("Runtime.evaluate", expression=expr, awaitPromise=True, returnByValue=True)).get("result", {})
                if "exceptionDetails" in r:
                    raise RuntimeError(r["exceptionDetails"])
                return r.get("result", {}).get("value")

            await call("Page.navigate", url=f"http://127.0.0.1:{HTTP}/audio_encode.html")
            await asyncio.sleep(1.5)
            for key, f in pcm_files.items():
                info = await js(f"encodeAudio('{f.relative_to(HERE).as_posix()}')")
                data, pos, step = bytearray(), 0, 4 * 1024 * 1024
                while pos < info["size"]:
                    data += base64.b64decode(await js(f"chunk({pos},{step})"))
                    pos += step
                info["data"] = bytes(data)
                res[key] = info
    finally:
        ch.terminate()
        srv.terminate()
        time.sleep(0.5)
        shutil.rmtree(prof, ignore_errors=True)
    return res


# ---------------------------------------------------------------- MP4 mux
def box(t, payload):
    return struct.pack(">I4s", 8 + len(payload), t.encode()) + payload


def full(t, ver, flags, payload):
    return box(t, struct.pack(">I", (ver << 24) | flags) + payload)


def boxes(b, o=0, end=None):
    end = len(b) if end is None else end
    while o < end:
        size, typ = struct.unpack(">I4s", b[o:o + 8])
        hdr = 8
        if size == 1:
            size, hdr = struct.unpack(">Q", b[o + 8:o + 16])[0], 16
        yield typ.decode(), o, hdr, size
        o += size


def desc(tag, payload):
    n = len(payload)
    return bytes([tag, 0x80 | (n >> 21) & 0x7F, 0x80 | (n >> 14) & 0x7F, 0x80 | (n >> 7) & 0x7F, n & 0x7F]) + payload


def audio_trak(info, offset, movie_ts):
    sizes, n = info["sizes"], len(info["sizes"])
    total = n * 1024
    asc = bytes(info["desc"]) or bytes([0x11, 0x90])              # AAC-LC 48 kHz stereo
    dcd = desc(0x04, bytes([0x40, 0x15]) + (6144).to_bytes(3, "big") + struct.pack(">II", 192000, 160000) + desc(0x05, asc))
    esds = full("esds", 0, 0, desc(0x03, struct.pack(">HB", 2, 0) + dcd + desc(0x06, b"\x02")))
    mp4a = box("mp4a", bytes(6) + struct.pack(">H", 1) + bytes(8) + struct.pack(">HHHHI", 2, 16, 0, 0, SR << 16) + esds)
    stsd = full("stsd", 0, 0, struct.pack(">I", 1) + mp4a)
    stts = full("stts", 0, 0, struct.pack(">III", 1, n, 1024))
    per = 47                                                      # ~1 s of audio per chunk
    chunks = [(k, min(per, n - k)) for k in range(0, n, per)]
    stsc_entries = [(1, chunks[0][1])] + ([(len(chunks), chunks[-1][1])] if len(chunks) > 1 and chunks[-1][1] != per else [])
    stsc = full("stsc", 0, 0, struct.pack(">I", len(stsc_entries)) + b"".join(struct.pack(">III", c, s, 1) for c, s in stsc_entries))
    stsz = full("stsz", 0, 0, struct.pack(">II", 0, n) + b"".join(struct.pack(">I", s) for s in sizes))
    offs, o = [], offset
    for k, cnt in chunks:
        offs.append(o)
        o += sum(sizes[k:k + cnt])
    co64 = full("co64", 0, 0, struct.pack(">I", len(offs)) + b"".join(struct.pack(">Q", x) for x in offs))
    stbl = box("stbl", stsd + stts + stsc + stsz + co64)
    hdlr = full("hdlr", 0, 0, bytes(4) + b"soun" + bytes(12) + b"SoundHandler" + bytes(1))
    smhd = full("smhd", 0, 0, bytes(4))
    dinf = box("dinf", full("dref", 0, 0, struct.pack(">I", 1) + full("url ", 0, 1, b"")))
    mdhd = full("mdhd", 0, 0, struct.pack(">IIII", 0, 0, SR, total) + struct.pack(">HH", 0x55C4, 0))
    mdia = box("mdia", mdhd + hdlr + box("minf", smhd + dinf + stbl))
    dur_movie = int(total * movie_ts / SR)
    matrix = struct.pack(">9I", 0x10000, 0, 0, 0, 0x10000, 0, 0, 0, 0x40000000)
    tkhd = full("tkhd", 0, 3, struct.pack(">IIIII", 0, 0, 2, 0, dur_movie) + bytes(8) + struct.pack(">hhhH", 0, 1, 0x0100, 0) + matrix + struct.pack(">II", 0, 0))
    return box("trak", tkhd + mdia)


def mux(src, dst, aac):
    b = src.read_bytes()
    top = {t: (o, h, s) for t, o, h, s in boxes(b)}
    ftyp = b[top["ftyp"][0]: top["ftyp"][0] + top["ftyp"][2]]
    mo, mh, ms = top["moov"]
    do, dh, ds = top["mdat"]
    vdata = b[do + dh: do + ds]
    old_data_start = do + dh
    kids = {t: b[o:o + s] for t, o, h, s in boxes(b, mo + mh, mo + ms)}
    mvhd = bytearray(kids["mvhd"])
    movie_ts = struct.unpack(">I", mvhd[20:24])[0]
    mvhd[-4:] = struct.pack(">I", 3)                              # next_track_ID
    vtrak = bytearray(kids["trak"])

    def patch_co64(delta):                                          # shift video chunk offsets
        t = bytearray(vtrak)
        k = t.find(b"co64")
        cnt = struct.unpack(">I", t[k + 8:k + 12])[0]
        for j in range(cnt):
            p = k + 12 + 8 * j
            t[p:p + 8] = struct.pack(">Q", struct.unpack(">Q", t[p:p + 8])[0] + delta)
        return bytes(t)

    adata = aac["data"]
    mdat_hdr = struct.pack(">I4sQ", 1, b"mdat", 16 + len(vdata) + len(adata))

    def moov(data_start):
        return box("moov", bytes(mvhd) + patch_co64(data_start - old_data_start) + audio_trak(aac, data_start + len(vdata), movie_ts))

    m = moov(0)
    m = moov(len(ftyp) + len(m) + len(mdat_hdr))
    with open(dst, "wb") as f:
        f.write(ftyp); f.write(m); f.write(mdat_hdr); f.write(vdata); f.write(adata)


# ---------------------------------------------------------------- main
def main():
    keys = [k for k in VIDEOS if k in sys.argv] or list(VIDEOS)
    AUDIO.mkdir(exist_ok=True)
    pcm, plan = {}, {}
    for k in keys:
        video, meta = VIDEOS[k]
        m = json.loads((HERE / meta).read_text(encoding="utf-8"))
        dur = m["frames"][-1][1] + 0.6
        if not m.get("events"):
            print(f"{k}: {meta} has no caption events, re-record it first"); continue
        print(f"{k}: {dur:.1f}s")
        vo = schedule(m["events"], VO_FULL if k == "full" else VO_SHORT)
        late = vo[-1][0] + len(vo[-1][1]) / SR if vo else 0
        if late > dur:
            print(f"  ! voiceover runs {late - dur:.1f}s past the end")
        for variant, lines in (("music", []), ("voiceover", vo)):
            a = mix(dur, lines)
            f = AUDIO / f"{k}_{variant}.f32"
            np.ascontiguousarray(a.T).astype("<f4").tofile(f)
            pcm[f"{k}_{variant}"] = f
            plan[f"{k}_{variant}"] = (HERE / video, HERE / (Path(video).stem + f"_{variant}.mp4"))
        (AUDIO / f"{k}_voiceover.txt").write_text("\n".join(f"{s:6.2f}s  {line}" for s, _, line in vo), encoding="utf-8")
    enc = asyncio.run(encode_aac(pcm))
    for key, info in enc.items():
        src, dst = plan[key]
        mux(src, dst, info)
        print("wrote", dst.name, dst.stat().st_size // 1024, "KB")
    for f in pcm.values():
        f.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
