/* Render the A03 Grasshopper definition as a wide PathOGen game canvas.
 * All nodes, ports, wires, and default slider values come from the level data.
 */
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const root = path.resolve(__dirname, '..');
const web = path.join(root, 'web');
const level = JSON.parse(fs.readFileSync(path.join(web, 'levels', '01-base-shape', 'A03.json'), 'utf8'));
const scope = {};
const libCode = fs.readFileSync(path.join(web, 'js', 'data.js'), 'utf8') + '\n' +
  fs.readFileSync(path.join(web, 'js', 'components_extra.js'), 'utf8') + '\n' +
  fs.readFileSync(path.join(web, 'js', 'gh_icons.js'), 'utf8') + '\n' +
  '({ components: COMPONENTS, iconFiles: GH_ICONS });';
const { components, iconFiles } = vm.runInNewContext(libCode, scope);

const W = 3840, H = 1800;
const SX = 2.42, SY = 2.30, TX = 236, TY = 550;
const outFile = path.join(web, 'levels', '01-base-shape', 'A03-definition.svg');
const esc = s => String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&apos;'}[c]));
const fmt = n => Number(n.toFixed(2));
const text = (x, y, value, size, fill, extra = '') => `<text x="${fmt(x)}" y="${fmt(y)}" font-size="${size}" fill="${fill}" ${extra}>${esc(value)}</text>`;
const nodes = new Map(level.nodes.map(n => [n.id, n]));
const params = new Map(level.params.map(p => [p.key, p]));
const openOrder = new Map(level.order.map((id, i) => [id, i + 1]));

function rect(x,y,w,h,rx,fill,stroke='none',sw=0,extra='') {
  return `<rect x="${fmt(x)}" y="${fmt(y)}" width="${fmt(w)}" height="${fmt(h)}" rx="${rx}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}" ${extra}/>`;
}
function circle(x,y,r,fill,stroke='none',sw=0) {
  return `<circle cx="${fmt(x)}" cy="${fmt(y)}" r="${r}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}"/>`;
}
function line(x1,y1,x2,y2,stroke,sw=2,extra='') {
  return `<line x1="${fmt(x1)}" y1="${fmt(y1)}" x2="${fmt(x2)}" y2="${fmt(y2)}" stroke="${stroke}" stroke-width="${sw}" ${extra}/>`;
}

const overrides = { slider5: {dy: 128} };
function geometry(n) {
  const c = components[n.comp];
  if (!c) throw new Error(`Unknown component ${n.comp}`);
  const x = TX + n.x * SX + (overrides[n.id]?.dx || 0);
  const y = TY + n.y * SY + (overrides[n.id]?.dy || 0);
  const slider = n.comp === 'slider';
  const w = slider ? 218 : (c.name.length > 14 ? 238 : 212);
  const rows = Math.max(c.ins.length, c.outs.length);
  const h = slider ? 74 : Math.max(112, 70 + rows * 34);
  const left = x - w/2, top = y - h/2;
  const ins = {}, outs = {};
  c.ins.forEach((p,i) => ins[p[0]] = [left, top + 55 + i*34]);
  c.outs.forEach((p,i) => outs[p[0]] = [left+w, slider ? y : top + 55 + i*34]);
  return {n,c,x,y,w,h,left,top,ins,outs,slider};
}
const geo = new Map(level.nodes.map(n => [n.id, geometry(n)]));

function icon(g) {
  const filename = iconFiles[g.n.comp];
  if (!filename) return '';
  const file = path.join(web, 'img', 'gh-icons', filename);
  if (!fs.existsSync(file)) return '';
  const data = fs.readFileSync(file).toString('base64');
  return `<image x="${fmt(g.x-25)}" y="${fmt(g.top+g.h-64)}" width="50" height="50" href="data:image/svg+xml;base64,${data}"/>`;
}

