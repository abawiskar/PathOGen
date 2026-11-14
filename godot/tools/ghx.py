"""Minimal .ghx (Grasshopper XML) reader: objects, params, wires, groups."""
import xml.etree.ElementTree as ET

def _items(ch):
    d = {}
    its = ch.find('items')
    if its is None:
        return d
    for it in its.findall('item'):
        n, idx = it.get('name'), it.get('index')
        d[n if idx is None else (n, int(idx))] = it
    return d

def _chunks(ch, name=None):
    cs = ch.find('chunks')
    if cs is None:
        return []
    return [c for c in cs.findall('chunk') if name is None or c.get('name') == name]

def _t(it):
    return it.text if it is not None else None

def _indexed(d, name):
    return [_t(v) for k, v in sorted(((k, v) for k, v in d.items() if isinstance(k, tuple) and k[0] == name), key=lambda kv: kv[0][1])]

def _pivot(cont):
    """Centre of the object on the canvas (Bounds), or its pivot when it has no bounds."""
    a = _chunks(cont, 'Attributes')
    if not a:
        return None
    ai = _items(a[0])
    b = ai.get('Bounds')
    if b is not None:
        return (float(b.find('X').text) + float(b.find('W').text) / 2, float(b.find('Y').text) + float(b.find('H').text) / 2)
    p = ai.get('Pivot')
    return (float(p.find('X').text), float(p.find('Y').text)) if p is not None else None

def _persist(ch):
    """Constant values typed into a parameter (PersistentData): numbers, bools, points, strings."""
    pd = _chunks(ch, 'PersistentData')
    if not pd:
        return None
    vals = []
    for br in _chunks(pd[0], 'Branch'):
        for it in _chunks(br, 'Item'):
            for item in it.iter('item'):
                tn = item.get('type_name')
                if tn in ('gh_double', 'gh_single', 'gh_int32'):
                    vals.append(float(item.text))
                elif tn == 'gh_bool':
                    vals.append(item.text == 'true')
                elif tn == 'gh_string' and item.get('name') != 'TypeName':
                    vals.append(item.text)
                elif tn in ('gh_point3d', 'gh_vector3d'):
                    vals.append([float(item.find(k).text) for k in ('X', 'Y', 'Z')])
                elif tn == 'gh_interval':
                    vals.append([float(item.find('A').text), float(item.find('B').text)])
    return vals or None

def _param(ch):
    i = _items(ch)
    return {
        'name': _t(i.get('Name')), 'nick': _t(i.get('NickName')), 'iid': _t(i.get('InstanceGuid')),
        'desc': _t(i.get('Description')), 'sources': _indexed(i, 'Source'),
        'mapping': int(_t(i.get('Mapping')) or 0),   # 1 = flatten, 2 = graft
        'reverse': _t(i.get('Reverse')) == 'true', 'simplify': _t(i.get('Simplify')) == 'true',
        'expression': _t(i.get('Expression')), 'persist': _persist(ch), 'degrees': _t(i.get('UseDegrees')) == 'true',
    }

def read(path):
    root = ET.parse(path).getroot()
    defn = _chunks(root, 'Definition')[0]
    objs = _chunks(defn, 'DefinitionObjects')[0]
    comps, groups, owner = {}, [], {}
    for oc in _chunks(objs, 'Object'):
        oi = _items(oc)
        name, tguid = _t(oi.get('Name')), _t(oi.get('GUID'))
        cont = _chunks(oc, 'Container')[0]
        ci = _items(cont)
        iid = _t(ci.get('InstanceGuid'))
        if name == 'Group':
            col = ci.get('Colour')
            groups.append({'name': _t(ci.get('NickName')), 'iid': iid, 'ids': _indexed(ci, 'ID'),
                           'argb': tuple(int(x) for x in col.find('ARGB').text.split(';')) if col is not None else None})
            continue
        c = {'type': name, 'tguid': tguid, 'iid': iid, 'nick': _t(ci.get('NickName')), 'desc': _t(ci.get('Description')),
             'locked': _t(ci.get('Locked')) == 'true', 'hidden': _t(ci.get('Hidden')) == 'true',
             'pivot': _pivot(cont), 'ins': [], 'outs': [], 'param': None}
        sl = _chunks(cont, 'Slider')
        if sl:
            si = _items(sl[0])
            c['slider'] = {k: float(_t(si.get(k))) for k in ('Min', 'Max', 'Value') if si.get(k) is not None}
            c['slider']['digits'] = int(_t(si.get('Digits')) or 0)
            c['slider']['interval'] = int(_t(si.get('Interval')) or 0)   # 0 float, 1 int, 2 even, 3 odd
        if name == 'Boolean Toggle':
            c['toggle'] = _t(ci.get('ToggleValue')) == 'true'
        sides = []
        for pc in _chunks(cont):
            if pc.get('name') in ('param_input', 'param_output'):
                sides.append(('ins' if pc.get('name') == 'param_input' else 'outs', pc))
        for pdc in _chunks(cont, 'ParameterData'):
            for pc in _chunks(pdc):
                if pc.get('name') in ('InputParam', 'OutputParam'):
                    sides.append(('ins' if pc.get('name') == 'InputParam' else 'outs', pc))
        for side, pc in sides:
            p = _param(pc)
            c[side].append(p)
            owner[p['iid']] = (iid, side, len(c[side]) - 1)
        if not c['ins'] and not c['outs']:
            # a floating parameter (Number Slider, Point, Curve, Data...): itself is the output
            c['param'] = _param(cont)
            owner[iid] = (iid, 'self', 0)
        comps[iid] = c
    return {'comps': comps, 'groups': groups, 'owner': owner}

def group_members(doc, g, seen=None):
    """Component ids in a group, following nested groups."""
    gid = {x['iid']: x for x in doc['groups']}
    seen = seen if seen is not None else set()
    out = []
    for i in g['ids']:
        if i in seen:
            continue
        seen.add(i)
        if i in gid:
            out += group_members(doc, gid[i], seen)
        elif i in doc['comps']:
            out.append(i)
    return out

def wires(doc):
    """(from_comp, from_out_index, to_comp, to_in_index) for every connection, params included."""
    out = []
    for c in doc['comps'].values():
        targets = [(i, p) for i, p in enumerate(c['ins'])] if c['ins'] or c['outs'] else ([(0, c['param'])] if c['param'] else [])
        for i, p in targets:
            for s in p['sources']:
                if s in doc['owner']:
                    sc, side, k = doc['owner'][s]
                    out.append((sc, 0 if side == 'self' else k, c['iid'], i))
    return out
