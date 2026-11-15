"""Record a Shorts-style walkthrough of PathOGen (backup demo video).

Drives a headless Chrome over the DevTools protocol: real mouse clicks, an on-screen cursor, big pop-in captions,
zooms, a progress bar, title and end cards. Frames are captured as JPEGs with timestamps into demo/frames/.
Then run encode_demo.py to turn them into an MP4.

    python -m http.server 5180 --directory <PathOGen>/web     (game server, already running is fine)
    python record_demo.py
"""
import asyncio, base64, json, shutil, subprocess, sys, time
from pathlib import Path

import requests
import websockets

HERE = Path(__file__).resolve().parent
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
GAME = "http://localhost:5180/?all"
PORT = 9333
W, H = 1920, 1080
FPS = 24
FRAMES = HERE / "frames"
PROFILE = HERE / "chrome-profile"

OVERLAY_JS = r"""
(() => {
  if (window.__demo) return;
  const css = document.createElement('style');
  css.textContent = `
    #demo-layer{position:fixed;inset:0;pointer-events:none;z-index:2147483000;font-family:'Arial Black','Segoe UI Black',Impact,sans-serif}
    #demo-cursor{position:fixed;left:0;top:0;width:34px;height:34px;z-index:2147483600;pointer-events:none;filter:drop-shadow(0 3px 4px rgba(0,0,0,.55));transform:translate(-4px,-2px)}
    .demo-ripple{position:fixed;width:20px;height:20px;margin:-10px 0 0 -10px;border-radius:50%;border:4px solid #ffd84a;z-index:2147483500;pointer-events:none;animation:demoRip .55s ease-out forwards}
    @keyframes demoRip{to{transform:scale(4.2);opacity:0}}
    #demo-cap{position:fixed;left:50%;transform:translateX(-50%);max-width:1500px;text-align:center;z-index:2147483400;
      font-size:62px;line-height:1.08;color:#fff;letter-spacing:.5px;text-transform:uppercase;
      -webkit-text-stroke:3px #000;paint-order:stroke fill;text-shadow:0 6px 0 rgba(0,0,0,.55),0 0 24px rgba(0,0,0,.45);background:rgba(8,14,12,.62);padding:16px 38px 20px;border-radius:26px;box-shadow:0 10px 40px rgba(0,0,0,.45)}
    #demo-cap .hl{color:#ffd84a}
    #demo-cap.pop{animation:demoPop .42s cubic-bezier(.2,1.6,.4,1) both}
    @keyframes demoPop{0%{transform:translateX(-50%) scale(.55);opacity:0}100%{transform:translateX(-50%) scale(1);opacity:1}}
    #demo-cap.out{transition:opacity .2s;opacity:0}
    #demo-bar{position:fixed;left:0;top:0;height:8px;width:0;background:linear-gradient(90deg,#ffd84a,#ff6a3d);z-index:2147483450;box-shadow:0 0 12px #ffb03a}
    #demo-mark{position:fixed;right:26px;bottom:20px;z-index:2147483450;color:#fff;font-size:22px;opacity:.85;-webkit-text-stroke:1px #000;paint-order:stroke fill}
    #demo-card{position:fixed;inset:0;z-index:2147483300;pointer-events:none;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:26px;
      background:radial-gradient(circle at 50% 40%,#2b4a3f 0%,#0f1a17 70%);color:#fff;text-align:center;transition:opacity .5s}
    #demo-card h1{font-size:150px;margin:0;color:#ffd84a;-webkit-text-stroke:5px #000;paint-order:stroke fill;text-shadow:0 10px 0 rgba(0,0,0,.6);letter-spacing:2px}
    #demo-card h2{font-size:58px;margin:0;text-transform:uppercase;-webkit-text-stroke:2px #000;paint-order:stroke fill;max-width:1400px;line-height:1.1}
    #demo-card p{font-size:32px;margin:0;opacity:.85;font-family:'Segoe UI',Arial,sans-serif;font-weight:600}
    #demo-card.hide{opacity:0}
    #viewport.demo-zoom{transition:transform .7s cubic-bezier(.3,.8,.3,1)}
  `;
  document.head.appendChild(css);
  const layer = document.createElement('div'); layer.id = 'demo-layer';
  layer.innerHTML = `<div id="demo-bar"></div><div id="demo-mark">PathOGen</div>`;
  document.body.appendChild(layer);
  const cur = document.createElement('div'); cur.id = 'demo-cursor';
  cur.innerHTML = '<svg viewBox="0 0 24 24" width="34" height="34"><path d="M3 2l7.5 19 2.6-7.4L20.5 11z" fill="#fff" stroke="#111" stroke-width="1.6" stroke-linejoin="round"/></svg>';
  document.body.appendChild(cur);
  let cx = innerWidth * 0.55, cy = innerHeight * 0.6; cur.style.left = cx + 'px'; cur.style.top = cy + 'px';
  const D = window.__demo = {};
  D.pos = () => [cx, cy];
  D.move = (x, y, ms) => new Promise(res => {
    const x0 = cx, y0 = cy, t0 = performance.now();
    const ease = t => t < .5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
    const step = now => { const t = Math.min(1, (now - t0) / ms), e = ease(t);
      cx = x0 + (x - x0) * e; cy = y0 + (y - y0) * e; cur.style.left = cx + 'px'; cur.style.top = cy + 'px';
      if (t < 1) requestAnimationFrame(step); else res(true); };
    requestAnimationFrame(step); });
  D.ripple = (x, y) => { const r = document.createElement('div'); r.className = 'demo-ripple'; r.style.left = x + 'px'; r.style.top = y + 'px'; document.body.appendChild(r); setTimeout(() => r.remove(), 700); };
  D.cap = (html, pos) => { let c = document.getElementById('demo-cap'); if (c) c.remove();
    if (!html) return; c = document.createElement('div'); c.id = 'demo-cap'; c.innerHTML = html;
    c.style.top = pos === 'top' ? '5%' : pos === 'mid' ? '40%' : 'auto'; c.style.bottom = pos === 'bottom' ? '6%' : 'auto';
    document.getElementById('demo-layer').appendChild(c); void c.offsetWidth; c.classList.add('pop'); };
  D.uncap = () => { const c = document.getElementById('demo-cap'); if (c) { c.classList.add('out'); setTimeout(() => c.remove(), 220); } };
  D.bar = f => { document.getElementById('demo-bar').style.width = (f * 100) + '%'; };
  D.card = (h1, h2, p) => { let c = document.getElementById('demo-card'); if (!c) { c = document.createElement('div'); c.id = 'demo-card'; document.body.appendChild(c); }
    c.innerHTML = `${h1 ? `<h1>${h1}</h1>` : ''}${h2 ? `<h2>${h2}</h2>` : ''}${p ? `<p>${p}</p>` : ''}`; c.classList.remove('hide'); };
  D.uncard = () => { const c = document.getElementById('demo-card'); if (c) { c.classList.add('hide'); setTimeout(() => c.remove(), 600); } };
  D.zoom = (sel, s, pad) => { const vp = document.getElementById('viewport'); vp.classList.add('demo-zoom');
    if (!sel) { vp.style.transform = ''; return; }
    const el = typeof sel === 'string' ? document.querySelector(sel) : sel; vp.style.transform = '';
    const r = el.getBoundingClientRect(); const mx = r.left + r.width / 2, my = r.top + r.height / 2;
    const tx = innerWidth / 2 - mx * s, ty = innerHeight / 2 - my * s;
    const clampX = Math.min(0, Math.max(innerWidth * (1 - s), tx)), clampY = Math.min(0, Math.max(innerHeight * (1 - s), ty));
    vp.style.transformOrigin = '0 0'; vp.style.transform = `translate(${clampX}px,${clampY}px) scale(${s})`; };
  D.rect = sel => { const el = typeof sel === 'string' ? document.querySelector(sel) : sel; if (!el) return null; const r = el.getBoundingClientRect(); return [r.left, r.top, r.width, r.height]; };
  return true;
})()
"""


