## A tiny Grasshopper-style solver, ported from web/js/engine.js.
##
## Evaluates a level's component graph the way Grasshopper does (simplified):
##  - data travels in trees: an Array of branches { path: [..], items: [..] }
##  - item inputs iterate with longest-list matching; list inputs receive the whole branch
##  - branches are matched one-to-one, re-using the last branch of the shorter tree
##  - unconnected inputs fall back to node.set values, then to the component defaults
##
## Geometry items: { t:'pt', p } { t:'vec', v } { t:'crv', pts, closed } { t:'pl', o, x, y, z }
##                 { t:'srf', c:[p00,p10,p11,p01] } { t:'loft', sections:[crv] } { t:'dom2', u0,u1,v0,v1 }
## Points are Vector3. A list result is { list: [...] }. Raw numeric arrays from
## level.json ([x,y,z] points, [a,b] domains) stay as Arrays, as in JS.
class_name GHEngine
extends RefCounted

## Stands in for JS `undefined` in default lists: the input is required.
const U := &"__undefined__"


# ───── constructors ─────
static func pt(p: Vector3) -> Dictionary: return {"t": "pt", "p": p}
static func vec(v: Vector3) -> Dictionary: return {"t": "vec", "v": v}
static func crv(pts: Array, closed := false) -> Dictionary: return {"t": "crv", "pts": pts, "closed": closed}
static func L(arr: Array) -> Dictionary: return {"list": arr}

static func plane(o: Vector3, x: Vector3, y: Vector3) -> Dictionary:
	return {"t": "pl", "o": o, "x": _unit(x), "y": _unit(y), "z": _unit(x.cross(y))}

static func plane_named(name: String) -> Dictionary:
	match name.to_upper():
		"XZ": return plane(Vector3.ZERO, Vector3(1, 0, 0), Vector3(0, 0, 1))
		"YZ": return plane(Vector3.ZERO, Vector3(0, 1, 0), Vector3(0, 0, 1))
	return plane(Vector3.ZERO, Vector3(1, 0, 0), Vector3(0, 1, 0))

static func _unit(a: Vector3) -> Vector3:
	var l := a.length()
	return a / (l if l != 0.0 else 1.0)


# ───── type checks / coercion (Grasshopper auto-converts between types) ─────
static func is_geo(v: Variant, t: String) -> bool:
	return v is Dictionary and v.get("t") == t

static func is_list(v: Variant) -> bool:
	return v is Dictionary and v.has("list")

static func _num_array(v: Variant, n: int) -> bool:
	if not (v is Array) or v.size() != n:
		return false
	return v[0] is float or v[0] is int

static func _arr3(v: Array) -> Vector3:
	return Vector3(to_num(v[0]), to_num(v[1]), to_num(v[2])) if v.size() >= 3 else Vector3.ZERO

static func to_point(v: Variant) -> Vector3:
	if v == null: return Vector3.ZERO
	if v is Vector3: return v
	if v is Array: return _arr3(v)
	if v is Dictionary:
		match v.get("t"):
			"pt": return v.p
			"pl": return v.o
			"vec": return v.v
	return Vector3.ZERO

static func to_vec(v: Variant) -> Vector3:
	if v == null: return Vector3.ZERO
	if v is float or v is int: return Vector3(0, 0, float(v))
	if v is Vector3: return v
	if v is Array: return _arr3(v)
	if v is Dictionary:
		match v.get("t"):
			"vec": return v.v
			"pt": return v.p
	return Vector3.ZERO

static func to_num(v: Variant) -> float:
	if v is float or v is int: return float(v)
	if v is bool: return 1.0 if v else 0.0
	if is_geo(v, "vec"): return (v.v as Vector3).length()
	if v is String and v.is_valid_float(): return v.to_float()
	return 0.0

static func to_domain(v: Variant) -> Array:
	return v if _num_array(v, 2) else [0.0, to_num(v)]

static func to_plane(v: Variant) -> Dictionary:
	if v == null: return plane_named("XY")
	if v is String or v is StringName: return plane_named(str(v))
	if is_geo(v, "pl"): return v
	var p := plane_named("XY")
	p.o = to_point(v)
	return p

static func truthy(v: Variant) -> bool:
	if v == null: return false
	if v is bool: return v
	if v is float or v is int: return v != 0
	if v is String: return not v.is_empty()
	return true

static func _on_plane(pl: Dictionary, u: float, w: float) -> Vector3:
	return pl.o + pl.x * u + pl.y * w


static func map_geo(g: Variant, f: Callable) -> Variant:
	if not (g is Dictionary):
		return g
	match g.get("t"):
		"pt": return pt(f.call(g.p))
		"crv":
			var c: Dictionary = g.duplicate()
			c.pts = g.pts.map(f)
			return c
		"srf":
			var s: Dictionary = g.duplicate()
			s.c = g.c.map(f)
			if g.has("outline"):
				s.outline = g.outline.map(f)
			return s
		"loft":
			var lf: Dictionary = g.duplicate()
			lf.sections = g.sections.map(func(sec): return map_geo(sec, f))
			return lf
		"pl":
			var o: Vector3 = f.call(g.o)
			return plane(o, (f.call(g.o + g.x) as Vector3) - o, (f.call(g.o + g.y) as Vector3) - o)
	return g


static func geo_points(g: Dictionary) -> Array:
	match g.get("t"):
		"pt": return [g.p]
		"crv": return g.pts
		"srf": return g.c
		"loft":
			var out := []
			for s in g.sections:
				out.append_array(geo_points(s))
			return out
	return []


static func rot_axis(p: Vector3, o: Vector3, axis: Vector3, a: float) -> Vector3:
	var k := _unit(axis)
	var r := p - o
	var c := cos(a)
	var s := sin(a)
	return o + r * c + k.cross(r) * s + k * (k.dot(r) * (1.0 - c))


