/* PathOGen — geometry helpers + a tiny wireframe 3D viewport (no dependencies). */

const G = {
  circle(c, r, n = 48) {
    const pts = [];
    for (let i = 0; i < n; i++) { const a = (i / n) * Math.PI * 2; pts.push([c[0] + r * Math.cos(a), c[1] + r * Math.sin(a), c[2]]); }
    return pts;
  },
  polygon(c, r, sides, rot = 0) {
    const pts = [];
    for (let i = 0; i < sides; i++) { const a = rot + (i / sides) * Math.PI * 2; pts.push([c[0] + r * Math.cos(a), c[1] + r * Math.sin(a), c[2]]); }
    return pts;
  },
  rect(c, w, h, plane = 'xy') {
    const [x, y, z] = c, a = w / 2, b = h / 2;
    if (plane === 'xz') return [[x - a, y, z - b], [x + a, y, z - b], [x + a, y, z + b], [x - a, y, z + b]];
    return [[x - a, y - b, z], [x + a, y - b, z], [x + a, y + b, z], [x - a, y + b, z]];
  },
  move: (pts, v) => pts.map(p => [p[0] + v[0], p[1] + v[1], p[2] + v[2]]),
  rotZ(pts, ang, c = [0, 0, 0]) {
    const cs = Math.cos(ang), sn = Math.sin(ang);
    return pts.map(p => { const x = p[0] - c[0], y = p[1] - c[1]; return [c[0] + x * cs - y * sn, c[1] + x * sn + y * cs, p[2]]; });
  },
  scale: (pts, f, c = [0, 0, 0]) => pts.map(p => [c[0] + (p[0] - c[0]) * f, c[1] + (p[1] - c[1]) * f, c[2] + (p[2] - c[2]) * f]),
  centroid(pts) { const s = [0, 0, 0]; pts.forEach(p => { s[0] += p[0]; s[1] += p[1]; s[2] += p[2]; }); return s.map(v => v / pts.length); },
  /* Catmull-Rom spline through points (open). */
  spline(pts, seg = 12) {
    if (pts.length < 3) return pts.slice();
    const out = [], P = [pts[0], ...pts, pts[pts.length - 1]];
    for (let i = 1; i < P.length - 2; i++) {
      for (let s = 0; s < seg; s++) {
        const t = s / seg, t2 = t * t, t3 = t2 * t;
        out.push([0, 1, 2].map(k => 0.5 * ((2 * P[i][k]) + (-P[i - 1][k] + P[i + 1][k]) * t +
          (2 * P[i - 1][k] - 5 * P[i][k] + 4 * P[i + 1][k] - P[i + 2][k]) * t2 +
          (-P[i - 1][k] + 3 * P[i][k] - 3 * P[i + 1][k] + P[i + 2][k]) * t3)));
      }
    }
    out.push(pts[pts.length - 1]);
    return out;
  },
  /* Divide a polyline into n equal-length segments -> n+1 points (or n points if closed). */
  divide(pts, n, closed = false) {
    const P = closed ? [...pts, pts[0]] : pts, L = [0];
    for (let i = 1; i < P.length; i++) L.push(L[i - 1] + Math.hypot(P[i][0] - P[i - 1][0], P[i][1] - P[i - 1][1], P[i][2] - P[i - 1][2]));
    const total = L[L.length - 1], out = [], count = closed ? n : n + 1;
    let j = 1;
    for (let k = 0; k < count; k++) {
      const d = (k / n) * total;
      while (j < L.length - 1 && L[j] < d) j++;
      const seg = L[j] - L[j - 1] || 1, t = Math.min(1, Math.max(0, (d - L[j - 1]) / seg));
      out.push([0, 1, 2].map(i => P[j - 1][i] + (P[j][i] - P[j - 1][i]) * t));
    }
    return out;
  },
  /* Loft preview: section curves plus smooth rails through matching vertices. */
  loft(sections, closed = true, k = 'loft') {
    const lines = sections.map(s => ({ pts: s, closed, k }));
    const n = sections[0].length;
    for (let i = 0; i < n; i++) lines.push({ pts: G.spline(sections.map(s => s[i]), 8), k, w: 0.9 });
    return lines;
  },
  range: (n) => Array.from({ length: n }, (_, i) => i),
  fmt: (v) => (Math.round(v * 100) / 100).toString(),
  list(vals, max = 6) { const s = vals.slice(0, max).map(G.fmt).join(', '); return vals.length > max ? s + ', …' : s; },
};