function drawNode(g) {
  const {n,c,x,y,w,h,left,top,slider} = g;
  const open = !!n.open;
  let s = '';
  if (open) {
    s += rect(left-11,top-11,w+22,h+22,19,'#9b864d','none',0,'opacity=".22" filter="url(#gold-glow)"');
    s += rect(left-8,top-8,w+16,h+16,17,'none','#d8c48c',3,'opacity=".85"');
  }
  s += rect(left+4,top+9,w,h,14,'#091412','none',0,'opacity=".50"');
  s += rect(left,top,w,h,13,'url(#node-face)',open?'#e9d8aa':'#77918a',open?3.5:2.5);
  if (slider) {
    const p = params.get(n.param);
    const display = p && Number.isFinite(p.value) ? String(p.value).replace(/\.0$/, '') : '';
    const label = n.label || p?.label || 'Number';
    s += text(left+18,top+29,label,23,'#24332e','font-weight="700"');
    s += text(left+w-17,top+29,display,25,'#24332e','font-weight="700" text-anchor="end"');
    s += line(left+20,top+52,left+w-28,top+52,'#798b84',5,'stroke-linecap="round"');
    const t = p ? Math.max(.08, Math.min(.95, (p.value-p.min)/(p.max-p.min||1))) : .5;
    s += circle(left+20+(w-48)*t,top+52,10,'#4e8b69','#e8eee4',2);
    s += circle(left+w,y,9,'#324a41','#edf2e8',2);
  } else {
    s += rect(left+1,top+1,w-2,39,11,open?'#e8dfc5':'#dce5d9');
    s += rect(left+1,top+30,w-2,11,0,open?'#e8dfc5':'#dce5d9');
    s += line(left+13,top+41,left+w-13,top+41,'#a6b4a9',2);
    s += text(left+14,top+29,n.label || c.name,22,'#20312b','font-weight="700"');
    for (const [i,p] of c.ins.entries()) {
      const yy = top+55+i*34;
      s += circle(left,yy,8,'#263a32','#eff2e7',2);
      s += text(left+17,yy+7,p[0],22,'#2c4037','font-weight="600"');
    }
    for (const [i,p] of c.outs.entries()) {
      const yy = top+55+i*34;
      s += circle(left+w,yy,8,'#263a32','#eff2e7',2);
      s += text(left+w-17,yy+7,p[0],22,'#2c4037','font-weight="600" text-anchor="end"');
    }
    s += icon(g);
  }
  if (open) {
    const k = openOrder.get(n.id);
    s += circle(left+w-4,top-8,26,'#dbc997','#20372e',3);
    s += text(left+w-4,top+2,String(k).padStart(2,'0'),23,'#23352c','text-anchor="middle" font-weight="800"');
  }
  return s;
}

function wirePath(w) {
  const [fromId, fromPort] = w.from.split('.');
  const [toId, toPort] = w.to.split('.');
  const a = geo.get(fromId)?.outs[fromPort], b = geo.get(toId)?.ins[toPort];
  if (!a || !b) throw new Error(`Cannot map wire ${w.from} → ${w.to}`);
  const dx = Math.max(90, (b[0]-a[0])*0.43);
  return `M ${fmt(a[0])} ${fmt(a[1])} C ${fmt(a[0]+dx)} ${fmt(a[1])}, ${fmt(b[0]-dx)} ${fmt(b[1])}, ${fmt(b[0])} ${fmt(b[1])}`;
}

function zone(x,y,w,h,number,title,sub) {
  return `<g>${rect(x,y,w,h,24,'#244039','#3f5b50',2,'opacity=".53"')}`+
    text(x+29,y+47,number,28,'#e0d2a5','font-weight="800" letter-spacing="4"')+
    text(x+95,y+46,title.toUpperCase(),26,'#dbe8db','font-weight="700" letter-spacing="2"')+
    text(x+29,y+85,sub,19,'#a7c0ad','letter-spacing=".5"')+'</g>';
}

let svg = `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
<defs>
  <radialGradient id="bg" cx="52%" cy="38%" r="72%"><stop stop-color="#223832"/><stop offset=".65" stop-color="#162823"/><stop offset="1" stop-color="#0d1b18"/></radialGradient>
  <linearGradient id="node-face" x2="0" y2="1"><stop stop-color="#f7f5ed"/><stop offset="1" stop-color="#d3dcd1"/></linearGradient>
  <pattern id="grid" width="120" height="120" patternUnits="userSpaceOnUse"><path d="M 120 0 L 0 0 0 120" fill="none" stroke="#5f8072" stroke-width="2" opacity=".18"/></pattern>
  <filter id="gold-glow" x="-30%" y="-40%" width="160%" height="180%"><feGaussianBlur stdDeviation="12"/></filter>
  <filter id="shape-glow" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur stdDeviation="10"/></filter>
</defs>`;
svg += rect(0,0,W,H,0,'url(#bg)');
svg += rect(44,309,W-88,1160,18,'url(#grid)','#496257',2);
svg += rect(22,22,W-44,H-44,21,'none','#426354',3);
svg += text(110,93,'PATHOGEN  /  PATTERN POUNCER',31,'#a8c690','font-weight="800" letter-spacing="6"');
svg += text(108,195,'GROW A FLOOR PLATE FROM A SINGLE POINT',81,'#e8dcb0','font-family="Georgia,serif" font-weight="700" letter-spacing="3"');
svg += text(114,256,'Move a seed point, generate the angles, rotate the copies, then refine the outline.',33,'#b4c9b7');
svg += line(110,292,W-110,292,'#577164',3);