## Point on a loft: u runs along the sections (by vertex index), w across them.
static func loft_point(l: Dictionary, u: float, w: float) -> Vector3:
	var S: Array = l.sections
	var m: int = S[0].pts.size()
	var closed: bool = S[0].closed
	var ring := []
	for c in S:
		var x: float = u * (m if closed else m - 1)
		var i := int(floorf(x)) % m
		var j := (i + 1) % m if closed else mini(i + 1, m - 1)
		var f := x - floorf(x)
		ring.append((c.pts[i] as Vector3).lerp(c.pts[j], f))
	var y := w * (ring.size() - 1)
	var a := mini(int(floorf(y)), ring.size() - 2)
	return (ring[a] as Vector3).lerp(ring[a + 1], y - a)


## Horizontal section of a loft at height z (rails treated as polylines between sections).
static func loft_ring(l: Dictionary, z: float) -> Array:
	var S: Array = l.sections
	var m: int = S[0].pts.size()
	var out := []
	for i in m:
		var hit = null
		for j in S.size() - 1:
			var a: Vector3 = S[j].pts[i]
			var b: Vector3 = S[j + 1].pts[i]
			if (z - a.z) * (z - b.z) <= 0 and a.z != b.z:
				hit = a.lerp(b, (z - a.z) / (b.z - a.z))
				break
		if hit == null:
			hit = S[0].pts[i] if z < (S[0].pts[i] as Vector3).z else S[S.size() - 1].pts[i]
		out.append(hit)
	return out


static func srf_point(s: Dictionary, u: float, w: float) -> Vector3:
	var a: Vector3 = s.c[0]
	var b: Vector3 = s.c[1]
	var c: Vector3 = s.c[2]
	var d: Vector3 = s.c[3]
	var p := a * (1.0 - u) + b * u
	var q := d * (1.0 - u) + c * u
	return p * (1.0 - w) + q * w


static func poly_len(P: Array) -> float:
	var t := 0.0
	for i in range(1, P.size()):
		t += (P[i] as Vector3).distance_to(P[i - 1])
	return t


static func _irange(n: int) -> Array:
	var a := []
	for i in maxi(0, n):
		a.append(i)
	return a


# ───── component solvers ─────
## Each entry: { def: [...] defaults per input (U = required), access: ["list", ...], fn: Callable(args, node, ctx) -> Array }
## or { tree: Callable(in_trees, node, ctx) -> Array of trees }.
static var _solvers: Dictionary = {}

static func solvers() -> Dictionary:
	if _solvers.is_empty():
		_build_solvers()
	return _solvers