class Preview {
  constructor(canvas) {
    this.c = canvas; this.ctx = canvas.getContext('2d');
    this.theta = -0.95; this.el = 0.55; this.goalTheta = this.theta; this.goalEl = this.el;
    this.target = [0, 0, 0]; this.goalTarget = [0, 0, 0];
    this.radius = 8; this.goalRadius = 8; this.zoom = 1;
    this.view = 'perspective'; this.auto = true;
    this.scene = { lines: [], points: [], labels: [], arrows: [] };
    this.fresh = null; this.freshT = 0;
    this.bindEvents();
    const loop = () => { this.frame(); requestAnimationFrame(loop); };
    requestAnimationFrame(loop);
  }
  bindEvents() {
    let drag = null;
    this.c.addEventListener('pointerdown', e => { drag = { x: e.clientX, y: e.clientY }; this.c.setPointerCapture(e.pointerId); this.auto = false; });
    this.c.addEventListener('pointermove', e => {
      if (!drag) return;
      const dx = e.clientX - drag.x, dy = e.clientY - drag.y; drag = { x: e.clientX, y: e.clientY };
      if (this.view !== 'perspective') this.setView('perspective', true);
      this.goalTheta -= dx * 0.008; this.goalEl = Math.max(-0.2, Math.min(1.5, this.goalEl + dy * 0.008));
      this.theta = this.goalTheta; this.el = this.goalEl;
    });
    const up = () => { drag = null; clearTimeout(this.autoT); this.autoT = setTimeout(() => { if (this.view === 'perspective') this.auto = true; }, 4000); };
    this.c.addEventListener('pointerup', up); this.c.addEventListener('pointercancel', up);
    this.c.addEventListener('wheel', e => { e.preventDefault(); this.zoom = Math.max(0.35, Math.min(3, this.zoom * (e.deltaY > 0 ? 1.1 : 0.9))); }, { passive: false });
    this.c.addEventListener('dblclick', () => { this.zoom = 1; this.auto = true; });
  }
  setView(v, keepAngles) {
    this.view = v;
    if (v === 'top') { this.goalEl = 1.5699; this.goalTheta = -Math.PI / 2; this.auto = false; }
    else if (v === 'front') { this.goalEl = 0.02; this.goalTheta = -Math.PI / 2; this.auto = false; }
    else if (!keepAngles) { this.goalEl = 0.55; this.goalTheta = -0.95; this.auto = true; }
  }
  setScene(scene, freshKey) {
    this.scene = Object.assign({ lines: [], points: [], labels: [], arrows: [] }, scene);
    const all = [];
    this.scene.lines.forEach(l => all.push(...l.pts));
    this.scene.points.forEach(p => all.push(p.p));
    this.scene.arrows.forEach(a => all.push(a.from, a.to));
    this.scene.labels.forEach(l => all.push(l.p));
    if (all.length) {
      const mn = [Infinity, Infinity, Infinity], mx = [-Infinity, -Infinity, -Infinity];
      all.forEach(p => { for (let i = 0; i < 3; i++) { mn[i] = Math.min(mn[i], p[i]); mx[i] = Math.max(mx[i], p[i]); } });
      this.bbox = { mn, mx };
      this.goalTarget = mn.map((v, i) => (v + mx[i]) / 2);
      this.goalRadius = Math.max(4, Math.hypot(mx[0] - mn[0], mx[1] - mn[1], mx[2] - mn[2]) / 2);
    } else { this.bbox = null; this.goalTarget = [0, 0, 0]; this.goalRadius = 6; }
    if (freshKey) { this.fresh = freshKey; this.freshT = performance.now(); }
  }
  camera(w, h) {
    const dist = (this.radius * 2.9) * this.zoom;
    const ce = Math.cos(this.el), se = Math.sin(this.el);
    const pos = [this.target[0] + dist * ce * Math.cos(this.theta), this.target[1] + dist * ce * Math.sin(this.theta), this.target[2] + dist * se];
    const f = norm(sub(this.target, pos));
    let r = cross(f, [0, 0, 1]); if (len(r) < 1e-6) r = [1, 0, 0]; r = norm(r);
    const u = cross(r, f);
    const fl = (h / 2) / Math.tan(0.5 * 0.75);
    return { pos, f, r, u, fl, w, h };
  }
  project(p, cam) {
    const rel = sub(p, cam.pos), z = dot(rel, cam.f);
    if (z < 0.05) return null;
    return [cam.w / 2 + dot(rel, cam.r) * cam.fl / z, cam.h / 2 - dot(rel, cam.u) * cam.fl / z, z];
  }
  frame() {
    const c = this.c, rect = c.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 1;
    const lw = c.clientWidth, lh = c.clientHeight;
    if (!lw || !lh) return;
    const k = (rect.width / lw) * dpr;
    if (c.width !== Math.round(lw * k) || c.height !== Math.round(lh * k)) { c.width = Math.round(lw * k); c.height = Math.round(lh * k); }
    const ctx = this.ctx; ctx.setTransform(k, 0, 0, k, 0, 0);
    // ease camera
    const e = 0.12;
    if (this.auto) this.goalTheta += 0.0016;
    this.theta += (this.goalTheta - this.theta) * e; this.el += (this.goalEl - this.el) * e;
    this.radius += (this.goalRadius - this.radius) * e;
    this.target = this.target.map((v, i) => v + (this.goalTarget[i] - v) * e);
    const cam = this.camera(lw, lh);

    const bg = ctx.createLinearGradient(0, 0, 0, lh);
    bg.addColorStop(0, '#c9d1d3'); bg.addColorStop(1, '#a9b4b7');
    ctx.fillStyle = bg; ctx.fillRect(0, 0, lw, lh);

    // ground grid on z = 0
    const step = niceStep(this.radius / 3), ext = Math.ceil((this.radius * 1.8) / step) * step;
    const cx = Math.round(this.target[0] / step) * step, cy = Math.round(this.target[1] / step) * step;
    ctx.lineWidth = 1;
    for (let i = -ext; i <= ext + 1e-9; i += step) {
      const major = Math.abs(Math.round((cx + i) / step)) % 5 === 0;
      ctx.strokeStyle = major ? 'rgba(255,255,255,.42)' : 'rgba(255,255,255,.22)';
      this.seg([cx + i, cy - ext, 0], [cx + i, cy + ext, 0], cam);
      ctx.strokeStyle = major ? 'rgba(255,255,255,.42)' : 'rgba(255,255,255,.22)';
      this.seg([cx - ext, cy + i, 0], [cx + ext, cy + i, 0], cam);
    }
    ctx.lineWidth = 1.4;
    ctx.strokeStyle = 'rgba(170,60,60,.55)'; this.seg([0, 0, 0], [ext * 0.35, 0, 0], cam);
    ctx.strokeStyle = 'rgba(60,140,80,.55)'; this.seg([0, 0, 0], [0, ext * 0.35, 0], cam);

    // faint bounding box
    if (this.bbox && this.scene.lines.length) {
      const { mn, mx } = this.bbox, pad = this.radius * 0.18;
      const a = mn.map(v => v - pad), b = mx.map(v => v + pad);
      const C = [[a[0], a[1], a[2]], [b[0], a[1], a[2]], [b[0], b[1], a[2]], [a[0], b[1], a[2]], [a[0], a[1], b[2]], [b[0], a[1], b[2]], [b[0], b[1], b[2]], [a[0], b[1], b[2]]];
      ctx.strokeStyle = 'rgba(190,80,95,.28)'; ctx.lineWidth = 1;
      [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]].forEach(([i, j]) => this.seg(C[i], C[j], cam));
    }