class CDP:
    def __init__(self, ws):
        self.ws, self.i, self.wait, self.on_event = ws, 0, {}, None

    async def reader(self):
        async for msg in self.ws:
            m = json.loads(msg)
            if "id" in m and m["id"] in self.wait:
                self.wait.pop(m["id"]).set_result(m)
            elif "method" in m and self.on_event:
                self.on_event(m)

    async def send(self, method, **params):
        self.i += 1
        fut = asyncio.get_event_loop().create_future()
        self.wait[self.i] = fut
        await self.ws.send(json.dumps({"id": self.i, "method": method, "params": params}))
        m = await fut
        if "error" in m:
            raise RuntimeError(f"{method}: {m['error']}")
        return m.get("result", {})

    async def js(self, expr, await_promise=True):
        r = await self.send("Runtime.evaluate", expression=expr, awaitPromise=await_promise, returnByValue=True)
        if "exceptionDetails" in r:
            raise RuntimeError(f"JS error: {r['exceptionDetails'].get('exception', {}).get('description', r['exceptionDetails'])}\n{expr[:200]}")
        return r.get("result", {}).get("value")


class Demo:
    def __init__(self, cdp):
        self.c, self.recording, self.frames, self.t0 = cdp, False, [], None
        self.total, self.events, self.wall0 = 1.0, [], None

    def ev(self, kind, **kw):          # vertical mode: overlays are drawn later by the compositor
        self.events.append({"t": round(time.time() - self.wall0, 4), "type": kind, **kw})

    def on_event(self, m):
        if m["method"] != "Page.screencastFrame":
            return
        p = m["params"]
        asyncio.ensure_future(self.c.send("Page.screencastFrameAck", sessionId=p["sessionId"]))
        if not self.recording:
            return
        name = f"{len(self.frames) + 1:05d}.jpg"
        (FRAMES / name).write_bytes(base64.b64decode(p["data"]))
        self.frames.append([name, round(p["metadata"]["timestamp"] - self.wall0, 4)])

    async def start_capture(self):
        self.c.on_event = self.on_event
        await self.c.send("Page.startScreencast", format="jpeg", quality=88, maxWidth=W, maxHeight=H, everyNthFrame=1)

    async def stop_capture(self):
        await self.c.send("Page.stopScreencast")

    async def sleep(self, s):
        await asyncio.sleep(s)
        if self.t0 and not VERTICAL:
            await self.c.js(f"__demo.bar({min(1.0, (time.perf_counter() - self.t0) / self.total):.4f})", False)

    async def cap(self, html, pos="bottom", hold=None):
        self.ev("cap", html=html)          # logged in every mode (voiceover cue times)
        if not VERTICAL:
            await self.c.js(f"__demo.cap({json.dumps(html)},{json.dumps(pos)})", False)
        if hold:
            await self.sleep(hold)

    async def uncap(self):
        self.ev("uncap")
        if not VERTICAL:
            await self.c.js("__demo.uncap()", False)

    async def zoom(self, sel=None, s=1.6):
        if VERTICAL:
            await self.focus(sel)
        else:
            await self.c.js(f"__demo.zoom({json.dumps(sel)},{s})" if sel else "__demo.zoom(null)", False)
        await self.sleep(0.75)

    async def focus(self, sel=None):   # vertical close-up target (no-op in landscape)
        if VERTICAL:
            self.ev("focus", rect=(await self.c.js(f"__demo.rect({json.dumps(sel)})", False)) if sel else None)

    async def card(self, h1, h2, p):
        self.ev("card", h1=h1, h2=h2, p=p)
        if not VERTICAL:
            await self.c.js(f"__demo.card({json.dumps(h1)},{json.dumps(h2)},{json.dumps(p)})", False)

    async def uncard(self):
        self.ev("uncard")
        if not VERTICAL:
            await self.c.js("__demo.uncard()", False)

    async def center(self, sel):
        r = await self.c.js(f"__demo.rect({sel if sel.startswith('document') else json.dumps(sel)})", False)
        if not r:
            raise RuntimeError("no element " + sel)
        return r[0] + r[2] / 2, r[1] + r[3] / 2

    async def move(self, x, y, ms=550):
        if VERTICAL and self.wall0:
            x0, y0 = await self.c.js("__demo.pos()", False)
            self.ev("move", x0=round(x0, 1), y0=round(y0, 1), x1=round(x, 1), y1=round(y, 1), ms=ms)
        await self.c.js(f"__demo.move({x:.1f},{y:.1f},{ms})")
        await self.c.send("Input.dispatchMouseEvent", type="mouseMoved", x=x, y=y)

    async def click(self, sel, ms=550, after=0.35):
        x, y = await self.center(sel)
        await self.move(x, y, ms)
        await asyncio.sleep(0.08)
        await self.c.js(f"__demo.ripple({x:.1f},{y:.1f})", False)
        await self.c.send("Input.dispatchMouseEvent", type="mousePressed", x=x, y=y, button="left", clickCount=1)
        await self.c.send("Input.dispatchMouseEvent", type="mouseReleased", x=x, y=y, button="left", clickCount=1)
        await self.sleep(after)

    async def drag_range(self, sel, frac_to, steps=26, ms=1400):
        r = await self.c.js(f"""(() => {{ const i=document.querySelector({json.dumps(sel)}); const b=i.getBoundingClientRect();
            const f=(i.value-i.min)/(i.max-i.min); return [b.left,b.top,b.width,b.height,f]; }})()""", False)
        x0 = r[0] + 8 + (r[2] - 16) * r[4]
        y = r[1] + r[3] / 2
        await self.move(x0, y, 500)
        await self.c.send("Input.dispatchMouseEvent", type="mousePressed", x=x0, y=y, button="left", clickCount=1)
        x1 = r[0] + 8 + (r[2] - 16) * frac_to
        for k in range(1, steps + 1):
            x = x0 + (x1 - x0) * k / steps
            if VERTICAL:
                self.ev("move", x0=round(x, 1), y0=round(y, 1), x1=round(x, 1), y1=round(y, 1), ms=10)
            await self.c.js(f"__demo.move({x:.1f},{y:.1f},10)")
            await self.c.send("Input.dispatchMouseEvent", type="mouseMoved", x=x, y=y, button="left", buttons=1)
            await asyncio.sleep(ms / 1000 / steps)
        await self.c.send("Input.dispatchMouseEvent", type="mouseReleased", x=x1, y=y, button="left", clickCount=1)

    # --- game helpers ---
    async def decision(self):
        return await self.c.js("""(() => { const s=PathOGen.state; const d=s.decisions[s.di]; if(!d) return null;
            return d.kind==='comp' ? {kind:'comp', id:d.step.comp, hand:s.hand} : {kind:'quiz', id:'port:'+d.quiz.answerIdx, hand:s.hand}; })()""", False)

    async def pick(self, card_id, place_via="button", ms=500):
        await self.click(f'#hand .card[data-id="{card_id}"]', ms=ms, after=0.45)
        if place_via == "button":
            await self.click("#featured .place", ms=380, after=0.9)
        else:
            await self.click(f'#hand .card[data-id="{card_id}"]', ms=200, after=0.9)

    async def correct(self, place_via="button", ms=500):
        d = await self.decision()
        await self.pick(d["id"], place_via, ms)
        return d