static func _build_solvers() -> void:
	var S := {}
	S.slider = {"fn": func(_a, n, ctx): return [ctx.params.get(n.param, 5.0) if n.get("param") != null else n.get("value", 5.0)]}
	S.panel = {"def": [null], "fn": func(_a, n, _c): return [L(n.get("values", []).duplicate())]}
	S.toggle = {"fn": func(_a, n, _c): return [n.get("value", true)]}
	S.pointParam = {"fn": func(_a, _n, _c): return [null]}
	S.curveParam = {"fn": func(_a, _n, _c): return [null]}
	S.xyPlane = {"def": [[0.0, 0.0, 0.0]], "fn": func(a, _n, _c):
		var p := plane_named("XY")
		p.o = to_point(a[0])
		return [p]}
	S.constructPoint = {"def": [0.0, 0.0, 0.0], "fn": func(a, _n, _c): return [pt(Vector3(to_num(a[0]), to_num(a[1]), to_num(a[2])))]}
	S.unitZ = {"def": [1.0], "fn": func(a, _n, _c): return [vec(Vector3(0, 0, to_num(a[0])))]}
	S.unitX = {"def": [1.0], "fn": func(a, _n, _c): return [vec(Vector3(to_num(a[0]), 0, 0))]}
	S.vector2pt = {"def": [U, U, false], "fn": func(a, _n, _c):
		var d := to_point(a[1]) - to_point(a[0])
		var l := d.length()
		if truthy(a[2]):
			d = _unit(d)
		return [vec(d), l]}
	S.amplitude = {"def": [U, 1.0], "fn": func(a, _n, _c): return [vec(_unit(to_vec(a[0])) * to_num(a[1]))]}
	S.line = {"fn": func(a, _n, _c): return [crv([to_point(a[0]), to_point(a[1])])]}
	S.lineSDL = {"def": [[0.0, 0.0, 0.0], vec(Vector3(1, 0, 0)), 1.0], "fn": func(a, _n, _c):
		var p := to_point(a[0])
		return [crv([p, p + _unit(to_vec(a[1])) * to_num(a[2])])]}
	S.circle = {"def": [null, 1.0], "fn": func(a, _n, _c):
		var pl := to_plane(a[0])
		var R := to_num(a[1])
		var pts := []
		for i in 64:
			var t := float(i) / 64.0 * TAU
			pts.append(_on_plane(pl, R * cos(t), R * sin(t)))
		return [crv(pts, true)]}
	S.rectangle = {"def": [null, 1.0, 1.0, 0.0], "fn": func(a, _n, _c):
		var pl := to_plane(a[0])
		var X := to_domain(a[1])
		var Y := to_domain(a[2])
		var pts := []
		for uw in [[X[0], Y[0]], [X[1], Y[0]], [X[1], Y[1]], [X[0], Y[1]]]:
			pts.append(_on_plane(pl, to_num(uw[0]), to_num(uw[1])))
		return [crv(pts, true), 2.0 * (absf(to_num(X[1]) - to_num(X[0])) + absf(to_num(Y[1]) - to_num(Y[0])))]}
	S.polygon = {"def": [null, 1.0, 6.0, 0.0], "fn": func(a, _n, _c):
		var pl := to_plane(a[0])
		var R := to_num(a[1])
		var n := maxi(3, roundi(to_num(a[2])))
		var F := maxf(0.0, to_num(a[3]))
		var half := PI / n
		var edge := 2.0 * R * sin(half)
		var inner := PI - 2.0 * half
		var tdist := minf(F / tan(inner / 2.0), edge / 2.0)
		var fr := tdist * tan(inner / 2.0)
		var pts := []
		for i in n:
			var t := float(i) / n * TAU
			if fr < 1e-6:
				pts.append(_on_plane(pl, R * cos(t), R * sin(t)))
				continue
			# fillet arc: centre on the bisector, sweeping the corner's exterior angle
			var cd := R - fr / sin(inner / 2.0)
			var cx := cd * cos(t)
			var cy := cd * sin(t)
			for k in 7:
				var ang := t - half + (2.0 * half) * k / 6.0
				pts.append(_on_plane(pl, cx + fr * cos(ang), cy + fr * sin(ang)))
		return [crv(pts, true), poly_len(pts + [pts[0]])]}
	S.interpolate = {"access": ["list"], "def": [U, 3.0, false, 0.0], "fn": func(a, _n, _c):
		var pts: Array = a[0].map(func(v): return to_point(v))
		if pts.size() < 2:
			return [null, null, null]
		var c := crv(Geo.spline(pts, 10))
		return [c, poly_len(c.pts), [0.0, 1.0]]}
	S.divideCurve = {"def": [U, 10.0, false], "fn": func(a, _n, _c):
		var c = a[0]
		if not is_geo(c, "crv"):
			return [null, null, null]
		var N := maxi(1, roundi(to_num(a[1])))
		var P := Geo.divide(c.pts, N, c.closed)
		var T := []
		for i in P.size():
			T.append(vec(_unit((P[mini(i + 1, P.size() - 1)] as Vector3) - P[maxi(i - 1, 0)])))
		var pts := []
		var prm := []
		for i in P.size():
			pts.append(pt(P[i]))
			prm.append(float(i) / N)
		return [L(pts), L(T), L(prm)]}
	S.loft = {"access": ["list"], "def": [U, null], "fn": func(a, _n, _c):
		var secs: Array = a[0].filter(func(c): return is_geo(c, "crv"))
		if secs.size() < 2:
			return [null]
		var cnt := 0
		for c in secs:
			cnt = maxi(cnt, c.pts.size())
		var same := secs.all(func(c): return c.pts.size() == cnt)
		if not same:
			secs = secs.map(func(c): return crv(Geo.divide(c.pts, 24, c.closed), c.closed))
		return [{"t": "loft", "sections": secs}]}
	S.extrude = {"def": [U, vec(Vector3(0, 0, 1))], "fn": func(a, _n, _c):
		var b = a[0]
		if not is_geo(b, "crv"):
			return [null]
		var d := to_vec(a[1])
		return [{"t": "loft", "sections": [b, map_geo(b, func(p): return p + d)]}]}
	S.pipe = {"def": [U, 1.0, null], "fn": func(a, _n, _c):
		var c = a[0]
		if not is_geo(c, "crv"):
			return [null]
		var o: Dictionary = c.duplicate()
		o.w = 4.0
		return [o]}
	S.boundary = {"fn": func(a, _n, _c):
		var e = a[0]
		if not is_geo(e, "crv") or not e.closed:
			return [null]
		var p: Array = e.pts
		if p.size() == 4:
			return [{"t": "srf", "c": p.duplicate()}]
		return [{"t": "srf", "c": [p[0], p[1], p[2], p[3] if p.size() > 3 else p[2]], "outline": p}]}
	S.divDomain2 = {"def": [U, 10.0, 10.0], "fn": func(a, _n, _c):
		var Uc := maxi(1, roundi(to_num(a[1])))
		var W := maxi(1, roundi(to_num(a[2])))
		var out := []
		for j in W:
			for i in Uc:
				out.append({"t": "dom2", "u0": float(i) / Uc, "u1": float(i + 1) / Uc, "v0": float(j) / W, "v1": float(j + 1) / W})
		return [L(out)]}
	S.isotrim = {"fn": func(a, _n, _c):
		var s = a[0]
		var d = a[1]
		if not (is_geo(s, "srf") or is_geo(s, "loft")) or not is_geo(d, "dom2"):
			return [null]
		var f := loft_point if is_geo(s, "loft") else srf_point
		return [{"t": "srf", "c": [f.call(s, d.u0, d.v0), f.call(s, d.u1, d.v0), f.call(s, d.u1, d.v1), f.call(s, d.u0, d.v1)]}]}
	S.capHoles = {"fn": func(a, _n, _c):
		var b = a[0]
		if is_geo(b, "loft"):
			var o: Dictionary = b.duplicate()
			o.capped = true
			return [o]
		return [b]}
	S.contour = {"def": [U, [0.0, 0.0, 0.0], vec(Vector3(0, 0, 1)), 1.0], "fn": func(a, _n, _c):
		var g = a[0]
		if not is_geo(g, "loft"):
			return [L([])]
		var D := maxf(0.05, to_num(a[3]))
		var P := geo_points(g)
		var z0: float = P.map(func(q): return q.z).min()
		var z1: float = P.map(func(q): return q.z).max()
		var base := to_point(a[1]).z
		var out := []
		var z: float = base + ceilf((z0 - base) / D - 1e-9) * D
		while z <= z1 + 1e-9 and out.size() < 400:
			out.append(crv(loft_ring(g, z), true))
			z += D
		return [L(out)]}
	S.area = {"fn": func(a, _n, _c):
		var g = a[0]
		if not (g is Dictionary):
			return [null, null]
		var P := geo_points(g)
		if P.is_empty():
			return [null, null]
		var c := Vector3.ZERO
		for p in P:
			c += p
		c /= P.size()
		var A := 0.0
		for i in P.size():
			A += ((P[i] as Vector3) - c).cross((P[(i + 1) % P.size()] as Vector3) - c).length() / 2.0
		return [A, pt(c)]}
	S.series = {"def": [0.0, 1.0, 10.0], "fn": func(a, _n, _c):
		var s := to_num(a[0])
		var st := to_num(a[1])
		return [L(_irange(roundi(to_num(a[2]))).map(func(i): return s + i * st))]}
	S.range = {"def": [[0.0, 1.0], 10.0], "fn": func(a, _n, _c):
		var D := to_domain(a[0])
		var N := maxi(1, roundi(to_num(a[1])))
		var d0 := to_num(D[0])
		var d1 := to_num(D[1])
		return [L(_irange(N + 1).map(func(i): return d0 + (d1 - d0) * i / N))]}
	S.cullPattern = {"access": ["list", "list"], "fn": func(a, _n, _c):
		var l: Array = a[0]
		var p: Array = a[1]
		if p.is_empty():
			return [L(l.duplicate())]
		var out := []
		for i in l.size():
			if truthy(p[i % p.size()]):
				out.append(l[i])
		return [L(out)]}
	S.listItem = {"access": ["list"], "def": [U, 0.0, true], "fn": func(a, _n, _c):
		var l: Array = a[0]
		if l.is_empty():
			return [null]
		var n := l.size()
		return [l[((roundi(to_num(a[1])) % n) + n) % n]]}
	S.reverseList = {"access": ["list"], "fn": func(a, _n, _c):
		var l: Array = a[0].duplicate()
		l.reverse()
		return [L(l)]}
	S.sortList = {"access": ["list", "list"], "fn": func(a, _n, _c):
		var k: Array = a[0]
		var v: Array = a[1]
		var idx := _irange(k.size())
		# stable sort by key value, like JS Array.sort
		idx.sort_custom(func(x, y):
			var dx := to_num(k[x])
			var dy := to_num(k[y])
			return dx < dy or (dx == dy and x < y))
		return [L(idx.map(func(i): return k[i])), L(idx.map(func(i): return v[i] if i < v.size() else null))]}
	S.shiftList = {"access": ["list"], "def": [U, 1.0, true], "fn": func(a, _n, _c):
		var l: Array = a[0]
		var n := l.size()
		if n == 0:
			return [L([])]
		var k := roundi(to_num(a[1]))
		var out := []
		for i in n:
			if truthy(a[2]):
				out.append(l[(((i + k) % n) + n) % n])
			elif i + k >= 0 and i + k < n:
				out.append(l[i + k])   # no wrap: items shifted off the end are dropped
		return [L(out)]}
	S.move = {"def": [U, vec(Vector3(0, 0, 10))], "fn": func(a, _n, _c):
		var d := to_vec(a[1])
		return [map_geo(a[0], func(p): return p + d), null]}
	S.rotate = {"def": [U, PI / 2.0, null], "fn": func(a, n, _c):
		var pl := to_plane(a[2])
		var ang := to_num(a[1]) * (PI / 180.0 if n.get("degrees", false) else 1.0)
		return [map_geo(a[0], func(q): return rot_axis(q, pl.o, pl.z, ang)), null]}
	S.scale = {"def": [U, [0.0, 0.0, 0.0], 0.5], "fn": func(a, _n, _c):
		var o := to_point(a[1])
		var k := to_num(a[2])
		return [map_geo(a[0], func(q): return o + (q - o) * k), null]}
	S.mirror = {"def": [U, "YZ"], "fn": func(a, _n, _c):
		var pl := to_plane(a[1])
		var z: Vector3 = pl.z
		var o: Vector3 = pl.o
		return [map_geo(a[0], func(q): return q - z * (2.0 * (q - o).dot(z))), null]}
	S.sine = {"fn": func(a, _n, _c): return [sin(to_num(a[0]))]}
	S.multiplication = {"def": [1.0, 1.0], "fn": func(a, _n, _c):
		if is_geo(a[0], "vec"):
			return [vec(a[0].v * to_num(a[1]))]
		return [to_num(a[0]) * to_num(a[1])]}
	S.addition = {"def": [0.0, 0.0], "fn": func(a, _n, _c): return [to_num(a[0]) + to_num(a[1])]}
	S.radians = {"fn": func(a, _n, _c): return [to_num(a[0]) * PI / 180.0]}
	S.remap = {"def": [U, [0.0, 1.0], [0.0, 1.0]], "fn": func(a, _n, _c):
		var A := to_domain(a[1])
		var B := to_domain(a[2])
		var a0 := to_num(A[0])
		var span := to_num(A[1]) - a0
		var x := (to_num(a[0]) - a0) / (span if span != 0.0 else 1.0)
		var b0 := to_num(B[0])
		var b1 := to_num(B[1])
		return [b0 + x * (b1 - b0), b0 + clampf(x, 0.0, 1.0) * (b1 - b0)]}
	# Graph Mapper: node.graph = { type: 'linear'|'pinch'|'sine'|'bell', param?: '<slider key>' }
	S.graphMapper = {"access": ["list"], "fn": func(a, n, ctx):
		var nums: Array = a[0].map(func(x): return to_num(x))
		if nums.is_empty():
			return [L([])]
		var lo: float = nums.min()
		var hi: float = nums.max()
		var g: Dictionary = n.get("graph", {"type": "linear"})
		var k: float = to_num(ctx.params.get(g.param, 0.5)) if g.get("param") != null else to_num(g.get("k", 0.5))
		var out := []
		for x in nums:
			var t: float = (x - lo) / (hi - lo) if hi > lo else 0.0
			var y: float = t
			match g.get("type", "linear"):
				"pinch": y = 1.0 - k * sin(PI * t)
				"sine": y = 0.5 + 0.5 * sin(TAU * t)
				"bell": y = exp(-pow((t - 0.5) / (0.2 + k * 0.3), 2.0))
			out.append(y)
		return [L(out)]}
	S.graft = {"tree": func(t, _n, _c):
		var out := []
		for b in t[0]:
			for i in b.items.size():
				out.append({"path": b.path + [i], "items": [b.items[i]]})
		return [out]}
	S.flatten = {"tree": func(t, _n, _c):
		var items := []
		for b in t[0]:
			items.append_array(b.items)
		return [[{"path": [0], "items": items}]]}
	S.flipMatrix = {"tree": func(t, _n, _c):
		var n := 0
		for b in t[0]:
			n = maxi(n, b.items.size())
		var out := []
		for i in n:
			var items := []
			for b in t[0]:
				if i < b.items.size():
					items.append(b.items[i])
			out.append({"path": [i], "items": items})
		return [out]}
	_build_godot_solvers(S)
	_solvers = S