    const now = performance.now(), age = (now - this.freshT) / 1000;
    const glow = this.fresh && age < 3.2 ? 1 - Math.max(0, age - 2.2) : 0;
    const isFresh = (key) => glow > 0 && key && key === this.fresh;

    this.scene.lines.forEach(l => {
      const f = isFresh(l.k);
      ctx.strokeStyle = f ? `rgba(31,150,90,${0.55 + 0.45 * glow})` : (l.color || 'rgba(196,44,66,.9)');
      ctx.lineWidth = (l.w || 1.35) + (f ? 1.2 * glow : 0);
      ctx.setLineDash(l.dash ? [4, 4] : []);
      ctx.beginPath(); let started = false;
      const pts = l.closed ? [...l.pts, l.pts[0]] : l.pts;
      pts.forEach(p => { const q = this.project(p, cam); if (!q) { started = false; return; } if (!started) { ctx.moveTo(q[0], q[1]); started = true; } else ctx.lineTo(q[0], q[1]); });
      ctx.stroke();
    });
    ctx.setLineDash([]);
    this.scene.arrows.forEach(a => {
      const f = isFresh(a.k);
      const p = this.project(a.from, cam), q = this.project(a.to, cam); if (!p || !q) return;
      ctx.strokeStyle = ctx.fillStyle = f ? '#1f965a' : (a.color || '#2f5f8a'); ctx.lineWidth = f ? 2.4 : 1.6;
      ctx.beginPath(); ctx.moveTo(p[0], p[1]); ctx.lineTo(q[0], q[1]); ctx.stroke();
      const ang = Math.atan2(q[1] - p[1], q[0] - p[0]);
      ctx.beginPath(); ctx.moveTo(q[0], q[1]);
      ctx.lineTo(q[0] - 9 * Math.cos(ang - 0.4), q[1] - 9 * Math.sin(ang - 0.4));
      ctx.lineTo(q[0] - 9 * Math.cos(ang + 0.4), q[1] - 9 * Math.sin(ang + 0.4)); ctx.closePath(); ctx.fill();
    });
    this.scene.points.forEach(pt => {
      const q = this.project(pt.p, cam); if (!q) return;
      const f = isFresh(pt.k), s = (pt.size || 3.4) + (f ? 1.2 : 0);
      ctx.strokeStyle = f ? '#1f965a' : (pt.color || '#8a1a2c'); ctx.lineWidth = f ? 2 : 1.6;
      ctx.beginPath(); ctx.moveTo(q[0] - s, q[1] - s); ctx.lineTo(q[0] + s, q[1] + s); ctx.moveTo(q[0] + s, q[1] - s); ctx.lineTo(q[0] - s, q[1] + s); ctx.stroke();
    });
    ctx.font = '600 11px "Barlow", system-ui, sans-serif';
    this.scene.labels.forEach(lb => {
      const q = this.project(lb.p, cam); if (!q) return;
      const f = isFresh(lb.k), tw = ctx.measureText(lb.text).width;
      ctx.fillStyle = 'rgba(255,255,255,.78)'; ctx.fillRect(q[0] + 6, q[1] - 16, tw + 10, 17);
      ctx.fillStyle = f ? '#14774a' : '#2a3436'; ctx.fillText(lb.text, q[0] + 11, q[1] - 4);
    });
  }
  seg(a, b, cam) {
    const p = this.project(a, cam), q = this.project(b, cam); if (!p || !q) return;
    this.ctx.beginPath(); this.ctx.moveTo(p[0], p[1]); this.ctx.lineTo(q[0], q[1]); this.ctx.stroke();
  }
}

function sub(a, b) { return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]; }
function dot(a, b) { return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]; }
function cross(a, b) { return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]; }
function len(a) { return Math.hypot(a[0], a[1], a[2]); }
function norm(a) { const l = len(a) || 1; return [a[0] / l, a[1] / l, a[2] / l]; }
function niceStep(x) { const p = Math.pow(10, Math.floor(Math.log10(x))), m = x / p; return (m < 1.5 ? 1 : m < 3.5 ? 2 : m < 7.5 ? 5 : 10) * p; }
