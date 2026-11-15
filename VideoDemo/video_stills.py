"""Save PNG stills from a demo MP4 at given times (decoded by headless Chrome).  python video_stills.py video.mp4 4 14 30"""
import asyncio, base64, json, subprocess, sys, time
from pathlib import Path

import requests
import websockets

HERE = Path(__file__).resolve().parent
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"


async def main(video, times):
    srv = subprocess.Popen([sys.executable, "-m", "http.server", "5183", "--bind", "127.0.0.1", "--directory", str(HERE)],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    prof = HERE / "chrome-stills"
    ch = subprocess.Popen([CHROME, "--headless=new", "--remote-debugging-port=9335", f"--user-data-dir={prof}", "--mute-audio",
                           "--autoplay-policy=no-user-gesture-required", "about:blank"])
    try:
        for _ in range(50):
            try:
                page = next(t for t in requests.get("http://127.0.0.1:9335/json", timeout=1).json() if t["type"] == "page"); break
            except Exception:
                time.sleep(0.2)
        async with websockets.connect(page["webSocketDebuggerUrl"], max_size=2 ** 28) as ws:
            n = 0

            async def js(expr):
                nonlocal n
                n += 1
                await ws.send(json.dumps({"id": n, "method": "Runtime.evaluate", "params": {"expression": expr, "awaitPromise": True, "returnByValue": True}}))
                while True:
                    m = json.loads(await ws.recv())
                    if m.get("id") == n:
                        return m["result"].get("result", {}).get("value")

            await ws.send(json.dumps({"id": 0, "method": "Page.navigate", "params": {"url": "http://127.0.0.1:5183/encode.html"}}))
            await asyncio.sleep(1.5)
            await js(f"""(async () => {{ document.body.innerHTML='<video id=v muted src="{video}"></video>'; const v=document.getElementById('v');
                await new Promise(r => v.onloadedmetadata = r); window.v = v; return v.duration; }})()""")
            for t in times:
                data = await js(f"""(async () => {{ const v=window.v; v.playbackRate=4; await v.play();
                    while (v.currentTime < {t} && !v.ended) await new Promise(r => setTimeout(r, 10)); v.pause();
                    await new Promise(r => setTimeout(r, 80));
                    const c=document.createElement('canvas'); c.width=v.videoWidth/2; c.height=v.videoHeight/2;
                    c.getContext('2d').drawImage(v,0,0,c.width,c.height); return c.toDataURL('image/jpeg',0.85); }})()""")
                out = HERE / "stills" / f"{Path(video).stem}_{t:05.1f}.jpg"
                out.parent.mkdir(exist_ok=True)
                out.write_bytes(base64.b64decode(data.split(",", 1)[1]))
                print(out)
    finally:
        ch.terminate(); srv.terminate()


asyncio.run(main(sys.argv[1], [float(x) for x in sys.argv[2:]]))