# ───── components used by the .ghx levels (Godot only, tools/ghx_to_level.py) ─────
static func _build_godot_solvers(S: Dictionary) -> void:
	# floating parameters pass their input through (unwired, they hold nothing)
	for id in ["pointParam", "curveParam", "dataParam"]:
		S[id] = {"fn": func(a, _n, _c): return [a[0]]}
	S.unitY = {"def": [1.0], "fn": func(a, _n, _c): return [vec(Vector3(0, to_num(a[0]), 0))]}
	S.division = {"def": [1.0, 1.0], "fn": func(a, _n, _c):
		var b := to_num(a[1])
		return [to_num(a[0]) / b if absf(b) > 1e-12 else null]}
	S.negative = {"fn": func(a, _n, _c): return [-to_num(a[0])]}
	S.circleCNR = {"def": [[0.0, 0.0, 0.0], vec(Vector3(0, 0, 1)), 1.0], "fn": func(a, _n, _c):
		var o := to_point(a[0])
		var z := _unit(to_vec(a[1]))
		var x := _unit(z.cross(Vector3(0, 1, 0) if absf(z.y) < 0.9 else Vector3(1, 0, 0)).cross(z))
		var pl := {"t": "pl", "o": o, "x": x, "y": z.cross(x), "z": z}
		var R := to_num(a[2])
		var pts := []
		for i in 64:
			var t := float(i) / 64.0 * TAU
			pts.append(_on_plane(pl, R * cos(t), R * sin(t)))
		return [crv(pts, true)]}
	S.endPoints = {"fn": func(a, _n, _c):
		var c = a[0]
		if not is_geo(c, "crv") or c.pts.is_empty():
			return [null, null]
		return [pt(c.pts[0]), pt(c.pts[0] if c.closed else c.pts[-1])]}
	S.polyline = {"access": ["list"], "def": [U, false], "fn": func(a, _n, _c):
		var pts: Array = a[0].map(func(v): return to_point(v))
		if pts.size() < 2:
			return [null]
		var closed := truthy(a[1])
		if closed and pts[0].distance_to(pts[-1]) < 1e-9:
			pts.pop_back()
		return [crv(pts, closed)]}
	S.fillet = {"def": [U, 1.0], "fn": func(a, _n, _c):
		if not is_geo(a[0], "crv"):
			return [null]
		return [_fillet_curve(a[0], to_num(a[1]))]}
	# Fillet (t): fillets at the given parameters; the .ghx levels feed it every corner, so fillet them all
	S.filletCtR = {"access": ["item", "list"], "def": [U, [], 1.0], "fn": func(a, _n, _c):
		if not is_geo(a[0], "crv"):
			return [null, null]
		return [_fillet_curve(a[0], to_num(a[2])), null]}
	S.discontinuity = {"def": [U, 1.0], "fn": func(a, _n, _c):
		var c = a[0]
		if not is_geo(c, "crv"):
			return [null, null]
		var P := []
		var T := []
		var n: int = c.pts.size()
		for i in n:
			if not c.closed and (i == 0 or i == n - 1):
				continue
			var p0: Vector3 = c.pts[(i - 1 + n) % n]
			var p1: Vector3 = c.pts[i]
			var p2: Vector3 = c.pts[(i + 1) % n]
			if (p1 - p0).length() > 1e-9 and (p2 - p1).length() > 1e-9 and _unit(p1 - p0).dot(_unit(p2 - p1)) < 0.999:
				P.append(pt(p1))
				T.append(float(i))
		return [L(P), L(T)]}
	S.joinCurves = {"access": ["list"], "def": [U, false], "fn": func(a, _n, _c):
		var cs: Array = a[0].filter(func(c): return is_geo(c, "crv") and c.pts.size() > 1)
		if cs.is_empty():
			return [null]
		return [L(_join(cs))]}
	S.merge = {"tree": func(t, _n, _c):
		return [merge_trees(t.filter(func(x): return x != null and has_data(x)))]}
	S.trimWithRegion = {"access": ["item", "list"], "def": [U, U, null], "fn": func(a, _n, _c):
		var c = a[0]
		var regions: Array = a[1].filter(func(r): return is_geo(r, "crv") and r.closed)
		if not is_geo(c, "crv") or regions.is_empty():
			return [null, null]
		var parts := _trim(c, regions)
		return [L(parts[0]), L(parts[1])]}
	S.arcSED = {"fn": func(a, _n, _c):
		var S0 := to_point(a[0])
		var E := to_point(a[1])
		var D := _unit(to_vec(a[2]))
		var ch := E - S0
		var nrm := D.cross(ch)
		if nrm.length() < 1e-9:
			return [crv([S0, E]), null, null]
		nrm = nrm.normalized()
		var perp := nrm.cross(D).normalized()
		var r := ch.length_squared() / (2.0 * ch.dot(perp))
		var C := S0 + perp * r
		var v0 := S0 - C
		var v1 := E - C
		var sweep := atan2(v0.cross(v1).dot(nrm), v0.dot(v1))
		if sweep < 0:
			sweep += TAU
		var pts := []
		var steps := maxi(4, int(sweep / TAU * 64.0))
		for i in steps + 1:
			pts.append(C + v0.rotated(nrm, sweep * i / steps))
		return [crv(pts), null, absf(r)]}
	S.evaluateCurve = {"def": [U, 0.0], "fn": func(a, _n, _c):
		var c = a[0]
		if not is_geo(c, "crv") or c.pts.size() < 2:
			return [null, null, null]
		var pts: Array = c.pts + [c.pts[0]] if c.closed else c.pts
		var t := clampf(to_num(a[1]), 0.0, 1.0)
		var goal := poly_len(pts) * t
		for i in range(1, pts.size()):
			var seg: float = (pts[i] as Vector3).distance_to(pts[i - 1])
			if goal <= seg or i == pts.size() - 1:
				var p: Vector3 = (pts[i - 1] as Vector3).lerp(pts[i], clampf(goal / maxf(seg, 1e-12), 0, 1))
				return [pt(p), vec(_unit(pts[i] - pts[i - 1])), 0.0]
			goal -= seg
		return [null, null, null]}