svg += zone(112,365,540,340,'01','Set the seed','Start at the floor plate centre');
svg += zone(674,365,800,365,'02','Offset the point','Build a translated starting corner');
svg += zone(670,760,1120,650,'03','Set the rhythm','Numbers drive the repeated rotations');
svg += zone(1810,365,1000,545,'04','Repeat and connect','Form the outline from rotated points');
svg += zone(2834,365,895,822,'05','Locate and soften','Find transitions and refine the curve');

// Draw the exact 20 directed connections, then put the native Grasshopper chips on top.
for (const w of level.wires) {
  const p = wirePath(w);
  svg += `<path d="${p}" fill="none" stroke="#071512" stroke-width="13" stroke-linecap="round" opacity=".50"/>`;
  svg += `<path d="${p}" fill="none" stroke="#b8d0bb" stroke-width="5.5" stroke-linecap="round" opacity=".94"/>`;
}
for (const n of level.nodes) svg += drawNode(geo.get(n.id));

// A quiet game-style output panel keeps the graph itself as the main event.
svg += rect(2910,1250,812,465,18,'#1b312a','#75917b',3);
svg += text(2960,1310,'GEOMETRY GOAL',29,'#e8dcb0','font-weight="800" letter-spacing="4"');
svg += text(2960,1358,'Rounded five-sided floor plate',26,'#ccdecb');
svg += circle(3316,1523,158,'none','#6c8b78',3);
for (let i=0;i<5;i++) {
  const a=-Math.PI/2+i*2*Math.PI/5;
  const x=3316+158*Math.cos(a), y=1523+158*Math.sin(a);
  svg += line(3316,1523,x,y,'#59786b',2,'stroke-dasharray="8 10"');
  svg += circle(x,y,6,'#a8c690');
}
const verts=Array.from({length:5},(_,i)=>{const a=-Math.PI/2+i*2*Math.PI/5;return [3316+158*Math.cos(a),1523+158*Math.sin(a)]});
const f=.16;
let d='';
for(let i=0;i<5;i++) {
  const a=verts[i], b=verts[(i+1)%5], c=verts[(i+2)%5];
  const start=[a[0]+(b[0]-a[0])*f,a[1]+(b[1]-a[1])*f];
  const end=[b[0]+(c[0]-b[0])*f,b[1]+(c[1]-b[1])*f];
  if(i===0)d=`M ${fmt(start[0])} ${fmt(start[1])}`;
  d+=` L ${fmt(b[0]-(b[0]-a[0])*f)} ${fmt(b[1]-(b[1]-a[1])*f)} Q ${fmt(b[0])} ${fmt(b[1])} ${fmt(end[0])} ${fmt(end[1])}`;
}
d+=' Z';
svg += `<path d="${d}" fill="#659b6d" fill-opacity=".25" stroke="#dbd2a4" stroke-width="22" opacity=".35" filter="url(#shape-glow)"/>`;
svg += `<path d="${d}" fill="#659b6d" fill-opacity=".20" stroke="#e9deae" stroke-width="6" stroke-linejoin="round"/>`;
svg += circle(3316,1523,9,'#e8dcb0');

svg += text(120,1523,'THE PLAYER BUILDS THE GOLD-FRAMED COMPONENTS',29,'#e8dcb0','font-weight="800" letter-spacing="3"');
svg += text(120,1582,'The full definition stays visible so every choice has a place in the larger script.',31,'#c4d8c6');
svg += text(120,1699,`${level.nodes.length} native components   ·   ${level.wires.length} connected wires   ·   5 playable steps`,27,'#8eaa98','font-weight="700" letter-spacing="1"');
svg += text(3692,1755,'PATHOGEN',26,'#91a992','font-family="Georgia,serif" text-anchor="end" letter-spacing="5"');
svg += '</svg>\n';
fs.writeFileSync(outFile, svg, 'utf8');
console.log(`Wrote ${outFile} from ${level.nodes.length} nodes and ${level.wires.length} wires`);
