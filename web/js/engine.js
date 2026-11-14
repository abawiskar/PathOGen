/* PathOGen — a tiny Grasshopper-style solver.
 *
 * Evaluates a level's component graph the way Grasshopper does (simplified):
 *  - data travels in trees: an array of branches { path: [..], items: [..] }
 *  - item inputs iterate with longest-list matching; list inputs receive the whole branch
 *  - branches are matched one-to-one, re-using the last branch of the shorter tree
 *  - unconnected inputs fall back to node.set values, then to the component defaults
 * Only the components the levels use are implemented. Any node may carry `baked` geometry instead.
 *
 * Geometry items: { t:'pt', p } { t:'vec', v } { t:'crv', pts, closed } { t:'pl', o, x, y, z }
 *                 { t:'srf', c:[p00,p10,p11,p01] } { t:'loft', sections:[crv] } { t:'dom2', u0,u1,v0,v1 }
 */
const Engine = (() => {
  const V = {
    add: (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]], sub: (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]],
    mul: (a, s) => [a[0] * s, a[1] * s, a[2] * s], dot: (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2],
    cross: (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]],
    len: (a) => Math.hypot(a[0], a[1], a[2]), unit: (a) => { const l = Math.hypot(a[0], a[1], a[2]) || 1; return [a[0] / l, a[1] / l, a[2] / l]; },
  };
  const pt = (p) => ({ t: 'pt', p }), vec = (v) => ({ t: 'vec', v }), crv = (pts, closed) => ({ t: 'crv', pts, closed: !!closed });
  const plane = (o, x, y) => ({ t: 'pl', o, x: V.unit(x), y: V.unit(y), z: V.unit(V.cross(x, y)) });
  const PLANES = { XY: () => plane([0, 0, 0], [1, 0, 0], [0, 1, 0]), XZ: () => plane([0, 0, 0], [1, 0, 0], [0, 0, 1]), YZ: () => plane([0, 0, 0], [0, 1, 0], [0, 0, 1]) };

  /* ───── coercion (Grasshopper auto-converts between types) ───── */
  const toPlane = (v) => {
    if (v == null) return PLANES.XY();
    if (typeof v === 'string') return (PLANES[v.toUpperCase()] || PLANES.XY)();
    if (v.t === 'pl') return v;
    const o = toPoint(v); const p = PLANES.XY(); p.o = o; return p;
  };
  const toPoint = (v) => (v == null ? [0, 0, 0] : Array.isArray(v) ? v : v.t === 'pt' ? v.p : v.t === 'pl' ? v.o : v.t === 'vec' ? v.v : [0, 0, 0]);
  const toVec = (v) => (v == null ? [0, 0, 0] : typeof v === 'number' ? [0, 0, v] : Array.isArray(v) ? v : v.t === 'vec' ? v.v : v.t === 'pt' ? v.p : [0, 0, 0]);
  const toNum = (v) => (typeof v === 'number' ? v : typeof v === 'boolean' ? +v : v && v.t === 'vec' ? V.len(v.v) : Number(v) || 0);
  const toDomain = (v) => (Array.isArray(v) && v.length === 2 && typeof v[0] === 'number' ? v : [0, toNum(v)]);
  const onPlane = (pl, u, w) => V.add(pl.o, V.add(V.mul(pl.x, u), V.mul(pl.y, w)));

  function mapGeo(g, f) {
    if (!g || typeof g !== 'object') return g;
    switch (g.t) {
      case 'pt': return pt(f(g.p));
      case 'crv': return Object.assign({}, g, { pts: g.pts.map(f) });
      case 'srf': return Object.assign({}, g, { c: g.c.map(f) });
      case 'loft': return Object.assign({}, g, { sections: g.sections.map(s => mapGeo(s, f)) });
      case 'pl': { const o = f(g.o), x = V.sub(f(V.add(g.o, g.x)), o), y = V.sub(f(V.add(g.o, g.y)), o); return plane(o, x, y); }
      default: return g;
    }
  }
  const geoPoints = (g) => (g.t === 'pt' ? [g.p] : g.t === 'crv' ? g.pts : g.t === 'srf' ? g.c : g.t === 'loft' ? g.sections.flatMap(geoPoints) : []);
  function rotAxis(p, o, axis, a) {
    const k = V.unit(axis), r = V.sub(p, o), c = Math.cos(a), s = Math.sin(a);
    return V.add(o, V.add(V.add(V.mul(r, c), V.mul(V.cross(k, r), s)), V.mul(k, V.dot(k, r) * (1 - c))));
  }
  /* point on a loft: u runs along the sections (by vertex index), w across them */
  function loftPoint(l, u, w) {
    const S = l.sections, m = S[0].pts.length, closed = S[0].closed;
    const along = (pts) => { const x = u * (closed ? m : m - 1), i = Math.floor(x) % m, j = closed ? (i + 1) % m : Math.min(i + 1, m - 1), f = x - Math.floor(x); return V.add(V.mul(pts[i], 1 - f), V.mul(pts[j], f)); };
    const ring = S.map(c => along(c.pts));
    const y = w * (ring.length - 1), a = Math.min(Math.floor(y), ring.length - 2), f = y - a;
    return V.add(V.mul(ring[a], 1 - f), V.mul(ring[a + 1], f));
  }
  /* horizontal section of a loft at height z (rails treated as polylines between sections) */
  function loftRing(l, z) {
    const S = l.sections, m = S[0].pts.length;
    return G.range(m).map(i => {
      for (let j = 0; j < S.length - 1; j++) {
        const a = S[j].pts[i], b = S[j + 1].pts[i];
        if ((z - a[2]) * (z - b[2]) <= 0 && a[2] !== b[2]) { const f = (z - a[2]) / (b[2] - a[2]); return V.add(V.mul(a, 1 - f), V.mul(b, f)); }
      }
      return S[z < S[0].pts[i][2] ? 0 : S.length - 1].pts[i];
    });
  }
  const srfPoint = (s, u, w) => { const [a, b, c, d] = s.c; const p = V.add(V.mul(a, 1 - u), V.mul(b, u)), q = V.add(V.mul(d, 1 - u), V.mul(c, u)); return V.add(V.mul(p, 1 - w), V.mul(q, w)); };
  const L = (arr) => ({ list: arr });

  /* ───── component solvers: def = defaults per input, access = 'list' for list inputs ───── */
  const S = {
    slider: { fn: (a, n, ctx) => [n.param != null ? ctx.params[n.param] : (n.value != null ? n.value : 5)] },
    // a wired panel passes its input through (as in Grasshopper); unwired it outputs its typed values
    panel: { access: ['list'], def: [null], fn: ([v], n) => [L(v && v.some(x => x != null) ? v : (n.values || []))] },
    toggle: { fn: (a, n) => [n.value != null ? n.value : true] },
    pointParam: { fn: ([v]) => [v] }, curveParam: { fn: ([v]) => [v] }, dataParam: { fn: ([v]) => [v] }, numberParam: { fn: ([v]) => [v] },
    xyPlane: { def: [[0, 0, 0]], fn: ([o]) => { const p = PLANES.XY(); p.o = toPoint(o); return [p]; } },
    constructPoint: { def: [0, 0, 0], fn: ([x, y, z]) => [pt([toNum(x), toNum(y), toNum(z)])] },
    unitZ: { def: [1], fn: ([f]) => [vec([0, 0, toNum(f)])] },
    unitX: { def: [1], fn: ([f]) => [vec([toNum(f), 0, 0])] },
    vector2pt: { def: [undefined, undefined, false], fn: ([a, b, u]) => { let d = V.sub(toPoint(b), toPoint(a)); const l = V.len(d); if (u) d = V.unit(d); return [vec(d), l]; } },
    amplitude: { def: [undefined, 1], fn: ([v, a]) => [vec(V.mul(V.unit(toVec(v)), toNum(a)))] },
    line: { fn: ([a, b]) => [crv([toPoint(a), toPoint(b)])] },
    lineSDL: { def: [[0, 0, 0], vec([1, 0, 0]), 1], fn: ([s, d, l]) => { const p = toPoint(s); return [crv([p, V.add(p, V.mul(V.unit(toVec(d)), toNum(l)))])]; } },
    circle: { def: [null, 1], fn: ([p, r]) => { const pl = toPlane(p), R = toNum(r), pts = []; for (let i = 0; i < 64; i++) { const t = i / 64 * Math.PI * 2; pts.push(onPlane(pl, R * Math.cos(t), R * Math.sin(t))); } return [crv(pts, true)]; } },
    rectangle: { def: [null, 1, 1, 0], fn: ([p, x, y]) => { const pl = toPlane(p), X = toDomain(x), Y = toDomain(y); const pts = [[X[0], Y[0]], [X[1], Y[0]], [X[1], Y[1]], [X[0], Y[1]]].map(([u, w]) => onPlane(pl, u, w)); return [crv(pts, true), 2 * (Math.abs(X[1] - X[0]) + Math.abs(Y[1] - Y[0]))]; } },
    polygon: { def: [null, 1, 6, 0], fn: ([p, r, s, rf]) => {
      const pl = toPlane(p), R = toNum(r), n = Math.max(3, Math.round(toNum(s))), F = Math.max(0, toNum(rf));
      const half = Math.PI / n, edge = 2 * R * Math.sin(half), inner = Math.PI - 2 * half;
      const tdist = Math.min(F / Math.tan(inner / 2), edge / 2), fr = tdist * Math.tan(inner / 2), pts = [];
      for (let i = 0; i < n; i++) {
        const t = i / n * Math.PI * 2;
        if (fr < 1e-6) { pts.push(onPlane(pl, R * Math.cos(t), R * Math.sin(t))); continue; }
        // fillet arc: centre on the bisector, sweeping the corner's exterior angle
        const cd = R - fr / Math.sin(inner / 2), cx = cd * Math.cos(t), cy = cd * Math.sin(t);
        for (let k = 0; k <= 6; k++) { const a = t - half + (2 * half) * k / 6; pts.push(onPlane(pl, cx + fr * Math.cos(a), cy + fr * Math.sin(a))); }
      }
      return [crv(pts, true), polyLen([...pts, pts[0]])];
    } },
    interpolate: { access: ['list'], def: [undefined, 3, false, 0], fn: ([v]) => { const pts = v.map(toPoint); if (pts.length < 2) return [null, null, null]; const c = crv(G.spline(pts, 10)); return [c, polyLen(c.pts), [0, 1]]; } },
    divideCurve: { def: [undefined, 10, false], fn: ([c, n]) => {
      if (!c || c.t !== 'crv') return [null, null, null];
      const N = Math.max(1, Math.round(toNum(n))), P = G.divide(c.pts, N, c.closed);
      const T = P.map((p, i) => vec(V.unit(V.sub(P[Math.min(i + 1, P.length - 1)], P[Math.max(i - 1, 0)]))));
      return [L(P.map(pt)), L(T), L(P.map((_, i) => i / N))];
    } },
    loft: { access: ['list'], def: [undefined, null], fn: ([cs]) => {
      const secs = cs.filter(c => c && c.t === 'crv'); if (secs.length < 2) return [null];
      const cnt = Math.max(...secs.map(c => c.pts.length)), same = secs.every(c => c.pts.length === cnt);
      return [{ t: 'loft', sections: same ? secs : secs.map(c => crv(G.divide(c.pts, 24, c.closed), c.closed)) }];
    } },
    extrude: { def: [undefined, vec([0, 0, 1])], fn: ([b, d]) => b && b.t === 'crv' ? [{ t: 'loft', sections: [b, mapGeo(b, p => V.add(p, toVec(d)))] }] : [null] },
    pipe: { def: [undefined, 1, null], fn: ([c]) => [c && c.t === 'crv' ? Object.assign({}, c, { w: 4 }) : null] },
    boundary: { fn: ([e]) => { if (!e || e.t !== 'crv' || !e.closed) return [null]; return [e.pts.length === 4 ? { t: 'srf', c: e.pts.slice() } : { t: 'srf', c: [e.pts[0], e.pts[1], e.pts[2], e.pts[3] || e.pts[2]], outline: e.pts }]; } },
    divDomain2: { def: [undefined, 10, 10], fn: ([, u, v]) => { const U = Math.max(1, Math.round(toNum(u))), W = Math.max(1, Math.round(toNum(v))), out = []; for (let j = 0; j < W; j++) for (let i = 0; i < U; i++) out.push({ t: 'dom2', u0: i / U, u1: (i + 1) / U, v0: j / W, v1: (j + 1) / W }); return [L(out)]; } },
    isotrim: { fn: ([s, d]) => { if (!s || (s.t !== 'srf' && s.t !== 'loft') || !d || d.t !== 'dom2') return [null]; const f = s.t === 'loft' ? loftPoint : srfPoint; return [{ t: 'srf', c: [f(s, d.u0, d.v0), f(s, d.u1, d.v0), f(s, d.u1, d.v1), f(s, d.u0, d.v1)] }]; } },
    capHoles: { fn: ([b]) => [b && b.t === 'loft' ? Object.assign({}, b, { capped: true }) : b] },
    contour: { def: [undefined, [0, 0, 0], vec([0, 0, 1]), 1], fn: ([g, p, , d]) => {
      if (!g || g.t !== 'loft') return [L([])];
      const D = Math.max(0.05, toNum(d)), P = geoPoints(g), z0 = Math.min(...P.map(q => q[2])), z1 = Math.max(...P.map(q => q[2])), base = toPoint(p)[2], out = [];
      for (let z = base + Math.ceil((z0 - base) / D - 1e-9) * D; z <= z1 + 1e-9 && out.length < 400; z += D) out.push(crv(loftRing(g, z), true));
      return [L(out)];
    } },
    area: { fn: ([g]) => {
      if (!g) return [null, null];
      const P = geoPoints(g); if (!P.length) return [null, null];
      const c = V.mul(P.reduce((a, b) => V.add(a, b), [0, 0, 0]), 1 / P.length);
      let A = 0; for (let i = 0; i < P.length; i++) A += V.len(V.cross(V.sub(P[i], c), V.sub(P[(i + 1) % P.length], c))) / 2;
      return [A, pt(c)];
    } },
    series: { def: [0, 1, 10], fn: ([s, n, c]) => [L(G.range(Math.max(0, Math.round(toNum(c)))).map(i => toNum(s) + i * toNum(n)))] },
    range: { def: [[0, 1], 10], fn: ([d, n]) => { const D = toDomain(d), N = Math.max(1, Math.round(toNum(n))); return [L(G.range(N + 1).map(i => D[0] + (D[1] - D[0]) * i / N))]; } },
    cullPattern: { access: ['list', 'list'], fn: ([l, p]) => [L(p.length ? l.filter((_, i) => !!p[i % p.length]) : l)] },
    listItem: { access: ['list'], def: [undefined, 0, true], fn: ([l, i]) => [l.length ? l[((Math.round(toNum(i)) % l.length) + l.length) % l.length] : null] },
    reverseList: { access: ['list'], fn: ([l]) => [L(l.slice().reverse())] },
    sortList: { access: ['list', 'list'], fn: ([k, a]) => { const idx = k.map((_, i) => i).sort((x, y) => toNum(k[x]) - toNum(k[y])); return [L(idx.map(i => k[i])), L(idx.map(i => a[i]))]; } },
    shiftList: { access: ['list'], def: [undefined, 1, true], fn: ([l, s, w]) => {
      const n = l.length, k = Math.round(toNum(s)), out = [];
      for (let i = 0; i < n; i++) {
        if (w) out.push(l[(((i + k) % n) + n) % n]);
        else if (i + k >= 0 && i + k < n) out.push(l[i + k]);   // no wrap: items shifted off the end are dropped
      }
      return [L(out)];
    } },
    move: { def: [undefined, vec([0, 0, 10])], fn: ([g, t]) => { const d = toVec(t); return [mapGeo(g, p => V.add(p, d)), null]; } },
    rotate: { def: [undefined, Math.PI / 2, null], fn: ([g, a, p], n) => { const pl = toPlane(p), ang = toNum(a) * (n.degrees ? Math.PI / 180 : 1); return [mapGeo(g, q => rotAxis(q, pl.o, pl.z, ang)), null]; } },
    scale: { def: [undefined, [0, 0, 0], 0.5], fn: ([g, c, f]) => { const o = toPoint(c), k = toNum(f); return [mapGeo(g, q => V.add(o, V.mul(V.sub(q, o), k))), null]; } },
    mirror: { def: [undefined, 'YZ'], fn: ([g, p]) => { const pl = toPlane(p); return [mapGeo(g, q => V.sub(q, V.mul(pl.z, 2 * V.dot(V.sub(q, pl.o), pl.z)))), null]; } },
    sine: { fn: ([x]) => [Math.sin(toNum(x))] },
    multiplication: { def: [1, 1], fn: ([a, b]) => [a && a.t === 'vec' ? vec(V.mul(a.v, toNum(b))) : toNum(a) * toNum(b)] },
    addition: { def: [0, 0], fn: ([a, b]) => [toNum(a) + toNum(b)] },
    radians: { fn: ([d]) => [toNum(d) * Math.PI / 180] },
    remap: { def: [undefined, [0, 1], [0, 1]], fn: ([v, s, t]) => { const A = toDomain(s), B = toDomain(t), x = (toNum(v) - A[0]) / ((A[1] - A[0]) || 1); return [B[0] + x * (B[1] - B[0]), B[0] + Math.max(0, Math.min(1, x)) * (B[1] - B[0])]; } },
    /* Graph Mapper: node.graph = { type: 'linear'|'pinch'|'sine'|'bell', param?: '<slider key>' }; x is normalised to the incoming list.
     * { type: 'bezier', cp: [[x,y] ×4] } is Grasshopper's Bezier graph (from a .ghx), read over the graph's 0–1 domain like Grasshopper. */
    graphMapper: { access: ['list'], fn: ([xs], n, ctx) => {
      const nums = xs.map(toNum), lo = Math.min(...nums), hi = Math.max(...nums), g = n.graph || { type: 'linear' };
      if (g.type === 'bezier' && g.cp && g.cp.length === 4) {
        const [p0, p1, p2, p3] = g.cp, B = (t, i) => { const u = 1 - t; return u * u * u * p0[i] + 3 * u * u * t * p1[i] + 3 * u * t * t * p2[i] + t * t * t * p3[i]; };
        const yAt = (x) => {   // solve B_x(t) = x by bisection (x is monotonic along a graph-mapper Bezier)
          let a = 0, b = 1;
          for (let k = 0; k < 40; k++) { const m = (a + b) / 2; if (B(m, 0) < x) a = m; else b = m; }
          return B((a + b) / 2, 1);
        };
        return [L(nums.map(x => yAt(Math.max(0, Math.min(1, x)))))];
      }
      const k = g.param != null ? ctx.params[g.param] : (g.k != null ? g.k : 0.5);
      const f = { linear: t => t, pinch: t => 1 - k * Math.sin(Math.PI * t), sine: t => 0.5 + 0.5 * Math.sin(Math.PI * 2 * t), bell: t => Math.exp(-Math.pow((t - 0.5) / (0.2 + k * 0.3), 2)) }[g.type] || (t => t);
      return [L(nums.map(x => f(hi > lo ? (x - lo) / (hi - lo) : 0)))];
    } },
    /* ───── components used by the .ghx levels (ported from the Godot build's gh_engine.gd) ───── */
    unitY: { def: [1], fn: ([f]) => [vec([0, toNum(f), 0])] },
    division: { def: [1, 1], fn: ([a, b]) => { const B = toNum(b); return [Math.abs(B) > 1e-12 ? toNum(a) / B : null]; } },
    negative: { fn: ([x]) => [-toNum(x)] },
    circleCNR: { def: [[0, 0, 0], vec([0, 0, 1]), 1], fn: ([c, n, r]) => {
      const o = toPoint(c), z = V.unit(toVec(n)), x = V.unit(V.cross(V.cross(z, Math.abs(z[1]) < 0.9 ? [0, 1, 0] : [1, 0, 0]), z));
      const pl = { t: 'pl', o, x, y: V.cross(z, x), z }, R = toNum(r), pts = [];
      for (let i = 0; i < 64; i++) { const t = i / 64 * Math.PI * 2; pts.push(onPlane(pl, R * Math.cos(t), R * Math.sin(t))); }
      return [crv(pts, true)];
    } },
    endPoints: { fn: ([c]) => (!c || c.t !== 'crv' || !c.pts.length ? [null, null] : [pt(c.pts[0]), pt(c.closed ? c.pts[0] : c.pts[c.pts.length - 1])]) },
    polyline: { access: ['list'], def: [undefined, false], fn: ([v, closed]) => {
      const pts = v.map(toPoint); if (pts.length < 2) return [null];
      const cl = !!closed; if (cl && V.len(V.sub(pts[0], pts[pts.length - 1])) < 1e-9) pts.pop();
      return [crv(pts, cl)];
    } },
    fillet: { def: [undefined, 1], fn: ([c, r]) => [c && c.t === 'crv' ? filletCurve(c, toNum(r)) : null] },
    // Fillet (t): the .ghx levels feed it every corner, so fillet them all
    filletCtR: { access: ['item', 'list'], def: [undefined, [], 1], fn: ([c, , r]) => (c && c.t === 'crv' ? [filletCurve(c, toNum(r)), null] : [null, null]) },
    discontinuity: { def: [undefined, 1], fn: ([c]) => {
      if (!c || c.t !== 'crv') return [null, null];
      const P = [], T = [], n = c.pts.length;
      for (let i = 0; i < n; i++) {
        if (!c.closed && (i === 0 || i === n - 1)) continue;
        const p0 = c.pts[(i - 1 + n) % n], p1 = c.pts[i], p2 = c.pts[(i + 1) % n];
        const a = V.sub(p1, p0), b = V.sub(p2, p1);
        if (V.len(a) > 1e-9 && V.len(b) > 1e-9 && V.dot(V.unit(a), V.unit(b)) < 0.999) { P.push(pt(p1)); T.push(i); }
      }
      return [L(P), L(T)];
    } },
    joinCurves: { access: ['list'], def: [undefined, false], fn: ([cs]) => {
      const curves = cs.filter(c => c && c.t === 'crv' && c.pts.length > 1);
      return [curves.length ? L(joinCurves(curves)) : null];
    } },
    merge: { tree: (ts) => [mergeTrees(ts.filter(t => t && hasData(t))) || []] },
    trimWithRegion: { access: ['item', 'list'], def: [undefined, undefined, null], fn: ([c, regions]) => {
      const R = regions.filter(r => r && r.t === 'crv' && r.closed);
      if (!c || c.t !== 'crv' || !R.length) return [null, null];
      const [inside, outside] = trimCurve(c, R);
      return [L(inside), L(outside)];
    } },
    arcSED: { fn: ([s, e, d]) => {
      const S0 = toPoint(s), E = toPoint(e), D = V.unit(toVec(d)), ch = V.sub(E, S0);
      let nrm = V.cross(D, ch);
      if (V.len(nrm) < 1e-9) return [crv([S0, E]), null, null];
      nrm = V.unit(nrm);
      const perp = V.unit(V.cross(nrm, D)), r = V.dot(ch, ch) / (2 * V.dot(ch, perp));
      const C = V.add(S0, V.mul(perp, r)), v0 = V.sub(S0, C), v1 = V.sub(E, C);
      let sweep = Math.atan2(V.dot(V.cross(v0, v1), nrm), V.dot(v0, v1)); if (sweep < 0) sweep += Math.PI * 2;
      const steps = Math.max(4, Math.floor(sweep / (Math.PI * 2) * 64)), pts = [];
      for (let i = 0; i <= steps; i++) pts.push(rotAxis(S0, C, nrm, sweep * i / steps));
      return [crv(pts), null, Math.abs(r)];
    } },
    evaluateCurve: { def: [undefined, 0], fn: ([c, tt]) => {
      if (!c || c.t !== 'crv' || c.pts.length < 2) return [null, null, null];
      const P = c.closed ? [...c.pts, c.pts[0]] : c.pts, t = Math.max(0, Math.min(1, toNum(tt)));
      let goal = polyLen(P) * t;
      for (let i = 1; i < P.length; i++) {
        const seg = V.len(V.sub(P[i], P[i - 1]));
        if (goal <= seg || i === P.length - 1) {
          const f = Math.max(0, Math.min(1, goal / Math.max(seg, 1e-12)));
          return [pt(V.add(P[i - 1], V.mul(V.sub(P[i], P[i - 1]), f))), vec(V.unit(V.sub(P[i], P[i - 1]))), 0];
        }
        goal -= seg;
      }
      return [null, null, null];
    } },
    graft: { tree: ([t]) => [t.flatMap(b => b.items.map((it, i) => ({ path: [...b.path, i], items: [it] })))] },
    flatten: { tree: ([t]) => [[{ path: [0], items: t.flatMap(b => b.items) }]] },
    flipMatrix: { tree: ([t]) => { const n = Math.max(0, ...t.map(b => b.items.length)); return [G.range(n).map(i => ({ path: [i], items: t.map(b => b.items[i]).filter(x => x !== undefined) }))]; } },
  };
  const polyLen = (P) => P.reduce((a, p, i) => i ? a + V.len(V.sub(p, P[i - 1])) : 0, 0);
  const angleBetween = (a, b) => Math.acos(Math.max(-1, Math.min(1, V.dot(V.unit(a), V.unit(b)))));

  /* Round every corner of a polyline with arcs of radius R (shrunk where segments are too short). */
  function filletCurve(c, R) {
    const P = c.pts, n = P.length;
    if (R <= 1e-9 || n < 3) return c;
    const out = [];
    for (let i = 0; i < n; i++) {
      const p1 = P[i];
      if (!(c.closed || (i > 0 && i < n - 1))) { out.push(p1); continue; }
      const p0 = P[(i - 1 + n) % n], p2 = P[(i + 1) % n], u = V.sub(p0, p1), w = V.sub(p2, p1);
      if (V.len(u) < 1e-9 || V.len(w) < 1e-9) { out.push(p1); continue; }
      const ang = angleBetween(u, w);
      if (ang > Math.PI - 1e-3) { out.push(p1); continue; }
      const d = Math.min(R / Math.tan(ang / 2), Math.min(V.len(u), V.len(w)) / 2), r = d * Math.tan(ang / 2);
      const a0 = V.add(p1, V.mul(V.unit(u), d)), a1 = V.add(p1, V.mul(V.unit(w), d));
      const bis = V.unit(V.add(V.unit(u), V.unit(w))), C = V.add(p1, V.mul(bis, r / Math.sin(ang / 2)));
      let nrm = V.cross(V.sub(a0, C), V.sub(a1, C));
      if (V.len(nrm) < 1e-12) { out.push(p1); continue; }
      nrm = V.unit(nrm);
      const v0 = V.sub(a0, C), sweep = angleBetween(v0, V.sub(a1, C));
      for (let k = 0; k <= 8; k++) out.push(rotAxis(a0, C, nrm, sweep * k / 8));
    }
    return crv(out, c.closed);
  }

  /* Chain curves end to start into as few polylines as possible (Join Curves). */
  function joinCurves(cs) {
    const near = (a, b) => V.len(V.sub(a, b)) < 1e-4;
    const left = cs.map(c => c.pts.slice()), out = [];
    while (left.length) {
      let chain = left.shift(), grown = true;
      while (grown) {
        grown = false;
        for (let i = 0; i < left.length; i++) {
          const q = left[i], last = chain[chain.length - 1];
          if (near(last, q[0])) chain = chain.concat(q.slice(1));
          else if (near(last, q[q.length - 1])) chain = chain.concat(q.slice().reverse().slice(1));
          else if (near(chain[0], q[q.length - 1])) chain = q.concat(chain.slice(1));
          else if (near(chain[0], q[0])) chain = q.slice().reverse().concat(chain.slice(1));
          else continue;
          left.splice(i, 1); grown = true; break;
        }
      }
      const closed = chain.length > 2 && near(chain[0], chain[chain.length - 1]);
      if (closed) chain.pop();
      out.push(crv(chain, closed));
    }
    return out;
  }

  /* Split a curve into the pieces inside / outside closed planar regions (Trim with Region, in plan). */
  function inPoly(p, poly) {
    let inside = false;
    for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      const a = poly[i], b = poly[j];
      if ((a[1] > p[1]) !== (b[1] > p[1]) && p[0] < (b[0] - a[0]) * (p[1] - a[1]) / (b[1] - a[1]) + a[0]) inside = !inside;
    }
    return inside;
  }
  function simplifyPts(pts) {
    if (pts.length < 3) return pts;
    const out = [pts[0]];
    for (let i = 1; i < pts.length - 1; i++) if (V.dot(V.unit(V.sub(pts[i], out[out.length - 1])), V.unit(V.sub(pts[i + 1], pts[i]))) < 0.99999) out.push(pts[i]);
    out.push(pts[pts.length - 1]);
    return out;
  }
  function trimCurve(c, regions) {
    const src = c.closed ? [...c.pts, c.pts[0]] : c.pts;
    let dense = [];
    for (let i = 1; i < src.length; i++) {
      const a = src[i - 1], b = src[i], k = Math.max(1, Math.floor(V.len(V.sub(b, a)) / 0.05));
      for (let j = 0; j < k; j++) dense.push(V.add(a, V.mul(V.sub(b, a), j / k)));
    }
    dense.push(src[src.length - 1]);
    let flags = dense.map(p => regions.some(r => inPoly(p, r.pts)));
    if (c.closed) {   // start the runs at a change of side so the seam doesn't split a piece
      const start = flags.findIndex((f, i) => i > 0 && f !== flags[i - 1]);
      if (start > 0) {
        dense = dense.slice(start, dense.length - 1).concat(dense.slice(0, start + 1));
        flags = flags.slice(start, flags.length - 1).concat(flags.slice(0, start + 1));
      }
    }
    const inside = [], outside = [];
    let run = [dense[0]];
    for (let i = 1; i < dense.length; i++) {
      run.push(dense[i]);
      if (i === dense.length - 1 || flags[i] !== flags[i - 1]) {
        if (run.length > 1) (flags[i - 1] ? inside : outside).push(crv(simplifyPts(run)));
        run = [dense[i]];
      }
    }
    return [inside, outside];
  }

  /* ───── baked geometry (JSON) ───── */
  function parseBaked(b) {
    if (b == null || typeof b !== 'object') return b;
    if (b.point) return pt(b.point);
    if (b.vector) return vec(b.vector);
    if (b.curve) return crv(b.smooth ? G.spline(b.curve, 20) : b.curve, b.closed);
    return b;
  }

  /* ───── tree helpers ───── */
  const single = (v) => [{ path: [0], items: v && v.list ? v.list : Array.isArray(v) && !(v.length === 3 && typeof v[0] === 'number') && !(v.length === 2 && typeof v[0] === 'number') ? v : [v] }];
  const hasData = (t) => t && t.some(b => b.items.length);
  function mergeTrees(ts) {
    if (!ts.length) return null;
    if (ts.length === 1) return ts[0];
    const m = new Map();
    ts.forEach(t => t.forEach(b => { const k = b.path.join(';'); if (!m.has(k)) m.set(k, { path: b.path, items: [] }); m.get(k).items.push(...b.items); }));
    return [...m.values()];
  }
  const resolveSet = (v, ctx) => (typeof v === 'string' && v[0] === '$' ? ctx.params[v.slice(1)] : Array.isArray(v) ? v.map(x => resolveSet(x, ctx)) : v);

  function solveNode(node, comp, inTrees, ctx) {
    if (node.baked) { const arr = Array.isArray(node.baked) ? node.baked : [node.baked]; return comp.outs.map((_, i) => i === 0 ? [{ path: [0], items: arr.map(parseBaked) }] : []); }
    const sv = S[comp.id];
    if (!sv) return comp.outs.map(() => []);
    if (sv.tree) return inTrees[0] ? sv.tree(inTrees, node, ctx) : comp.outs.map(() => []);
    const def = sv.def || [], acc = sv.access || [];
    const set = node.set || {};
    const trees = comp.ins.map((p, i) => {
      if (hasData(inTrees[i])) return inTrees[i];
      const sk = set[p[0]] !== undefined ? p[0] : set[i] !== undefined ? i : null;
      if (sk !== null) return single(resolveSet(set[sk], ctx));
      if (def[i] !== undefined) return single(def[i]);
      return null; // required input missing
    });
    if (comp.ins.length && trees.some((t, i) => t === null && def[i] === undefined)) return comp.outs.map(() => []);
    // a wired input that delivers no data stops the component (as in Grasshopper)
    if (inTrees.some(t => t && !hasData(t))) return comp.outs.map(() => []);
    const nb = Math.max(1, ...trees.map(t => t.length));
    const pathSrc = trees.reduce((a, t) => (t.length > (a ? a.length : 0) ? t : a), null);
    const outs = comp.outs.map(() => []);
    for (let b = 0; b < nb; b++) {
      const br = trees.map(t => t[Math.min(b, t.length - 1)]);
      const path = pathSrc ? pathSrc[Math.min(b, pathSrc.length - 1)].path : [0];
      const itemIdx = br.map((_, i) => i).filter(i => acc[i] !== 'list');
      let n = itemIdx.length ? Math.max(...itemIdx.map(i => br[i].items.length)) : 1;
      if (itemIdx.some(i => !br[i].items.length)) n = 0;
      const res = [];
      for (let k = 0; k < n; k++) {
        const args = br.map((bb, i) => (acc[i] === 'list' ? bb.items : bb.items[Math.min(k, bb.items.length - 1)]));
        try { res.push(sv.fn(args, node, ctx)); } catch (e) { res.push(null); }
      }
      const toList = (v) => (v == null ? [] : v.list ? v.list.filter(x => x != null) : [v]);
      const listy = res.some(r => r && r.some(o => o && o.list));
      comp.outs.forEach((_, o) => {
        if (listy && n > 1) res.forEach((r, k) => outs[o].push({ path: [...path, k], items: r ? toList(r[o]) : [] }));
        else outs[o].push({ path, items: res.flatMap(r => (r ? toList(r[o]) : [])) });
      });
    }
    return outs;
  }

  /* Grasshopper's flatten / graft input modifiers (node.in_map: { port nick: "flatten" | "graft" }). */
  function mapInput(t, node, nick) {
    const m = node.in_map && node.in_map[nick];
    if (!m || !t) return t;
    if (m === 'flatten') return [{ path: [0], items: t.flatMap(b => b.items) }];
    return t.flatMap(b => b.items.map((it, i) => ({ path: [...b.path, i], items: [it] })));
  }

  /* level: normalised level; ctx: { placed(node), wireActive(wire), params } → { nodeId: [outTree, …] } */
  function evaluate(level, ctx) {
    const ids = level.nodes.map(n => n.id), indeg = Object.fromEntries(ids.map(i => [i, 0]));
    level.wires.forEach(w => indeg[w.to[0]]++);
    const q = ids.filter(i => !indeg[i]), order = [];
    while (q.length) { const id = q.shift(); order.push(id); level.wires.filter(w => w.from[0] === id).forEach(w => { if (--indeg[w.to[0]] === 0) q.push(w.to[0]); }); }
    const res = {};
    order.forEach(id => {
      const node = level.nodes.find(n => n.id === id), comp = COMPONENTS[node.comp];
      const inTrees = comp.ins.map((p, i) => mapInput(mergeTrees(level.wires
        .filter(w => w.to[0] === id && w.to[1] === i && ctx.wireActive(w) && res[w.from[0]] && res[w.from[0]][w.from[1]])
        .map(w => res[w.from[0]][w.from[1]])), node, p[0]));
      if (!ctx.placed(node)) { res[id] = node.passthrough && inTrees[0] ? [inTrees[0]] : null; return; }
      res[id] = solveNode(node, comp, inTrees, ctx);
    });
    return res;
  }

  /* Build a preview scene from evaluation results. A node previews when node.preview is true, or by default
   * when none of its outputs feed a placed node through an active wire (i.e. it is a current "leaf"). */
  const QUIET = new Set(['slider', 'panel', 'toggle']);
  function scene(level, res, ctx) {
    const s = { lines: [], points: [], labels: [], arrows: [] };
    let labelZ = 0;
    level.nodes.forEach(node => {
      const out = res[node.id]; if (!out || !ctx.placed(node)) return;
      const leaf = !level.wires.some(w => w.from[0] === node.id && ctx.wireActive(w) && ctx.placed(level.nodes.find(n => n.id === w.to[0])));
      if (!(node.preview != null ? node.preview : leaf)) return;
      const k = node.id, nums = [], isVecComp = COMPONENTS[node.comp].cat.startsWith('Vector');
      const srfCount = out.reduce((a, t) => a + t.reduce((b, br) => b + br.items.filter(x => x && x.t === 'srf').length, 0), 0);
      let doms = 0;
      out.forEach((tree, oi) => tree.forEach(b => b.items.forEach(it => {
        if (it == null) return;
        if (typeof it === 'number' || typeof it === 'boolean') { if (oi === 0) nums.push(it); return; }
        switch (it.t) {
          case 'pt': s.points.push({ p: it.p, k }); break;
          case 'vec': if (isVecComp) s.arrows.push({ from: [0, 0, 0], to: it.v, k }); break;
          case 'crv': s.lines.push({ pts: it.pts, closed: it.closed, k, w: it.w }); break;
          case 'srf': {
            s.lines.push({ pts: it.outline || it.c, closed: true, k });
            if (srfCount === 1) for (let i = 1; i < 4; i++) {
              s.lines.push({ pts: [srfPoint(it, i / 4, 0), srfPoint(it, i / 4, 1)], k, color: 'rgba(196,44,66,.28)', w: 0.8 });
              s.lines.push({ pts: [srfPoint(it, 0, i / 4), srfPoint(it, 1, i / 4)], k, color: 'rgba(196,44,66,.28)', w: 0.8 });
            }
            break;
          }
          case 'loft': {
            const ls = G.loft(it.sections.map(c => c.pts), it.sections[0].closed, k);
            if (it.sections.length === 2) for (let r = 1; r < 8; r++) { const f = r / 8; ls.push({ pts: it.sections[0].pts.map((p, i) => V.add(V.mul(p, 1 - f), V.mul(it.sections[1].pts[i], f))), closed: it.sections[0].closed, k, w: 0.8 }); }
            if (node.ghost) ls.forEach(l => { l.color = 'rgba(120,60,70,.22)'; l.k = null; l.w = 0.8; });
            s.lines.push(...ls); break;
          }
          case 'dom2': doms++; break;
        }
      })));
      const name = node.label || COMPONENTS[node.comp].name;
      if (nums.length && !QUIET.has(node.comp)) { s.labels.push({ p: [0, 0, labelZ], text: `${name}: ${G.list(nums)}`, k }); labelZ -= 1.2; }
      if (doms) { s.labels.push({ p: [0, 0, labelZ], text: `${name}: ${doms} sub-domains`, k }); labelZ -= 1.2; }
    });
    return s;
  }

  return { evaluate, scene, SOLVERS: S };
})();