## Round every corner of a polyline with arcs of radius R (shrunk where segments are too short).
static func _fillet_curve(c: Dictionary, R: float) -> Dictionary:
	var P: Array = c.pts.duplicate()
	var n := P.size()
	if R <= 1e-9 or n < 3:
		return c
	var out := []
	for i in n:
		var corner: bool = c.closed or (i > 0 and i < n - 1)
		var p1: Vector3 = P[i]
		if not corner:
			out.append(p1)
			continue
		var p0: Vector3 = P[(i - 1 + n) % n]
		var p2: Vector3 = P[(i + 1) % n]
		var u := p0 - p1
		var w := p2 - p1
		if u.length() < 1e-9 or w.length() < 1e-9:
			out.append(p1)
			continue
		var ang := u.angle_to(w)
		if ang > PI - 1e-3:
			out.append(p1)
			continue
		var d := minf(R / tan(ang / 2.0), minf(u.length(), w.length()) / 2.0)
		var r := d * tan(ang / 2.0)
		var a0 := p1 + u.normalized() * d
		var a1 := p1 + w.normalized() * d
		var bis := (u.normalized() + w.normalized()).normalized()
		var C := p1 + bis * (r / sin(ang / 2.0))
		var nrm := (a0 - C).cross(a1 - C)
		if nrm.length() < 1e-12:
			out.append(p1)
			continue
		nrm = nrm.normalized()
		var v0 := a0 - C
		var sweep := v0.angle_to(a1 - C)
		for k in 9:
			out.append(C + v0.rotated(nrm, sweep * k / 8.0))
	return crv(out, c.closed)