SHORT = "--short" in sys.argv          # 60-second cut: frames_short/ + frames_short.json
VERTICAL = "--vertical" in sys.argv    # 60-second cut for phones: frames_vertical/ + events, composited by encode_demo.py --vertical
if VERTICAL:
    SHORT = True
    FRAMES = HERE / "frames_vertical"
elif SHORT:
    FRAMES = HERE / "frames_short"


async def main():
    if FRAMES.exists():
        shutil.rmtree(FRAMES)
    FRAMES.mkdir(parents=True)
    if PROFILE.exists():
        shutil.rmtree(PROFILE, ignore_errors=True)
    proc = subprocess.Popen([CHROME, "--headless=new", f"--remote-debugging-port={PORT}", f"--user-data-dir={PROFILE}",
                             f"--window-size={W},{H}", "--hide-scrollbars", "--mute-audio", "--no-first-run",
                             "--no-default-browser-check", "--force-device-scale-factor=1", "about:blank"])
    try:
        for _ in range(50):
            try:
                tabs = requests.get(f"http://127.0.0.1:{PORT}/json", timeout=1).json()
                page = next(t for t in tabs if t["type"] == "page")
                break
            except Exception:
                time.sleep(0.2)
        async with websockets.connect(page["webSocketDebuggerUrl"], max_size=2 ** 28) as ws:
            c = CDP(ws)
            reader = asyncio.create_task(c.reader())
            await c.send("Page.enable")
            await c.send("Runtime.enable")
            await c.send("Emulation.setDeviceMetricsOverride", width=W, height=H, deviceScaleFactor=1, mobile=False)
            await c.send("Page.navigate", url=GAME)
            for _ in range(100):
                await asyncio.sleep(0.2)
                try:
                    if await c.js("!!(window.LEVELS && LEVELS.length && window.PathOGen)", False):
                        break
                except Exception:
                    pass
            await asyncio.sleep(1.5)
            await c.js(OVERLAY_JS, False)
            if VERTICAL:
                await c.js("document.getElementById('demo-bar').style.display='none';document.getElementById('demo-mark').style.display='none'", False)
            else:
                await c.js("__demo.card('PathOGen','Learn Grasshopper by beating monsters','A browser game for architecture students')", False)
            await asyncio.sleep(0.6)

            d = Demo(c)
            d.total = 58.0 if SHORT else 92.0
            d.t0 = time.perf_counter()
            d.wall0 = time.time()
            d.ev("card", h1="PathOGen", h2="Learn Grasshopper by beating monsters", p="A browser game for architecture students")
            if VERTICAL:
                x0, y0 = await c.js("__demo.pos()", False)
                d.ev("move", x0=x0, y0=y0, x1=x0, y1=y0, ms=10)
            d.recording = True
            await d.start_capture()
            await (script_short(d) if SHORT else script(d))
            await asyncio.sleep(0.3)
            d.recording = False
            await d.stop_capture()
            (HERE / (FRAMES.name + ".json")).write_text(json.dumps({"fps": FPS, "w": W, "h": H, "dir": FRAMES.name, "frames": d.frames, "events": d.events}), encoding="utf-8")
            dur = d.frames[-1][1]
            print(f"captured {len(d.frames)} frames over {dur:.1f}s = {len(d.frames) / dur:.1f} fps")
            reader.cancel()
    finally:
        proc.terminate()


