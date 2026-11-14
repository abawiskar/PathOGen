## Geometry helpers, ported from the G object in web/js/preview.js.
class_name Geo
extends RefCounted


## Catmull-Rom spline through points (open).
static func spline(pts: Array, seg := 12) -> Array:
	if pts.size() < 3:
		return pts.duplicate()
	var out := []
	var P := [pts[0]] + pts + [pts[pts.size() - 1]]
	for i in range(1, P.size() - 2):
		for s in seg:
			var t := float(s) / seg
			var t2 := t * t
			var t3 := t2 * t
			var a: Vector3 = P[i - 1]
			var b: Vector3 = P[i]
			var c: Vector3 = P[i + 1]
			var d: Vector3 = P[i + 2]
			out.append(0.5 * ((2.0 * b) + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t2 + (-a + 3.0 * b - 3.0 * c + d) * t3))
	out.append(pts[pts.size() - 1])
	return out


## Divide a polyline into n equal-length segments -> n+1 points (or n points if closed).
static func divide(pts: Array, n: int, closed := false) -> Array:
	var P: Array = pts + [pts[0]] if closed else pts
	var L := [0.0]
	for i in range(1, P.size()):
		L.append(L[i - 1] + (P[i] as Vector3).distance_to(P[i - 1]))
	var total: float = L[L.size() - 1]
	var out := []
	var count := n if closed else n + 1
	var j := 1
	for k in count:
		var d := float(k) / n * total
		while j < L.size() - 1 and L[j] < d:
			j += 1
		var seg: float = L[j] - L[j - 1]
		if seg == 0.0:
			seg = 1.0
		var t := clampf((d - L[j - 1]) / seg, 0.0, 1.0)
		out.append((P[j - 1] as Vector3).lerp(P[j], t))
	return out


## Loft preview: section curves plus smooth rails through matching vertices.
static func loft(sections: Array, closed := true, k := "loft") -> Array:
	var lines := []
	for s in sections:
		lines.append({"pts": s, "closed": closed, "k": k})
	var n: int = sections[0].size()
	for i in n:
		var rail := []
		for s in sections:
			rail.append(s[i] if i < s.size() else s[s.size() - 1])
		lines.append({"pts": spline(rail, 8), "k": k, "w": 0.9})
	return lines


## JS: (Math.round(v * 100) / 100).toString()
static func fmt(v: Variant) -> String:
	var x := float(v) if (v is float or v is int) else (1.0 if v == true else 0.0)
	var r := floorf(x * 100.0 + 0.5) / 100.0
	if is_equal_approx(r, roundf(r)):
		return str(int(roundf(r)))
	var s := "%.2f" % r
	return s.rstrip("0").rstrip(".")


static func list_text(vals: Array, max_n := 6) -> String:
	var parts := PackedStringArray()
	for i in mini(max_n, vals.size()):
		parts.append(fmt(vals[i]))
	var s := ", ".join(parts)
	return s + ", …" if vals.size() > max_n else s