## Chain curves end to start into as few polylines as possible (Join Curves).
static func _join(cs: Array) -> Array:
	var left := cs.map(func(c): return c.pts.duplicate())
	var out := []
	while not left.is_empty():
		var chain: Array = left.pop_front()
		var grown := true
		while grown:
			grown = false
			for i in left.size():
				var q: Array = left[i]
				if (chain[-1] as Vector3).distance_to(q[0]) < 1e-4:
					chain += q.slice(1)
				elif (chain[-1] as Vector3).distance_to(q[-1]) < 1e-4:
					var r := q.duplicate()
					r.reverse()
					chain += r.slice(1)
				elif (chain[0] as Vector3).distance_to(q[-1]) < 1e-4:
					chain = q + chain.slice(1)
				elif (chain[0] as Vector3).distance_to(q[0]) < 1e-4:
					var r2 := q.duplicate()
					r2.reverse()
					chain = r2 + chain.slice(1)
				else:
					continue
				left.remove_at(i)
				grown = true
				break
		var closed: bool = chain.size() > 2 and (chain[0] as Vector3).distance_to(chain[-1]) < 1e-4
		if closed:
			chain.pop_back()
		out.append(crv(chain, closed))
	return out


static func _in_regions(p: Vector3, regions: Array) -> bool:
	for r in regions:
		var poly := PackedVector2Array()
		for q in r.pts:
			poly.append(Vector2(q.x, q.y))
		if Geometry2D.is_point_in_polygon(Vector2(p.x, p.y), poly):
			return true
	return false


## Split a curve into the pieces inside / outside closed planar regions (Trim with Region, in plan).
static func _trim(c: Dictionary, regions: Array) -> Array:
	var src: Array = c.pts + [c.pts[0]] if c.closed else c.pts
	var dense := []
	for i in range(1, src.size()):
		var a: Vector3 = src[i - 1]
		var b: Vector3 = src[i]
		var k := maxi(1, int(a.distance_to(b) / 0.05))
		for j in k:
			dense.append(a.lerp(b, float(j) / k))
	dense.append(src[-1])
	var flags := dense.map(func(p): return _in_regions(p, regions))
	# a closed curve starts its runs at a change of side, so the seam doesn't split a piece
	if c.closed:
		var start := -1
		for i in range(1, flags.size()):
			if flags[i] != flags[i - 1]:
				start = i
				break
		if start > 0:
			dense = dense.slice(start, dense.size() - 1) + dense.slice(0, start + 1)
			flags = flags.slice(start, flags.size() - 1) + flags.slice(0, start + 1)
	var inside := []
	var outside := []
	var run := [dense[0]]
	for i in range(1, dense.size()):
		run.append(dense[i])
		if i == dense.size() - 1 or flags[i] != flags[i - 1]:
			if run.size() > 1:
				(inside if flags[i - 1] else outside).append(crv(_simplify(run)))
			run = [dense[i]]
	return [inside, outside]