async def script(d: Demo):
    c = d.c
    # 0 — hook
    await d.sleep(2.6)
    await d.uncard()
    await d.cap('Every level is a <span class="hl">real Grasshopper script</span>', "mid", 2.2)
    await d.uncap()
    # 1 — title -> map
    await d.click("#btn-start", after=1.0)
    await d.cap('<span class="hl">4 levels</span> from base shape to facade', "top")
    await d.move(960, 560, 900)
    await d.sleep(1.8)
    await d.uncap()
    # 2 — difficulty picker
    await d.click('.map-node[data-i="1"]', after=0.8)
    await d.click('.campaign-challenge', ms=500, after=0.9)
    await d.cap('Each difficulty = a <span class="hl">different method</span>', "top", 2.4)
    await d.uncap()
    await d.click('[data-act="diff:1:0"]', after=1.0)
    # 3 — briefing
    await d.cap('Meet the monster. See the <span class="hl">goal</span>.', "top", 2.2)
    await d.uncap()
    await d.click('[data-act="fight"]', after=1.2)
    # 4 — battle overview
    await d.cap('Rebuild the definition <span class="hl">one node at a time</span>', "mid", 2.4)
    await d.uncap()
    await d.zoom("#p-graph", 1.75)
    await d.cap('The <span class="hl">glowing node</span> is your next step', "bottom", 2.3)
    await d.uncap()
    await d.zoom(None)
    # 5 — first correct pick
    await d.cap('Pick a card from your hand…', "mid")
    dec = await d.decision()
    await d.click(f'#hand .card[data-id="{dec["id"]}"]', after=0.6)
    await d.cap('…and <span class="hl">place it!</span>', "mid")
    await d.click("#featured .place", ms=420, after=0.9)
    await d.uncap()
    await d.zoom("#feedback", 1.9)
    await d.cap('Field notes explain <span class="hl">why</span> it works', "top", 2.4)
    await d.uncap()
    await d.zoom(None)
    # 6 — a wrong pick
    dec = await d.decision()
    wrong = next(h for h in dec["hand"] if h != dec["id"])
    await d.cap('Pick the <span class="hl">wrong</span> one and…', "mid")
    await d.click(f'#hand .card[data-id="{wrong}"]', after=0.5)
    await d.click("#featured .place", ms=380, after=0.4)
    await d.cap('…the monster <span class="hl">strikes!</span>', "mid", 1.6)
    await d.uncap()
    await d.zoom("#feedback", 1.8)
    await d.cap('You still learn <span class="hl">what went wrong</span>', "top", 2.2)
    await d.uncap()
    await d.zoom(None)
    # 7 — lifesaver
    await d.cap('Stuck? Use a <span class="hl">lifesaver</span>', "mid", 1.2)
    await d.click('[data-ls="hint"]', after=0.7)
    await d.zoom("#lifesavers", 1.9)
    await d.cap('Hints · potions · 50/50 · shields · second chances', "top", 2.4)
    await d.uncap()
    await d.zoom(None)
    await d.correct("card", 420)
    # 8 — move + wire check
    await d.correct("card", 380)
    dec = await d.decision()
    if dec and dec["kind"] == "quiz":
        await d.cap('<span class="hl">Wire checks:</span> plug into the right input', "mid", 1.4)
        await d.pick(dec["id"], "button", 450)
        await d.uncap()
    # 9 — rotate + its wire checks, live preview
    await d.correct("card", 380)
    for _ in range(3):
        dec = await d.decision()
        if not dec or dec["kind"] != "quiz":
            break
        await d.pick(dec["id"], "card", 350)
    await d.zoom("#p-preview", 1.7)
    await d.cap('The <span class="hl">3D preview</span> grows with every move', "top", 2.4)
    await d.uncap()
    await d.zoom(None)
    # 10 — finish quickly
    await d.cap('Loft → Cap Holes → a <span class="hl">solid tower</span>', "top")
    for _ in range(6):
        dec = await d.decision()
        if not dec:
            break
        await d.pick(dec["id"], "card", 300)
    await d.sleep(0.8)
    await d.uncap()
    # 11 — victory
    await d.cap('Earn <span class="hl">stars, XP</span> and rank up', "top", 2.6)
    await d.uncap()
    await d.click('[data-act="explore"]', after=0.8)
    # 12 — sliders
    await d.zoom("#p-preview", 1.45)
    await d.cap('Drag the sliders: it\'s <span class="hl">fully parametric</span>', "top")
    sl = await c.js("""(() => { const l=[...document.querySelectorAll('#params input')]; const i=l.findIndex(x=>/twist/i.test(x.parentElement.textContent)); return i<0?l.length-1:i; })()""", False)
    sel = f"#params label:nth-of-type({sl + 1}) input"
    await d.drag_range(sel, 0.97, ms=1500)
    await d.drag_range(sel, 0.15, ms=1300)
    sl2 = await c.js("""(() => { const l=[...document.querySelectorAll('#params input')]; return l.findIndex(x=>/^floors$/i.test(x.parentElement.querySelector('span').textContent.trim())); })()""", False)
    if sl2 is not None and sl2 >= 0:
        await d.drag_range(f"#params label:nth-of-type({sl2 + 1}) input", 0.85, ms=1100)
    await d.uncap()
    # 13 — views
    await d.click("#view-btn", after=0.5)
    await d.click('#view-menu button[data-view="top"]', ms=350, after=1.0)
    await d.cap('Orbit · zoom · <span class="hl">switch views</span>', "top", 1.6)
    await d.click("#view-btn", ms=350, after=0.4)
    await d.click('#view-menu button[data-view="perspective"]', ms=350, after=0.6)
    await d.uncap()
    await d.zoom(None)
    # 14 — end card
    await d.card('PathOGen', 'Build the script. Survive the monster.<br>Master Grasshopper.', '4 levels · 3 methods each · real Grasshopper definitions')
    await d.sleep(3.6)


