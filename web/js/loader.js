/* PathOGen — loads levels/<dir>/level.json and normalises them for the game.
 *
 * level.json (see levels/README.md):
 *   nodes[]: { id, comp, open, x, y, label?, param?, set?, graph?, baked?, preview?, passthrough?,
 *              need?, hint?, correct?, wrong?: { compId | "*": text }, distractors?, draft? }
 *   wires[]: { from: "node.Out", to: "node.In", check?: { side?: "in"|"out", prompt?, hint?, correct?, wrong?, draft? } }
 *   order?:  explicit build order of open node ids (default: topological order of the graph)
 *   difficulties?: [{ id, name, description?, file?, ...rule overrides }] — see levels/README.md
 */
var LEVELS = [];
var MONSTER_OVERRIDE = null;

const LevelLoader = (() => {
  function resolvePort(nodes, ref, side, where) {
    const dot = ref.lastIndexOf('.');
    const id = ref.slice(0, dot), p = ref.slice(dot + 1);
    const n = nodes.find(x => x.id === id);
    if (!n) throw new Error(`${where}: wire "${ref}" points at unknown node "${id}"`);
    const list = COMPONENTS[n.comp][side];
    let i = list.findIndex(x => x[0] === p);
    if (i < 0 && /^\d+$/.test(p)) i = +p;
    if (i < 0 || i >= list.length) throw new Error(`${where}: ${COMPONENTS[n.comp].name} has no ${side === 'ins' ? 'input' : 'output'} "${p}" (${ref})`);
    return [id, i];
  }

  function topoOrder(nodes, wires) {
    const indeg = Object.fromEntries(nodes.map(n => [n.id, 0]));
    wires.forEach(w => indeg[w.to[0]]++);
    const ready = nodes.filter(n => !indeg[n.id]).map(n => n.id), out = [];
    while (ready.length) {
      ready.sort((a, b) => nodes.findIndex(n => n.id === a) - nodes.findIndex(n => n.id === b));
      const id = ready.shift(); out.push(id);
      wires.filter(w => w.from[0] === id).forEach(w => { if (--indeg[w.to[0]] === 0) ready.push(w.to[0]); });
    }
    return out;
  }

  const catOf = (id) => COMPONENTS[id].cat.split(' / ')[0];
  function defaultDistractors(compId) {
    const pool = Object.keys(COMPONENTS).filter(k => k !== compId && catOf(k) === catOf(compId));
    for (let i = pool.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [pool[i], pool[j]] = [pool[j], pool[i]]; }
    return pool.slice(0, 5);
  }

  function normalize(raw, dir) {
    const where = `levels/${dir}/level.json`;
    (raw.nodes || []).forEach(n => { if (!COMPONENTS[n.comp]) throw new Error(`${where}: unknown component "${n.comp}" on node "${n.id}"`); });
    const nodes = raw.nodes.map(n => Object.assign({}, n, { given: !n.open, step: n.open ? n.id : undefined }));
    const wires = (raw.wires || []).map((w, i) => ({
      from: resolvePort(nodes, w.from, 'outs', where), to: resolvePort(nodes, w.to, 'ins', where),
      check: w.check || null, quiz: w.check ? 'wire:' + i : undefined,
    }));
    const openIds = nodes.filter(n => n.open).map(n => n.id);
    const order = raw.order ? raw.order.slice() : topoOrder(nodes, wires).filter(id => openIds.includes(id));
    openIds.forEach(id => { if (!order.includes(id)) throw new Error(`${where}: open node "${id}" missing from "order"`); });
    const node = (id) => nodes.find(n => n.id === id);
    const steps = order.map(id => {
      const n = node(id), c = COMPONENTS[n.comp];
      return {
        key: id, comp: n.comp,
        need: n.need || `the right ${catOf(n.comp)} component`,
        distractors: (n.distractors || defaultDistractors(n.comp)).filter(d => COMPONENTS[d] && d !== n.comp),
        hint: n.hint || `Look in the ${c.cat.replace(' / ', ' › ')} panel.`,
        why: n.correct || `${c.name}: ${c.desc}`,
        wrong: n.wrong || {}, quizzes: [],
      };
    });
    const pos = (id) => (node(id).open ? order.indexOf(id) : -1);
    wires.forEach(w => {
      if (!w.check) return;
      const side = w.check.side === 'out' ? 'out' : 'in';
      const target = side === 'in' ? w.to[0] : w.from[0], idx = side === 'in' ? w.to[1] : w.from[1];
      const comp = COMPONENTS[node(target).comp], port = comp[side === 'in' ? 'ins' : 'outs'][idx];
      const quiz = {
        key: w.quiz, target, side, answer: port[0], answerIdx: idx,
        prompt: w.check.prompt || `Which ${side === 'in' ? 'input' : 'output'} of ${comp.name} should this wire connect to?`,
        hint: w.check.hint || `It carries ${port[2]}.`, why: w.check.correct || `${port[0]} (${port[1]}) expects ${port[2]}.`, wrong: w.check.wrong || {},
      };
      steps[Math.max(0, pos(w.from[0]), pos(w.to[0]))].quizzes.push(quiz);
    });
    return Object.assign({ params: [], lifesavers: {}, health: 4, guidance: 'standard' }, raw,
      { dir, nodes, wires, steps, monster: MONSTER_OPTIONS[raw.monster] ? raw.monster : (console.warn(`${where}: unknown monster "${raw.monster}"`), 'placeholder') });
  }

  async function loadAll() {
    const idx = await (await fetch('levels/index.json', { cache: 'no-cache' })).json();
    const pick = (location.search.match(/[?&]monster=(\w+)/) || [])[1];
    MONSTER_OVERRIDE = MONSTER_OPTIONS[pick] ? pick : null;
    const out = [];
    const get = async (url) => { const r = await fetch(url, { cache: 'no-cache' }); if (!r.ok) throw new Error(`${url}: ${r.status} ${r.statusText}`); return r.json(); };
    for (const dir of idx.levels) {
      const raw = await get(`levels/${dir}/level.json`);
      // Difficulties: each may load its own definition file and override game rules.
      // Without a list the level plays as one "Standard" difficulty using level.json's own graph.
      const list = raw.difficulties && raw.difficulties.length ? raw.difficulties : [{ id: 'standard', name: 'Standard' }];
      const base = Object.assign({}, raw); delete base.difficulties;
      const diffs = [];
      for (let i = 0; i < list.length; i++) {
        const entry = list[i];
        const def = entry.file ? await get(`levels/${dir}/${entry.file}`) : {};
        const knobs = Object.assign({}, entry); delete knobs.file; delete knobs.id; delete knobs.name; delete knobs.description;
        const merged = Object.assign({}, base, def, knobs);
        // "open": which node ids the player must place in this difficulty (others start on the canvas)
        if (Array.isArray(merged.open)) merged.nodes = merged.nodes.map(n => Object.assign({}, n, { open: merged.open.includes(n.id) }));
        const lvl = normalize(merged, dir + (entry.file ? '/' + entry.file : ''));
        lvl.dir = dir;
        Object.assign(lvl, { diffId: String(entry.id != null ? entry.id : i + 1), diffName: entry.name || `Difficulty ${i + 1}`,
          diffDesc: entry.description || '', diffIndex: i, diffCount: list.length });
        diffs.push({ id: lvl.diffId, name: lvl.diffName, description: lvl.diffDesc, level: lvl });
      }
      // the stage behaves like its first difficulty for map/meta purposes
      out.push(Object.assign({}, diffs[0].level, { difficulties: diffs }));
    }
    return out;
  }
  return { loadAll, normalize };
})();