static func _simplify(pts: Array) -> Array:
	if pts.size() < 3:
		return pts
	var out := [pts[0]]
	for i in range(1, pts.size() - 1):
		var d0 := _unit(pts[i] - out[-1])
		var d1 := _unit(pts[i + 1] - pts[i])
		if d0.dot(d1) < 0.99999:
			out.append(pts[i])
	out.append(pts[-1])
	return out


# ───── baked geometry (JSON) ─────
static func parse_baked(b: Variant) -> Variant:
	if not (b is Dictionary):
		return b
	if b.has("point"): return pt(_arr3(b.point))
	if b.has("vector"): return vec(_arr3(b.vector))
	if b.has("curve"):
		var pts: Array = b.curve.map(func(p): return _arr3(p))
		return crv(Geo.spline(pts, 20) if b.get("smooth", false) else pts, b.get("closed", false))
	return b


# ───── tree helpers ─────
static func single(v: Variant) -> Array:
	var items: Array
	if is_list(v):
		items = v.list
	elif v is Array and not _num_array(v, 3) and not _num_array(v, 2):
		items = v
	else:
		items = [v]
	return [{"path": [0], "items": items}]


static func has_data(t: Variant) -> bool:
	if not (t is Array):
		return false
	for b in t:
		if not b.items.is_empty():
			return true
	return false


static func merge_trees(ts: Array) -> Variant:
	if ts.is_empty():
		return null
	if ts.size() == 1:
		return ts[0]
	var m := {}
	var order := []
	for t in ts:
		for b in t:
			var k := ";".join(b.path.map(func(x): return str(x)))
			if not m.has(k):
				m[k] = {"path": b.path, "items": []}
				order.append(k)
			m[k].items.append_array(b.items)
	return order.map(func(k): return m[k])


static func resolve_set(v: Variant, ctx: Dictionary) -> Variant:
	if v is String and v.begins_with("$"):
		return ctx.params.get(v.substr(1), 0.0)
	if v is Array:
		return v.map(func(x): return resolve_set(x, ctx))
	return v


static func _to_list(v: Variant) -> Array:
	if v == null:
		return []
	if is_list(v):
		return v.list.filter(func(x): return x != null)
	return [v]


static func _empty_outs(comp: Dictionary) -> Array:
	return comp.outs.map(func(_o): return [])


static func solve_node(node: Dictionary, comp: Dictionary, in_trees: Array, ctx: Dictionary) -> Array:
	if node.has("baked"):
		var arr: Array = node.baked if node.baked is Array else [node.baked]
		var outs := []
		for i in comp.outs.size():
			outs.append([{"path": [0], "items": arr.map(func(b): return parse_baked(b))}] if i == 0 else [])
		return outs
	var sv: Dictionary = solvers().get(comp.id, {})
	if sv.is_empty():
		return _empty_outs(comp)
	if sv.has("tree"):
		return sv.tree.call(in_trees, node, ctx) if in_trees.size() > 0 and in_trees[0] != null else _empty_outs(comp)
	var def: Array = sv.get("def", [])
	var acc: Array = sv.get("access", [])
	var set_vals: Dictionary = node.get("set", {})
	var trees := []
	for i in comp.ins.size():
		var p: Array = comp.ins[i]
		if has_data(in_trees[i]):
			trees.append(in_trees[i])
		elif set_vals.has(p[0]):
			trees.append(single(resolve_set(set_vals[p[0]], ctx)))
		elif set_vals.has(str(i)):
			trees.append(single(resolve_set(set_vals[str(i)], ctx)))
		elif i < def.size() and not (def[i] is StringName and def[i] == U):
			trees.append(single(def[i]))
		else:
			return _empty_outs(comp)   # required input missing
	# a wired input that delivers no data stops the component (as in Grasshopper)
	for t in in_trees:
		if t != null and not has_data(t):
			return _empty_outs(comp)

	var nb := 1
	var path_src = null
	for t in trees:
		nb = maxi(nb, t.size())
		if path_src == null or t.size() > path_src.size():
			path_src = t
	var outs := _empty_outs(comp)
	for b in nb:
		var br := trees.map(func(t): return t[mini(b, t.size() - 1)])
		var path: Array = path_src[mini(b, path_src.size() - 1)].path if path_src != null else [0]
		var item_idx := []
		for i in br.size():
			if i >= acc.size() or acc[i] != "list":
				item_idx.append(i)
		var n := 1
		if not item_idx.is_empty():
			n = 0
			for i in item_idx:
				n = maxi(n, br[i].items.size())
			for i in item_idx:
				if br[i].items.is_empty():
					n = 0
		var res := []
		for k in n:
			var args := []
			for i in br.size():
				var items: Array = br[i].items
				args.append(items if (i < acc.size() and acc[i] == "list") else items[mini(k, items.size() - 1)])
			res.append(sv.fn.call(args, node, ctx))
		var listy := false
		for r in res:
			if r != null:
				for o in r:
					if is_list(o):
						listy = true
		for o in comp.outs.size():
			if listy and n > 1:
				for k in res.size():
					var r = res[k]
					outs[o].append({"path": path + [k], "items": _to_list(r[o]) if r != null and o < r.size() else []})
			else:
				var items := []
				for r in res:
					if r != null and o < r.size():
						items.append_array(_to_list(r[o]))
				outs[o].append({"path": path, "items": items})
	return outs