async def script_short(d: Demo):
    """~60 s cut: same story, tighter holds, fewer zooms."""
    c = d.c
    await d.sleep(1.8)
    await d.uncard()
    await d.cap('Every level is a <span class="hl">real Grasshopper script</span>', "mid", 1.4)
    await d.uncap()
    await d.click("#btn-start", ms=450, after=0.7)
    await d.cap('<span class="hl">4 levels</span> from base shape to facade', "top", 1.4)
    await d.click('.map-node[data-i="1"]', ms=450, after=0.5)
    await d.click('.campaign-challenge', ms=400, after=0.6)
    await d.cap('3 difficulties = <span class="hl">3 different methods</span>', "top", 1.5)
    await d.click('[data-act="diff:1:0"]', ms=400, after=0.6)
    await d.cap('Meet the monster. See the <span class="hl">goal</span>.', "top", 1.1)
    await d.uncap()
    await d.click('[data-act="fight"]', ms=400, after=0.8)
    await d.focus("#p-graph")
    await d.cap('Fill the <span class="hl">glowing node</span>, one step at a time', "mid", 1.5)
    await d.focus(None)
    await d.cap('Pick a card → <span class="hl">place it</span>', "mid")
    dec = await d.decision()
    await d.click(f'#hand .card[data-id="{dec["id"]}"]', ms=450, after=0.45)
    await d.click("#featured .place", ms=350, after=0.6)
    await d.focus("#feedback")
    await d.cap('Field notes explain <span class="hl">why</span>', "mid", 1.3)
    await d.focus(None)
    dec = await d.decision()
    wrong = next(h for h in dec["hand"] if h != dec["id"])
    await d.cap('Wrong card? The monster <span class="hl">strikes!</span>', "mid")
    await d.click(f'#hand .card[data-id="{wrong}"]', ms=400, after=0.35)
    await d.click("#featured .place", ms=320, after=0.2)
    await d.focus("#p-health")
    await d.sleep(1.1)
    await d.focus(None)
    await d.cap('Stuck? Use a <span class="hl">lifesaver</span>', "mid")
    await d.click('[data-ls="hint"]', ms=400, after=1.0)
    await d.uncap()
    await d.correct("card", 380)
    await d.correct("card", 340)
    dec = await d.decision()
    if dec and dec["kind"] == "quiz":
        await d.cap('<span class="hl">Wire checks:</span> pick the right input', "mid")
        await d.pick(dec["id"], "button", 400)
        await d.uncap()
    await d.correct("card", 340)
    for _ in range(3):
        dec = await d.decision()
        if not dec or dec["kind"] != "quiz":
            break
        await d.pick(dec["id"], "card", 300)
    await d.zoom("#p-preview", 1.6)
    await d.cap('The <span class="hl">3D preview</span> grows live', "top", 1.4)
    await d.zoom(None)
    await d.cap('Loft → Cap → a <span class="hl">solid tower</span>', "top")
    for _ in range(6):
        dec = await d.decision()
        if not dec:
            break
        await d.pick(dec["id"], "card", 260)
    await d.sleep(0.5)
    await d.cap('Earn <span class="hl">stars, XP</span> and rank up', "top", 1.5)
    await d.uncap()
    await d.click('[data-act="explore"]', ms=400, after=0.6)
    await d.zoom("#p-preview", 1.45)
    await d.cap("Drag a slider: it's <span class=\"hl\">fully parametric</span>", "top")
    sl = await c.js("""(() => { const l=[...document.querySelectorAll('#params input')]; const i=l.findIndex(x=>/twist/i.test(x.parentElement.textContent)); return i<0?l.length-1:i; })()""", False)
    sel = f"#params label:nth-of-type({sl + 1}) input"
    await d.drag_range(sel, 0.97, ms=1200)
    await d.uncap()
    await d.zoom(None)
    await d.card('PathOGen', 'Build the script. Survive the monster.<br>Master Grasshopper.', '4 levels · 3 methods each · real Grasshopper definitions')
    await d.sleep(2.5)


if __name__ == "__main__":
    asyncio.run(main())