## level: normalised level; ctx: { placed: Callable(node)->bool, wire_active: Callable(wire)->bool, params: {} }
## Returns { node_id: [out_tree, ...] or null }.
static func evaluate(level: Dictionary, ctx: Dictionary) -> Dictionary:
	GHData.ensure_loaded()
	var nodes: Array = level.nodes
	var wires: Array = level.wires
	var indeg := {}
	for n in nodes:
		indeg[n.id] = 0
	for w in wires:
		indeg[w.to[0]] += 1
	var q := []
	for n in nodes:
		if indeg[n.id] == 0:
			q.append(n.id)
	var order := []
	while not q.is_empty():
		var id = q.pop_front()
		order.append(id)
		for w in wires:
			if w.from[0] == id:
				indeg[w.to[0]] -= 1
				if indeg[w.to[0]] == 0:
					q.append(w.to[0])
	var by_id := {}
	for n in nodes:
		by_id[n.id] = n
	var res := {}
	for id in order:
		var node: Dictionary = by_id[id]
		var comp := GHData.comp(node.comp)
		var in_trees := []
		for i in comp.ins.size():
			var ts := []
			for w in wires:
				if w.to[0] == id and w.to[1] == i and ctx.wire_active.call(w) and res.get(w.from[0]) != null and w.from[1] < res[w.from[0]].size():
					ts.append(res[w.from[0]][w.from[1]])
			in_trees.append(_map_input(merge_trees(ts), node, comp.ins[i][0]))
		if not ctx.placed.call(node):
			res[id] = [in_trees[0]] if node.get("passthrough", false) and not in_trees.is_empty() and in_trees[0] != null else null
			continue
		res[id] = solve_node(node, comp, in_trees, ctx)
	return res


## Grasshopper's flatten / graft input modifiers (node.in_map: { port nick: "flatten" | "graft" }).
static func _map_input(t: Variant, node: Dictionary, nick: String) -> Variant:
	var m = node.get("in_map", {}).get(nick)
	if m == null or not (t is Array):
		return t
	var out := []
	if m == "flatten":
		var items := []
		for b in t:
			items.append_array(b.items)
		return [{"path": [0], "items": items}]
	for b in t:
		for i in b.items.size():
			out.append({"path": b.path + [i], "items": [b.items[i]]})
	return out


const QUIET := ["slider", "panel", "toggle"]

## Build a preview scene from evaluation results. A node previews when node.preview is true, or by default
## when none of its outputs feed a placed node through an active wire (i.e. it is a current "leaf").
static func scene(level: Dictionary, res: Dictionary, ctx: Dictionary) -> Dictionary:
	var s := {"lines": [], "points": [], "labels": [], "arrows": []}
	var label_z := 0.0
	var by_id := {}
	for n in level.nodes:
		by_id[n.id] = n
	for node in level.nodes:
		var out = res.get(node.id)
		if out == null or not ctx.placed.call(node):
			continue
		var leaf := true
		for w in level.wires:
			if w.from[0] == node.id and ctx.wire_active.call(w) and ctx.placed.call(by_id[w.to[0]]):
				leaf = false
				break
		var show: bool = node.preview if node.has("preview") else leaf
		if not show:
			continue
		var k: String = node.id
		var comp := GHData.comp(node.comp)
		var is_vec_comp: bool = str(comp.cat).begins_with("Vector")
		var srf_count := 0
		for tree in out:
			for br in tree:
				for it in br.items:
					if is_geo(it, "srf"):
						srf_count += 1
		var nums := []
		var doms := 0
		for oi in out.size():
			for br in out[oi]:
				for it in br.items:
					if it == null:
						continue
					if it is float or it is int or it is bool:
						if oi == 0:
							nums.append(it)
						continue
					if not (it is Dictionary):
						continue
					match it.get("t"):
						"pt": s.points.append({"p": it.p, "k": k})
						"vec":
							if is_vec_comp:
								s.arrows.append({"from": Vector3.ZERO, "to": it.v, "k": k})
						"crv": s.lines.append({"pts": it.pts, "closed": it.closed, "k": k, "w": it.get("w")})
						"srf":
							s.lines.append({"pts": it.get("outline", it.c), "closed": true, "k": k})
							if srf_count == 1:
								for i in range(1, 4):
									var f := i / 4.0
									s.lines.append({"pts": [srf_point(it, f, 0), srf_point(it, f, 1)], "k": k, "color": Color(196 / 255.0, 44 / 255.0, 66 / 255.0, 0.28), "w": 0.8})
									s.lines.append({"pts": [srf_point(it, 0, f), srf_point(it, 1, f)], "k": k, "color": Color(196 / 255.0, 44 / 255.0, 66 / 255.0, 0.28), "w": 0.8})
						"loft":
							var ls := Geo.loft(it.sections.map(func(c): return c.pts), it.sections[0].closed, k)
							if it.sections.size() == 2:
								for r in range(1, 8):
									var f := r / 8.0
									var a0: Array = it.sections[0].pts
									var a1: Array = it.sections[1].pts
									var ring := []
									for i in a0.size():
										ring.append((a0[i] as Vector3).lerp(a1[i], f))
									ls.append({"pts": ring, "closed": it.sections[0].closed, "k": k, "w": 0.8})
							if node.get("ghost", false):
								for l in ls:
									l.color = Color(120 / 255.0, 60 / 255.0, 70 / 255.0, 0.22)
									l.k = null
									l.w = 0.8
							s.lines.append_array(ls)
						"dom2": doms += 1
		var name: String = node.get("label", comp.name)
		if not nums.is_empty() and not QUIET.has(node.comp):
			s.labels.append({"p": Vector3(0, 0, label_z), "text": "%s: %s" % [name, Geo.list_text(nums)], "k": k})
			label_z -= 1.2
		if doms > 0:
			s.labels.append({"p": Vector3(0, 0, label_z), "text": "%s: %d sub-domains" % [name, doms], "k": k})
			label_z -= 1.2
	return s
