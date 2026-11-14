/* PathOGen — game engine and UI. */
(() => {
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];
  const stage = $('#stage');
  const shuffle = (a) => { for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };
  const pad2 = (n) => String(n).padStart(2, '0');
  const esc = (s) => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

  /* ───────── Stage scaling ───────── */
  function fit() {
    const s = Math.min(innerWidth / 1600, innerHeight / 900);
    stage.style.transform = `translate(-50%, -50%) scale(${s})`;
  }
  addEventListener('resize', fit); fit();

  /* ───────── Save data ───────── */
  const SAVE_KEY = 'pathogen.save.v1';
  let save = { best: {}, unlocked: 1 };
  try { save = Object.assign(save, JSON.parse(localStorage.getItem(SAVE_KEY) || '{}')); } catch (e) { /* storage unavailable */ }
  const writeSave = () => { try { localStorage.setItem(SAVE_KEY, JSON.stringify(save)); } catch (e) { /* ignore */ } };
  const totalXP = () => Object.values(save.best).reduce((a, b) => a + (b.xp || 0), 0);
  const RANKS = [[0, 'Novice'], [600, 'Apprentice'], [1500, 'Wirebender'], [3000, 'Definition Smith'], [5000, 'Parametric Ranger'], [7500, 'Script Master']];
  const rankFor = (xp) => RANKS.filter(r => xp >= r[0]).pop()[1];

  /* ───────── Screens ───────── */
  function show(id) { $$('.screen').forEach(s => s.classList.toggle('active', s.id === id)); }

  /* ───────── Toast / tooltip / modal ───────── */
  function toast(msg, cls = '') {
    const t = document.createElement('div'); t.className = 'toast-msg ' + cls; t.textContent = msg;
    $('#toast').appendChild(t); setTimeout(() => t.remove(), 2300);
  }
  let modalOnClose = null;
  function modal(html, onClose) {
    $('#modal-card').innerHTML = html; $('#modal').classList.remove('hidden'); modalOnClose = onClose || null;
    hideTip();
  }
  function closeModal() { $('#modal').classList.add('hidden'); const f = modalOnClose; modalOnClose = null; if (f) f(); }
  const modalOpen = () => !$('#modal').classList.contains('hidden');
  $('#modal').addEventListener('click', e => {
    const b = e.target.closest('[data-act]'); if (b) { modalAction(b.dataset.act); return; }
    if (e.target.id === 'modal' || e.target.closest('.x-close')) closeModal();
  });
  let tipEl = null;
  function showTip(el, html) {
    hideTip(); tipEl = document.createElement('div'); tipEl.className = 'tip'; tipEl.innerHTML = html; stage.appendChild(tipEl);
    const sr = stage.getBoundingClientRect(), er = el.getBoundingClientRect(), k = sr.width / 1600;
    const x = (er.left - sr.left) / k, y = (er.top - sr.top) / k;
    tipEl.style.left = Math.min(1360, x) + 'px'; tipEl.style.top = (y - tipEl.offsetHeight - 10) + 'px';
  }
  function hideTip() { if (tipEl) { tipEl.remove(); tipEl = null; } }

  /* ───────── Chip (Grasshopper component) renderer ───────── */
  const ROW = 13;
  function chipSize(comp, w) {
    if (comp.id === 'slider') return { w: 108, h: 22 };
    const rows = Math.max(comp.ins.length, comp.outs.length, 1);
    return { w: w || 92, h: Math.max(rows * ROW + 12, 30) };
  }
  function iconSVG(id, x, y, s) {
    return `<svg class="icon" x="${x}" y="${y}" width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">${ICONS[id] || ''}</svg>`;
  }
  /* returns { svg, ports: { in: [[x,y]], out: [[x,y]] }, w, h } — centred at (cx, cy) */
  function chip(comp, cx, cy, o = {}) {
    const { w, h } = chipSize(comp, o.w);
    const x0 = cx - w / 2, y0 = cy - h / 2;
    const ports = { in: [], out: [] };
    if (comp.id === 'slider') {
      const val = o.value != null ? G.fmt(o.value) : '';
      const label = o.locked ? '???' : (o.label || 'Slider');
      const knob = o.frac != null ? x0 + 48 + o.frac * 34 : x0 + 64;
      ports.out.push([x0 + w, cy]);
      return { w, h, ports, svg: `<g class="g-slider">
        <rect class="body" x="${x0}" y="${y0}" width="${w}" height="${h}" rx="4"/>
        <text x="${x0 + 6}" y="${cy + 3.5}" font-size="9.5" font-weight="700" font-family="Barlow,sans-serif" fill="#333">${esc(label.slice(0, 8))}</text>
        <line class="track" x1="${x0 + 48}" y1="${cy}" x2="${x0 + 82}" y2="${cy}"/>
        <rect class="knob" x="${knob - 2.5}" y="${cy - 5}" width="5" height="10" rx="1"/>
        <text x="${x0 + w - 6}" y="${cy + 3.5}" text-anchor="end" font-size="10" font-weight="700" font-family="Barlow,sans-serif" fill="#2f6d52">${esc(val)}</text>
        <circle class="g-port" cx="${x0 + w}" cy="${cy}" r="3.4"/></g>` };
    }
    const zin = comp.ins.length ? (o.big ? 22 : 18) : 6, zout = comp.outs.length ? (o.big ? 22 : 18) : 6;
    const fs = o.big ? 13 : 10;
    let s = `<g class="g-chip${o.anim ? ' placed-anim' : ''}"><rect class="body" x="${x0}" y="${y0}" width="${w}" height="${h}" rx="${o.big ? 7 : 5}"/>`;
    if (comp.ins.length) s += `<line class="div" x1="${x0 + zin}" y1="${y0 + 3}" x2="${x0 + zin}" y2="${y0 + h - 3}"/>`;
    if (comp.outs.length) s += `<line class="div" x1="${x0 + w - zout}" y1="${y0 + 3}" x2="${x0 + w - zout}" y2="${y0 + h - 3}"/>`;
    const portY = (i, n) => y0 + 6 + (i + 0.5) * (h - 12) / n;
    comp.ins.forEach((p, i) => {
      const y = portY(i, comp.ins.length), hl = o.hlSide === 'in' && o.hlIdx === i;
      ports.in.push([x0, y]);
      s += `<text x="${x0 + zin / 2}" y="${y + fs * 0.36}" text-anchor="middle" font-size="${fs}" ${hl ? 'fill="#b3402e" font-weight="800"' : ''}>${o.locked ? '?' : esc(p[0])}</text>`;
      s += `<circle class="g-port${hl ? ' hl' : ''}" cx="${x0}" cy="${y}" r="${hl ? 5 : (o.big ? 4 : 3.2)}"/>`;
    });
    comp.outs.forEach((p, i) => {
      const y = portY(i, comp.outs.length), hl = o.hlSide === 'out' && o.hlIdx === i;
      ports.out.push([x0 + w, y]);
      s += `<text x="${x0 + w - zout / 2}" y="${y + fs * 0.36}" text-anchor="middle" font-size="${fs}" ${hl ? 'fill="#b3402e" font-weight="800"' : ''}>${o.locked ? '?' : esc(p[0])}</text>`;
      s += `<circle class="g-port${hl ? ' hl' : ''}" cx="${x0 + w}" cy="${y}" r="${hl ? 5 : (o.big ? 4 : 3.2)}"/>`;
    });
    const isz = Math.min(o.big ? 30 : 20, h - 8), mid = x0 + zin + (w - zin - zout) / 2;
    s += o.locked ? `<text x="${mid}" y="${cy + 6}" text-anchor="middle" font-size="16" font-weight="800" fill="#8a2a36">?</text>` : iconSVG(comp.id, mid - isz / 2, cy - isz / 2, isz);
    s += '</g>';
    return { svg: s, ports, w, h };
  }

  /* ───────── Game state ───────── */
  let st = null;
  const preview = new Preview($('#preview-canvas'));
  const cur = () => st && st.decisions[st.di];
  const level = () => st.L;
  const nodeById = (id) => st.L.nodes.find(n => n.id === id);
  const isPlaced = (n) => n.given || st.done.has(n.step);
  /* the path's single monster, with this level's phase of attacks */
  const phaseOf = (idx) => MONSTER_PHASES[Math.min(idx, MONSTER_PHASES.length - 1)];
  const monsterKey = (L) => MONSTER_OVERRIDE || L.monster;
  const monster = () => Object.assign({}, MONSTER_OPTIONS[monsterKey(st.L)], phaseOf(st.idx));
  const monsterArt = (key) => { const m = MONSTER_OPTIONS[key]; return m.img ? `<img class="monster-img" src="${m.img}" alt="${esc(m.name)}">` : ART.monster(m.art); };
  const levelHP = (L) => buildDecisions(L).reduce((a, d) => a + (d.kind === 'comp' ? 10 : 5), 0);
  /* hero sprite reactions (frames cut from the hero sheet) */
  const HERO_FRAMES = { success: 4, damage: 4, defeat: 4 };
  let heroTimer = null;
  function heroReact(kind) {
    const el = $('#hero img'); if (!el) return;
    clearInterval(heroTimer); clearTimeout(heroTimer);
    if (!HERO_FRAMES[kind]) { el.src = 'img/hero-main.png'; el.className = 'hero-main'; return; }
    let i = 0; el.className = 'hero-frame'; el.src = `img/hero-${kind}-0.png`;
    heroTimer = setInterval(() => {
      if (++i < HERO_FRAMES[kind]) { el.src = `img/hero-${kind}-${i}.png`; return; }
      clearInterval(heroTimer);
      if (kind !== 'defeat') heroTimer = setTimeout(() => heroReact('idle'), 600);
    }, 140);
  }
  ['main', 'success-0', 'success-1', 'success-2', 'success-3', 'damage-0', 'damage-1', 'damage-2', 'damage-3', 'defeat-0', 'defeat-1', 'defeat-2', 'defeat-3']
    .forEach(f => { new Image().src = `img/hero-${f}.png`; });
  const HAND_SIZE = { guided: 4, standard: 5, independent: 6 };
  const LS_INFO = {
    hint: ['Hint', 'Reveals a clue about the missing component or port.'],
    potion: ['Health Potion', 'Restores one heart.'],
    fifty: ['50/50', 'Removes two incorrect cards from your hand.'],
    clear: ['Clear Vision', 'Removes blur, the icon curse and hidden node labels.'],
    shield: ['Shield', 'Blocks the next monster attack completely.'],
    second: ['Second Chance', 'Undo your last mistake: health, penalty and card restored.'],
  };
  const INTENT_TXT = { hit: '1 damage', damage: '2 damage', blur: '1 dmg + blur', icon: '1 dmg + icon curse', scramble: '1 dmg + scramble', locked: '1 dmg + lock node', time: '1 dmg + time pressure' };
  const ATTACK_NAME = { hit: 'Strike', damage: 'Heavy Strike', blur: 'Blurred Vision', icon: 'Icon Curse', scramble: 'Scramble', locked: 'Locked Component', time: 'Time Pressure' };

  function buildDecisions(L) {
    const out = [];
    L.steps.forEach(s => {
      out.push({ kind: 'comp', key: s.key, step: s });
      (s.quizzes || []).forEach(q => out.push({ kind: 'quiz', key: q.key, step: s, quiz: q }));
    });
    return out;
  }

  function startLevel(idx) {
    const L = LEVELS[idx];
    if (st) clearTimer();
    st = {
      idx, L, health: L.health, max: L.health, di: 0, decisions: buildDecisions(L), done: new Set(),
      hand: [], selected: null, effects: { blur: 0, icon: 0, locked: null }, timer: null, timerInt: null,
      shield: false, snap: null, ls: Object.assign({}, L.lifesavers), xp: 0, mistakes: 0, aids: 0, attempts: 0,
      streak: 0, drops: 0, decMistakes: 0, hintShown: false, params: Object.fromEntries(L.params.map(p => [p.key, p.value])),
      journal: [], over: false, won: false, intent: null, lastPlaced: null, fb: null,
    };
    st.hpMax = levelHP(L); st.hp = st.hpMax;
    heroReact('idle');
    rollIntent(); dealHand();
    st.fb = { cls: '', head: 'Field notes', title: level().title, body: level().objective, meta: `<b>Skill:</b> ${esc(level().learn)}` };
    show('screen-battle');
    preview.setView('perspective'); preview.zoom = 1;
    renderParams(); renderAll(); updatePreview();
    briefing();
  }

  function rollIntent() {
    const w = monster().intents, entries = Object.entries(w), tot = entries.reduce((a, e) => a + e[1], 0);
    let r = Math.random() * tot;
    for (const [k, v] of entries) { r -= v; if (r <= 0) { st.intent = k; break; } }
    if (!st.intent) st.intent = entries[0][0];
  }

  function dealHand(anim = true) {
    const d = cur(); if (!d) { st.hand = []; return; }
    if (d.kind === 'comp') {
      const ids = [d.step.comp, ...d.step.distractors];
      const size = Math.max(HAND_SIZE[level().guidance], ids.length);
      const fill = shuffle(FILLER.filter(f => !ids.includes(f)));
      while (ids.length < size && fill.length) ids.push(fill.pop());
      st.hand = shuffle(ids.slice(0, size));
    } else {
      const comp = COMPONENTS[nodeById(d.quiz.target).comp];
      st.hand = comp[d.quiz.side === 'in' ? 'ins' : 'outs'].map((_, i) => 'port:' + i);
    }
    st.selected = null; st.hintShown = false; st.dealAnim = anim; st.pan = { x: 0, y: 0 };
  }

  const isCorrect = (d, id) => {
    if (d.kind === 'comp') return id === d.step.comp;
    return +id.split(':')[1] === d.quiz.answerIdx;
  };
  function portOf(d, id) {
    const comp = COMPONENTS[nodeById(d.quiz.target).comp];
    return comp[d.quiz.side === 'in' ? 'ins' : 'outs'][+id.split(':')[1]];
  }
  const wrongCards = () => st.hand.filter(id => !isCorrect(cur(), id));

  /* ───────── Core actions ───────── */
  function select(id) {
    if (!st || st.over) return;
    st.selected = st.selected === id ? null : id;
    renderHand(); renderFeatured(); renderGraph();
  }
  function place(id = st.selected) {
    if (!st || st.over || !id || st.busy) return;
    const d = cur(); if (!d) return;
    st.attempts++;
    st.snap = null;
    if (isCorrect(d, id)) onCorrect(d, id); else onWrong(d, id);
  }

  function onCorrect(d, id) {
    clearTimer();
    st.done.add(d.key);
    const clean = st.decMistakes === 0, gain = (d.kind === 'comp' ? 100 : 60) + (clean ? 40 : 0);
    st.xp += gain;
    const dmg = d.kind === 'comp' ? 10 : 5; st.hp = Math.max(0, st.hp - dmg);
    st.streak++;
    st.lastPlaced = d.kind === 'comp' ? d.step.key : null;
    floatText($('#mon-art'), `-${dmg}`, ''); floatText($('#p-health'), `+${gain} XP`, 'good', 360, 110);
    anim($('#mon-art'), 'hurt', 500); heroReact('success');

    if (d.kind === 'comp') {
      const c = COMPONENTS[id];
      st.fb = { cls: 'ok', head: 'Correct', title: c.name, body: d.step.why, meta: ioMeta(c) };
      st.journal.push({ cls: 'ok', title: `✓ ${c.name}`, text: d.step.why });
    } else {
      const p = portOf(d, id);
      st.fb = { cls: 'ok', head: 'Wire connected', title: `${p[0]} · ${p[1]}`, body: d.quiz.why, meta: '' };
      st.journal.push({ cls: 'ok', title: `✓ Wire → ${p[0]} (${p[1]})`, text: d.quiz.why });
    }
    // penalties wear off as you make progress
    if (st.effects.blur) st.effects.blur--;
    if (st.effects.icon) st.effects.icon--;
    if (st.effects.locked && --st.effects.locked.turns <= 0) st.effects.locked = null;
    // streak drop
    if (st.streak % 3 === 0 && st.drops < 2) {
      st.drops++; const k = ['hint', 'potion', 'shield', 'fifty'][Math.floor(Math.random() * 4)];
      st.ls[k] = (st.ls[k] || 0) + 1;
      setTimeout(() => toast(`Streak bonus: +1 ${LS_INFO[k][0]}`, 'good'), 500);
    }
    st.decMistakes = 0; st.di++;
    updatePreview(d.kind === 'comp' ? d.step.key : (d.quiz.side === 'in' ? d.quiz.target : (st.L.wires.find(w => w.quiz === d.key) || { to: [d.quiz.target] }).to[0]));
    if (st.di >= st.decisions.length) { st.hand = []; st.selected = null; return victory(); }
    dealHand();
    renderAll();
    if (monster().frenzy) startTimer(monster().frenzy);
  }

  function onWrong(d, id) {
    st.mistakes++; st.decMistakes++; st.streak = 0;
    const snap = { health: st.health, effects: JSON.parse(JSON.stringify(st.effects)), hand: st.hand.slice(), intent: st.intent,
      timerLeft: st.timer ? st.timer.left : null, timerTotal: st.timer ? st.timer.total : null, shield: st.shield, id };
    st.hand = st.hand.filter(h => h !== id); st.selected = null;
    let title, body;
    if (d.kind === 'comp') {
      const c = COMPONENTS[id];
      title = c.name;
      body = (d.step.wrong && (d.step.wrong[id] || d.step.wrong['*'])) || `${c.name}: ${c.desc} But this slot needs ${d.step.need}.`;
      st.fb = { cls: 'bad', head: 'Not quite', title, body, meta: ioMeta(c) };
    } else {
      const p = portOf(d, id);
      title = `${p[0]} · ${p[1]}`;
      body = (d.quiz.wrong && (d.quiz.wrong[p[0]] || d.quiz.wrong['*'])) || `${p[0]} (${p[1]}) expects ${p[2]}.`;
      st.fb = { cls: 'bad', head: 'Wrong port', title, body, meta: '' };
    }
    st.journal.push({ cls: 'bad', title: `✗ ${title}`, text: body });
    monsterAttack(snap);
  }

  function monsterAttack(snap) {
    if (st.shield) {
      st.shield = false; toast('Your shield blocks the attack!', 'good');
      anim($('#mon-art'), 'attack', 550); renderAll(); return;
    }
    const intent = st.intent;
    let dmg = 1;
    anim($('#mon-art'), 'attack', 550);
    setTimeout(() => { anim($('#flash'), 'red', 500); heroReact('damage'); anim($('#p-health'), 'shake', 400); }, 220);
    switch (intent) {
      case 'damage': dmg = 2; break;
      case 'blur': st.effects.blur = 2; break;
      case 'icon': st.effects.icon = 2; break;
      case 'scramble': { const before = st.hand.join(); let n = 0; do { shuffle(st.hand); n++; } while (st.hand.join() === before && st.hand.length > 1 && n < 8); st.dealAnim = true; break; }
      case 'locked': {
        const cands = st.L.nodes.filter(n => isPlaced(n));
        if (cands.length) st.effects.locked = { node: cands[Math.floor(Math.random() * cands.length)].id, turns: 3 };
        else dmg = 2;
        break;
      }
      case 'time': startTimer(15); break;
    }
    st.health = Math.max(0, st.health - dmg);
    setTimeout(() => toast(`${monster().name}: ${ATTACK_NAME[intent]}!${dmg > 1 ? ' (-2)' : ''}`, 'bad'), 250);
    floatText($('#p-health'), `-${dmg}`, 'bad', 200, 70);
    st.snap = snap;
    rollIntent();
    renderAll();
    anim($('#mon-intent'), 'flash', 1200);
    if (st.health <= 0) setTimeout(defeat, 650);
  }

  function onTimeout() {
    clearTimer();
    if (st.over) return;
    st.mistakes++; st.streak = 0;
    if (st.shield) { st.shield = false; toast('Out of time — your shield absorbs the hit.', 'good'); }
    else {
      st.health = Math.max(0, st.health - 1);
      anim($('#mon-art'), 'attack', 550); anim($('#flash'), 'red', 500); heroReact('damage');
      toast('Too slow! The monster strikes.', 'bad'); floatText($('#p-health'), '-1', 'bad', 200, 70);
    }
    st.journal.push({ cls: 'bad', title: '✗ Out of time', text: 'Hesitation cost a heart. Lifesavers like Hint and 50/50 can speed up a tough decision.' });
    renderAll();
    if (st.health <= 0) return setTimeout(defeat, 650);
    if (monster().frenzy) startTimer(monster().frenzy);
  }

  /* ───────── Timer ───────── */
  function startTimer(sec) {
    clearTimer();
    st.timer = { total: sec, left: sec };
    st.timerInt = setInterval(() => {
      if (!st || !st.timer || modalOpen() || st.over || !$('#screen-battle').classList.contains('active')) return;
      st.timer.left -= 0.1; renderTimer();
      if (st.timer.left <= 0) onTimeout();
    }, 100);
    renderTimer(); renderEffects();
  }
  function clearTimer() {
    if (!st) return;
    clearInterval(st.timerInt); st.timerInt = null; st.timer = null; renderTimer();
  }
  function renderTimer() {
    const t = $('#timer');
    if (!st || !st.timer) { t.classList.remove('on', 'urgent'); return; }
    t.classList.add('on'); t.classList.toggle('urgent', st.timer.left < 5);
    $('#timer i').style.width = Math.max(0, st.timer.left / st.timer.total * 100) + '%';
    $('#timer b').textContent = Math.ceil(Math.max(0, st.timer.left));
  }

  /* ───────── Lifesavers ───────── */
  function canUse(k) {
    if (!st || st.over && !(k === 'second' && st.snap && !st.won)) return false;
    if (!st.ls[k]) return false;
    switch (k) {
      case 'hint': return !st.hintShown && !!cur();
      case 'potion': return st.health < st.max;
      case 'fifty': return !!cur() && wrongCards().length >= 2;
      case 'clear': return !!(st.effects.blur || st.effects.icon || st.effects.locked);
      case 'shield': return !st.shield;
      case 'second': return !!st.snap;
    }
    return false;
  }
  function useLifesaver(k) {
    if (!canUse(k)) return;
    st.ls[k]--; st.aids++;
    const d = cur();
    switch (k) {
      case 'hint': {
        st.hintShown = true;
        const txt = d.kind === 'comp' ? d.step.hint : d.quiz.hint;
        st.fb = { cls: 'hint', head: 'Hint', title: d.kind === 'comp' ? 'Looking for…' : 'Wire check', body: txt, meta: d.kind === 'comp' ? `This slot needs ${esc(d.step.need)}.` : '' };
        st.journal.push({ cls: 'aid', title: '★ Hint', text: txt });
        break;
      }
      case 'potion': st.health = Math.min(st.max, st.health + 1); toast('+1 heart', 'good'); floatText($('#p-health'), '+1', 'good', 200, 70); break;
      case 'fifty': {
        const rm = shuffle(wrongCards()).slice(0, 2);
        st.hand = st.hand.filter(h => !rm.includes(h)); if (rm.includes(st.selected)) st.selected = null;
        toast('Two wrong cards removed', 'good'); break;
      }
      case 'clear': st.effects = { blur: 0, icon: 0, locked: null }; toast('Your vision clears', 'good'); break;
      case 'shield': st.shield = true; toast('Shield raised', 'good'); break;
      case 'second': {
        const s = st.snap; st.snap = null;
        st.health = s.health; st.effects = s.effects; st.hand = s.hand; st.intent = s.intent; st.shield = s.shield;
        st.mistakes = Math.max(0, st.mistakes - 1); st.decMistakes = Math.max(0, st.decMistakes - 1);
        if (s.timerLeft == null) clearTimer();
        else { startTimer(s.timerTotal); st.timer.left = s.timerLeft; }
        if (st.over) { st.over = false; closeModal(); }
        st.fb = { cls: 'hint', head: 'Second chance', title: 'Mistake undone', body: 'Health, penalties and your hand are restored. Think it through — the explanation above still applies.', meta: '' };
        st.journal.push({ cls: 'aid', title: '↺ Second Chance', text: 'Last mistake undone.' });
        toast('Time rewinds…', 'good');
        break;
      }
    }
    renderAll();
  }

  /* ───────── Victory / defeat ───────── */
  function victory() {
    st.over = true; st.won = true; clearTimer();
    $('#mon-art').classList.add('dead');
    const L = level();
    const perfect = st.mistakes === 0 && st.aids === 0;
    const eff = Math.round(200 * st.decisions.length / Math.max(st.attempts, 1));
    const hpBonus = st.health * 50, perfBonus = perfect ? 500 : 0;
    const total = st.xp + eff + hpBonus + perfBonus;
    const stars = st.mistakes === 0 ? 3 : st.mistakes <= 2 ? 2 : 1;
    const prev = save.best[L.id] || { xp: 0, stars: 0 };
    save.best[L.id] = { xp: Math.max(prev.xp, total), stars: Math.max(prev.stars, stars) };
    save.unlocked = Math.max(save.unlocked, Math.min(LEVELS.length, st.idx + 2));
    writeSave();
    st.fb = { cls: 'ok', head: 'Definition complete', title: 'Your script runs!', body: 'Drag the sliders in the preview — the whole definition updates live. That is parametric design.', meta: '' };
    renderAll();
    const next = LEVELS[st.idx + 1];
    setTimeout(() => modal(`
      <button class="x-close">&times;</button>
      <div class="sub">${esc(monster().place)} &middot; Level ${st.idx + 1} of ${LEVELS.length}</div>
      <h2>${esc(monster().name)} is defeated!</h2>
      <div class="stars-big">${[1, 2, 3].map(i => `<span class="${i <= stars ? 'on' : ''}">★</span>`).join('')}</div>
      <p>You built a working definition: <b>${esc(L.objective)}</b></p>
      <table class="score">
        <tr><td>Correct decisions</td><td>${st.xp}</td></tr>
        <tr><td>Efficiency (${st.decisions.length} / ${st.attempts} picks)</td><td>${eff}</td></tr>
        <tr><td>Health remaining (${st.health} × 50)</td><td>${hpBonus}</td></tr>
        <tr><td>Perfect run ${perfect ? '' : '<span class="muted">(no mistakes, no lifesavers)</span>'}</td><td>${perfBonus}</td></tr>
        <tr class="total"><td>Total XP</td><td>${total}</td></tr>
      </table>
      <div class="actions">
        <button class="btn ghost" data-act="explore">Explore result</button>
        <button class="btn" data-act="map">Map</button>
        ${next ? '<button class="btn primary" data-act="next">Next level →</button>' : '<button class="btn primary" data-act="credits">Finish</button>'}
      </div>`), 1100);
  }

  function defeat() {
    if (st.won) return;
    st.over = true; clearTimer(); heroReact('defeat');
    const doneCount = st.di;
    modal(`
      <div class="sub">${esc(monster().place)}</div>
      <h2>${esc(monster().name)} wins this round</h2>${''}
      <p>Your health ran out with <b>${doneCount} of ${st.decisions.length}</b> decisions complete. Every mistake taught you something — check <b>Moves</b> for the explanations, then try again.</p>
      <div class="actions">
        ${st.snap && st.ls.second ? '<button class="btn warm" data-act="second">Use Second Chance</button>' : ''}
        <button class="btn" data-act="map">Map</button>
        <button class="btn primary" data-act="retry">Retry</button>
      </div>`);
    renderAll();
  }

  function modalAction(a) {
    switch (a) {
      case 'close': closeModal(); break;
      case 'fight': closeModal(); break;
      case 'map': clearTimer(); closeModal(); openMap(); break;
      case 'retry': closeModal(); startLevel(st.idx); break;
      case 'next': closeModal(); startLevel(st.idx + 1); break;
      case 'explore': closeModal(); break;
      case 'second': useLifesaver('second'); break;
      case 'start': closeModal(); openMap(); break;
      case 'credits': closeModal(); credits(); break;
      case 'reset': save = { best: {}, unlocked: 1 }; writeSave(); closeModal(); openMap(); break;
    }
  }

  function briefing() {
    const L = level(), m = monster();
    const mode = { guided: 'Guided — descriptions shown, the open node tells you what it needs.', standard: 'Standard — descriptions shown, no slot hints.', independent: 'Independent — card descriptions hidden. Read the icons and ports.' }[L.guidance];
    modal(`
      <div class="brief">
        <div class="art">${monsterArt(monsterKey(L))}</div>
        <div>
          <div class="sub">Level ${L.id} of ${LEVELS.length} &middot; ${esc(m.place)}</div>
          <h2>${esc(L.title)}</h2>
          <p><b>${esc(m.name)}</b> blocks the path. ${esc(m.trait)} ${esc(m.line)}</p>
          <div class="kv">
            <span>Challenge</span><div>${esc(L.objective)}</div>
            <span>You’ll learn</span><div>${esc(L.learn)}</div>
            <span>Mode</span><div>${mode}</div>
            <span>Decisions</span><div>${st.decisions.length} (${L.steps.length} components${st.decisions.length > L.steps.length ? ' + ' + (st.decisions.length - L.steps.length) + ' wire checks' : ''})</div>
          </div>
        </div>
      </div>
      <div class="actions"><button class="btn ghost" data-act="map">Back</button><button class="btn primary" data-act="fight">Fight!</button></div>`,
    () => { if (monster().frenzy && !st.over && !st.timer) startTimer(monster().frenzy); });
  }

  function credits() {
    modal(`<h2>Script Master</h2>
      <p>You defeated the Spaghetti Wyrm and built a complete parametric workflow — polygon, series, graph mapping, scale, rotate, move and loft — all driven by a handful of sliders.</p>
      <p>That chain is real Grasshopper. Open Rhino, place the same components, wire them the same way, and you’ll get the same tower.</p>
      <p class="muted">Replay levels for three stars and a higher rank, or try a perfect run without lifesavers.</p>
      <div class="actions"><button class="btn primary" data-act="map">Back to the map</button></div>`);
  }

  function helpModal() {
    modal(`<button class="x-close">&times;</button>
      <h2>How to play</h2>
      <p>Each level is a Grasshopper challenge guarded by a monster. Build the definition before it defeats you.</p>
      <h4>Each turn</h4>
      <p>1. Pick a <b>component card</b> from your hand — it appears in the featured slot.<br>
         2. Click <b>Place</b>, the glowing node, or the card again to commit.<br>
         3. <b>Wire checks</b> ask which input or output a wire should connect to — the cards become ports.<br>
         4. Read the <b>field notes</b>: every choice explains why it works (or doesn’t), what it expects and what it outputs. Watch the preview update.</p>
      <h4>Monster attacks</h4>
      <p class="muted">A wrong pick costs a heart and triggers the monster’s telegraphed <b>intent</b> (shown on its panel). Penalties wear off as you place correct components.</p>
      <table>
        <tr><td>Heavy Strike</td><td>Lose 2 hearts instead of 1.</td></tr>
        <tr><td>Blurred Vision</td><td>Component names and the preview blur for 2 placements.</td></tr>
        <tr><td>Icon Curse</td><td>Card names and descriptions vanish — only icons and ports remain.</td></tr>
        <tr><td>Scramble</td><td>Your hand is shuffled.</td></tr>
        <tr><td>Locked Component</td><td>A placed node hides its label for 3 placements.</td></tr>
        <tr><td>Time Pressure</td><td>15 seconds to decide, or take a hit.</td></tr>
      </table>
      <h4>Lifesavers</h4>
      <table>${Object.entries(LS_INFO).map(([k, v]) => `<tr><td>${v[0]}</td><td>${v[1]}</td></tr>`).join('')}
        <tr><td>Streak bonus</td><td>Every 3 correct picks in a row may award an extra lifesaver.</td></tr></table>
      <h4>Scoring</h4>
      <p>+100 XP per component (+60 per wire check), +40 for a clean first try, plus efficiency, health and a 500 XP bonus for a perfect run (no mistakes, no lifesavers).</p>
      <h4>Shortcuts</h4>
      <p class="muted">Keys 1–6 select a card &middot; Enter places it &middot; H uses a hint &middot; drag the preview to orbit, scroll to zoom, double-click to reset.</p>
      <div class="actions"><button class="btn primary" data-act="close">Got it</button></div>`);
  }

  function movesModal() {
    const j = st.journal.length ? st.journal.map(e => `<div class="je ${e.cls}"><b>${esc(e.title)}</b><p>${esc(e.text)}</p></div>`).join('') : '<p class="muted">No moves yet. Every decision you make is logged here with its explanation.</p>';
    modal(`<button class="x-close">&times;</button><div class="sub">${esc(level().title)}</div><h2>Moves &amp; field notes</h2>
      <p class="muted">${st.di} / ${st.decisions.length} decisions &middot; ${st.mistakes} mistakes &middot; ${st.aids} lifesavers used</p>
      <div class="journal">${j}</div>
      <div class="actions"><button class="btn primary" data-act="close">Back to battle</button></div>`);
  }

  /* ───────── Rendering ───────── */
  function renderAll() {
    const fx = $('#screen-battle');
    fx.classList.toggle('fx-blur', st.effects.blur > 0);
    fx.classList.toggle('fx-icon', st.effects.icon > 0);
    renderGraph(); renderHand(); renderFeatured(); renderFeedback(); renderHealth(); renderEffects(); renderMonster(); renderLifesavers(); renderTimer();
    const d = cur();
    $('#hand-sub').textContent = !d ? (st.won ? 'Definition complete' : '') : d.kind === 'quiz' ? 'Wire check — choose a port' : 'Choose a component';
  }

  function ioMeta(c) {
    const f = (arr) => arr.length ? arr.map(p => `${esc(p[0])} ${esc(p[1])}`).join(' · ') : '—';
    return `<b>In:</b> ${f(c.ins)}<br><b>Out:</b> ${f(c.outs)}`;
  }

  function renderGraph() {
    const L = level(), svg = $('#graph'), d = cur();
    const slotNum = {}; L.steps.forEach((s, i) => { slotNum[s.key] = i + 1; });
    const lockedId = st.effects.locked && st.effects.locked.node;
    const blur = st.effects.blur > 0;
    const geo = {}; let mnx = Infinity, mny = Infinity, mxx = -Infinity, mxy = -Infinity;
    // layout + bounds
    L.nodes.forEach(n => {
      const comp = COMPONENTS[n.comp], sz = chipSize(comp);
      geo[n.id] = { n, comp, ...sz, placed: isPlaced(n) };
      mnx = Math.min(mnx, n.x - sz.w / 2); mxx = Math.max(mxx, n.x + sz.w / 2);
      mny = Math.min(mny, n.y - Math.max(sz.h / 2, 24)); mxy = Math.max(mxy, n.y + Math.max(sz.h / 2, 24) + 26);
    });
    const quizCur = d && d.kind === 'quiz' ? d.quiz : null;
    const selPort = quizCur && st.selected ? +st.selected.split(':')[1] : null;

    let nodesSVG = '';
    L.nodes.forEach(n => {
      const g = geo[n.id], comp = g.comp;
      const isCur = d && d.kind === 'comp' && d.step.key === n.step;
      const filt = blur ? ' filter="url(#gblur)"' : '';
      if (g.placed) {
        const hl = quizCur && quizCur.target === n.id && selPort != null ? { hlSide: quizCur.side, hlIdx: selPort } : {};
        const p = L.params.find(pp => pp.key === n.param);
        const c = chip(comp, n.x, n.y, { label: n.label, value: n.param ? st.params[n.param] : (n.value != null ? n.value : null), frac: p ? (st.params[p.key] - p.min) / (p.max - p.min) : null,
          locked: lockedId === n.id, anim: st.lastPlaced === n.step && !n.given, ...hl });
        g.ports = c.ports;
        const name = lockedId === n.id ? '???' : (n.label && comp.id !== 'slider' ? n.label : comp.id === 'slider' ? '' : comp.name);
        nodesSVG += `<g${filt}>${c.svg}</g>`;
        if (name) nodesSVG += `<text class="g-label" x="${n.x}" y="${n.y + g.h / 2 + 13}" text-anchor="middle"${filt}>${esc(name)}</text>`;
        if (quizCur && quizCur.target === n.id) nodesSVG += `<rect x="${n.x - g.w / 2 - 5}" y="${n.y - g.h / 2 - 5}" width="${g.w + 10}" height="${g.h + 10}" rx="8" fill="none" stroke="#e8dcb0" stroke-width="1.5" stroke-dasharray="4 3"/>`;
      } else {
        const r = isCur ? 22 : 18;
        g.ports = { in: comp.ins.map(() => [n.x - r, n.y]), out: comp.outs.map(() => [n.x + r, n.y]) };
        if (isCur) {
          nodesSVG += `<g class="g-cur${st.selected ? ' armed' : ''}" data-act="place-node">
            <circle class="halo" cx="${n.x}" cy="${n.y}" r="${r + 4}"/><circle class="ring" cx="${n.x}" cy="${n.y}" r="${r}"/>
            <path class="plus" d="M${n.x - 8} ${n.y}h16M${n.x} ${n.y - 8}v16"/></g>
            <text class="g-label cur" x="${n.x}" y="${n.y + r + 16}" text-anchor="middle">Node ${pad2(slotNum[n.step])}</text>
            <line x1="${n.x - 26}" x2="${n.x + 26}" y1="${n.y + r + 21}" y2="${n.y + r + 21}" stroke="#e8dcb0" stroke-width="1"/>`;
          if (L.guidance === 'guided') nodesSVG += `<text class="g-need" x="${n.x}" y="${n.y + r + 33}" text-anchor="middle">needs ${esc(shortNeed(d.step.need))}</text>`;
        } else {
          nodesSVG += `<circle class="g-slot" cx="${n.x}" cy="${n.y}" r="${r}"/><text class="g-slot-q" x="${n.x}" y="${n.y + 5.5}" text-anchor="middle">?</text>
            <text class="g-label" x="${n.x}" y="${n.y + r + 14}" text-anchor="middle" opacity=".7">Open node</text>`;
        }
      }
    });

    let wiresSVG = '';
    const curve = (a, b) => { const dx = Math.max(24, Math.abs(b[0] - a[0]) * 0.5); return `M${a[0]} ${a[1]}C${a[0] + dx} ${a[1]} ${b[0] - dx} ${b[1]} ${b[0]} ${b[1]}`; };
    L.wires.forEach(w => {
      if (w.hideWhen && st.done.has(w.hideWhen)) return;
      const A = geo[w.from[0]], B = geo[w.to[0]];
      let a = A.ports.out[w.from[1]], b = B.ports.in[w.to[1]];
      const both = A.placed && B.placed;
      if (!both) { wiresSVG += `<path class="g-wire pending" d="${curve(a, b)}"/>`; return; }
      if (w.quiz && !st.done.has(w.quiz)) {
        const isCurQ = quizCur && quizCur.key === w.quiz;
        const unknownIn = (w.check && w.check.side === 'out' ? 'out' : 'in') === 'in';
        if (unknownIn) b = isCurQ && selPort != null ? B.ports.in[selPort] : [B.n.x - B.w / 2 - 16, B.n.y];
        else a = isCurQ && selPort != null ? A.ports.out[selPort] : [A.n.x + A.w / 2 + 16, A.n.y];
        wiresSVG += `<path class="g-wire ${isCurQ ? 'quiz' : 'quiz-future'}" d="${curve(a, b)}"/>`;
        if (isCurQ && selPort == null) { const q = unknownIn ? b : a; wiresSVG += `<circle cx="${q[0]}" cy="${q[1]}" r="7" fill="#2a4a3c" stroke="#e8dcb0"/><text x="${q[0]}" y="${q[1] + 3.5}" text-anchor="middle" font-size="10" font-weight="800" fill="#e8dcb0" font-family="Barlow">?</text>`; }
        return;
      }
      wiresSVG += `<path class="g-wire" d="${curve(a, b)}"/>`;
    });

    const pad = 18;
    // fixed zoom, centred on the active node; drag to pan
    const VW = 540, VH = 262;
    const focus = d ? (d.kind === 'comp' ? L.nodes.find(n => n.step === d.step.key) : nodeById(d.quiz.target)) : null;
    const bx0 = mnx - pad, bx1 = mxx + pad, by0 = mny - pad, by1 = mxy + pad;
    const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
    let fx = (focus ? focus.x : (bx0 + bx1) / 2) + st.pan.x, fy = (focus ? focus.y : (by0 + by1) / 2) + st.pan.y;
    fx = bx1 - bx0 <= VW ? (bx0 + bx1) / 2 : clamp(fx, bx0 + VW / 2, bx1 - VW / 2);
    fy = by1 - by0 <= VH ? (by0 + by1) / 2 : clamp(fy, by0 + VH / 2, by1 - VH / 2);
    st.pan = { x: fx - (focus ? focus.x : (bx0 + bx1) / 2), y: fy - (focus ? focus.y : (by0 + by1) / 2) };
    st.graphPannable = bx1 - bx0 > VW || by1 - by0 > VH;
    svg.style.cursor = st.graphPannable ? 'grab' : 'default';
    svg.setAttribute('viewBox', `${fx - VW / 2} ${fy - VH / 2} ${VW} ${VH}`);
    svg.innerHTML = `<defs><filter id="gblur"><feGaussianBlur stdDeviation="2.6"/></filter></defs>${wiresSVG}${nodesSVG}`;
    st.lastPlaced = null;

    // footer + subtitle
    $('#graph-sub').textContent = level().objective;
    let foot;
    if (!d) foot = st.won ? '<b>Definition complete</b> &bull; Drag the sliders in the preview to explore your result.' : '';
    else if (d.kind === 'quiz') foot = `<b>Wire check</b> &bull; ${esc(d.quiz.prompt)}`;
    else foot = `<b>Selected slot ${pad2(slotNum[d.step.key])}</b> &bull; Place a card here to extend the definition.`;
    $('#graph-foot').innerHTML = foot;
  }
  const shortNeed = (s) => s.length > 44 ? s.slice(0, 42) + '…' : s;

  function cardHTML(id, opts = {}) {
    const d = cur();
    if (id.startsWith('port:')) {
      const comp = COMPONENTS[nodeById(d.quiz.target).comp], idx = +id.split(':')[1], side = d.quiz.side, p = portOf(d, id);
      const c = chip(comp, 0, 0, { w: 150, big: true, hlSide: side, hlIdx: idx });
      return `<div class="card port" data-id="${id}">
        <div class="card-cat">Wire &middot; ${side === 'in' ? 'Input' : 'Output'}</div>
        <div class="card-tier">${esc(p[0])}</div>
        <div class="card-chip"><div class="tag">${esc(comp.name)}</div>${svgWrap(c)}</div>
        <div class="card-name">${esc(p[0])} &middot; ${esc(p[1])}</div>
        <div class="card-desc">${side === 'in' ? 'Expects' : 'Carries'} ${esc(p[2])}.</div></div>`;
    }
    const comp = COMPONENTS[id];
    const c = chip(comp, 0, 0, { w: 150, big: true, label: comp.id === 'slider' ? 'Slider' : null, value: comp.id === 'slider' ? 5 : null, frac: 0.5 });
    const showDesc = level().guidance !== 'independent' || opts.featured && false;
    return `<div class="card" data-id="${id}">
      <div class="card-cat">${esc(comp.cat)}</div>
      <div class="card-tier">${comp.tier}</div>
      <div class="card-chip"><div class="tag">${esc(comp.name)}</div>${svgWrap(c)}</div>
      <div class="card-name">${esc(comp.name)}</div>
      <div class="card-desc">${showDesc ? esc(comp.desc) : '<i>Read the icon and ports.</i>'}</div></div>`;
  }
  function svgWrap(c) {
    return `<svg viewBox="${-c.w / 2 - 7} ${-c.h / 2 - 3} ${c.w + 14} ${c.h + 6}" xmlns="http://www.w3.org/2000/svg">${c.svg}</svg>`;
  }

  function renderHand() {
    const el = $('#hand'), n = st.hand.length;
    if (!n) { el.innerHTML = ''; return; }
    const cw = 196, avail = 940;
    const step = n > 1 ? Math.min(186, (avail - cw) / (n - 1)) : 0;
    const left0 = (avail - (cw + step * (n - 1))) / 2, mid = (n - 1) / 2;
    el.innerHTML = st.hand.map(id => cardHTML(id)).join('');
    $$('.card', el).forEach((c, i) => {
      const off = i - mid, rot = off * (n > 4 ? 3.4 : 4.6), y = off * off * (n > 4 ? 3.5 : 6) + 6;
      const sel = c.dataset.id === st.selected;
      c.style.left = (left0 + i * step) + 'px'; c.style.top = '0px'; c.style.zIndex = 10 + i;
      c.style.transform = `translateY(${y - (sel ? 38 : 0)}px) rotate(${rot}deg)`;
      c.classList.toggle('selected', sel);
      if (st.dealAnim) { c.classList.add('dealing'); c.style.animationDelay = (i * 60) + 'ms'; }
      c.addEventListener('mouseenter', () => { if (!sel) c.style.transform = `translateY(${y - 22}px) rotate(${rot * 0.5}deg)`; });
      c.addEventListener('mouseleave', () => { c.style.transform = `translateY(${y - (sel ? 38 : 0)}px) rotate(${rot}deg)`; });
      c.addEventListener('click', () => { if (st.selected === c.dataset.id) place(); else select(c.dataset.id); });
    });
    st.dealAnim = false;
  }

  function renderFeatured() {
    const el = $('#featured'), d = cur();
    if (!d) {
      el.innerHTML = st.won ? `<div class="featured-empty"><b>Victory!</b>Your definition is complete. Drag the sliders in the preview to see it respond.${LEVELS[st.idx + 1] ? '<br><br><button class="btn small" id="feat-next">Next level →</button>' : ''}</div>` : '<div class="featured-empty"><b>Defeated</b>Retry from the menu.</div>';
      const nb = $('#feat-next'); if (nb) nb.onclick = () => startLevel(st.idx + 1);
      return;
    }
    if (!st.selected) {
      el.innerHTML = `<div class="featured-empty"><b>${d.kind === 'quiz' ? 'Wire check' : 'Your move'}</b>${d.kind === 'quiz' ? esc(d.quiz.prompt) : 'Choose a card from your hand to inspect it, then place it in the glowing node.'}
        ${level().guidance === 'guided' && d.kind === 'comp' ? `<div class="need">Needs ${esc(d.step.need)}.</div>` : ''}</div>`;
      return;
    }
    el.innerHTML = cardHTML(st.selected, { featured: true }) + `<button class="btn place">${d.kind === 'quiz' ? 'Connect wire ▸' : 'Place in node ▸'}</button>`;
    $('.place', el).onclick = () => place();
    $('.card', el).onclick = () => place();
  }

  function renderFeedback() {
    const f = st.fb || {}, el = $('#feedback');
    el.className = 'panel ' + (f.cls || '') + ' anim';
    el.innerHTML = `<div class="fb-h"><span>${esc(f.head || 'Field notes')}</span><span>${st.di}/${st.decisions.length}</span></div>
      <div class="fb-title">${esc(f.title || '')}</div><div class="fb-body">${esc(f.body || '')}</div>${f.meta ? `<div class="fb-meta">${f.meta}</div>` : ''}`;
    // restart animation
    void el.offsetWidth;
  }

  function renderHealth() {
    $('#hp-text').textContent = `${st.health} / ${st.max}`;
    const h = $('#hearts');
    const prev = h.dataset.hp != null ? +h.dataset.hp : st.health;
    h.className = 'hearts' + (st.max > 4 ? ' five' : '') + (st.shield ? ' shielded' : '');
    h.innerHTML = Array.from({ length: st.max }, (_, i) => `<div class="heart${i < st.health ? '' : ' empty'}${i >= st.health && i < prev ? ' lost' : ''}">${ART.heart}</div>`).join('');
    h.dataset.hp = st.health;
    $('#xp-text').textContent = st.xp;
    $('#level-chip').textContent = level().boss ? 'Boss level' : `Level ${level().id} · ${level().title}`;
  }

  function renderEffects() {
    const chips = [];
    if (st.effects.blur) chips.push(`<span class="fx-chip">Blurred · ${st.effects.blur}</span>`);
    if (st.effects.icon) chips.push(`<span class="fx-chip">Icon curse · ${st.effects.icon}</span>`);
    if (st.effects.locked) chips.push(`<span class="fx-chip">Locked node · ${st.effects.locked.turns}</span>`);
    if (st.timer) chips.push(`<span class="fx-chip">${monster().frenzy && st.timer.total === monster().frenzy ? 'Frenzy' : 'Time pressure'}</span>`);
    if (st.shield) chips.push('<span class="fx-chip good">Shielded</span>');
    if (st.snap && st.ls.second && !st.won) chips.push('<span class="fx-chip good">Second chance ready</span>');
    $('#effects').innerHTML = chips.length ? chips.join('') : '<span class="fx-chip none">No active penalties</span>';
  }

  function renderMonster() {
    const m = monster(), L = level();
    $('#mon-name').textContent = m.name; $('#mon-name').classList.toggle('long', m.name.length > 15);
    $('#mon-sub').textContent = `${m.place} · Level ${st.idx + 1} of ${LEVELS.length}`;
    $('#mon-intent').innerHTML = st.won ? 'Defeated' : `⚔ Intent: ${INTENT_TXT[st.intent]}`;
    $('#mon-hp-text').textContent = `${st.hp} / ${st.hpMax}`;
    $('#mon-hp-bar').style.width = (st.hp / st.hpMax * 100) + '%';
    const art = $('#mon-art');
    const mk = monsterKey(L);
    if (art.dataset.kind !== mk) { art.innerHTML = monsterArt(mk); art.dataset.kind = mk; }
    if (!st.won) art.classList.remove('dead');
  }

  function renderLifesavers() {
    const el = $('#lifesavers');
    el.innerHTML = Object.keys(LS_INFO).map(k => `<button class="ls${k === 'shield' && st.shield ? ' active' : ''}${k === 'second' && canUse('second') ? ' ready' : ''}" data-ls="${k}" ${canUse(k) ? '' : 'disabled'}>${ART.lsIcon(k)}<i>${st.ls[k] || 0}</i></button>`).join('');
    $$('.ls', el).forEach(b => {
      b.onclick = () => useLifesaver(b.dataset.ls);
      b.onmouseenter = () => showTip(b, `<b>${LS_INFO[b.dataset.ls][0]}</b>${LS_INFO[b.dataset.ls][1]}`);
      b.onmouseleave = hideTip;
    });
    // disabled buttons don't fire mouse events: use the wrapper
    el.onmousemove = (e) => {
      const b = document.elementsFromPoint(e.clientX, e.clientY).find(x => x.classList && x.classList.contains('ls'));
      if (b && b.disabled) { if (!tipEl || tipEl.dataset.k !== b.dataset.ls) { showTip(b, `<b>${LS_INFO[b.dataset.ls][0]}</b>${LS_INFO[b.dataset.ls][1]}${st.ls[b.dataset.ls] ? '' : '<br><i class="muted">None left this level.</i>'}`); tipEl.dataset.k = b.dataset.ls; } }
    };
    el.onmouseleave = hideTip;
  }

  function renderParams() {
    const L = level();
    $('#params').innerHTML = `<div class="ph">Sliders</div>` + L.params.map(p => `
      <label class="param"><span>${esc(p.label)}</span><input type="range" min="${p.min}" max="${p.max}" step="${p.step}" value="${st.params[p.key]}" data-k="${p.key}"><b>${G.fmt(st.params[p.key])}</b></label>`).join('');
    $$('#params input').forEach(inp => inp.addEventListener('input', () => {
      st.params[inp.dataset.k] = +inp.value; inp.nextElementSibling.textContent = G.fmt(+inp.value);
      updatePreview(); renderGraph();
    }));
    $('#preview-foot').textContent = `World XY • ${L.title} preview`;
  }

  function updatePreview(freshKey) {
    const ctx = { params: st.params, placed: (n) => n.given || st.done.has(n.id), wireActive: (w) => !w.quiz || st.done.has(w.quiz) };
    const res = Engine.evaluate(level(), ctx);
    st.results = res;
    preview.setScene(Engine.scene(level(), res, ctx), freshKey);
  }

  function floatText(host, text, cls, x, y) {
    const sr = stage.getBoundingClientRect(), hr = host.getBoundingClientRect(), k = sr.width / 1600;
    const el = document.createElement('div'); el.className = 'dmg-float ' + (cls || ''); el.textContent = text;
    el.style.left = ((hr.left - sr.left) / k + (x != null ? x : hr.width / k / 2 - 20)) + 'px';
    el.style.top = ((hr.top - sr.top) / k + (y != null ? y : hr.height / k / 2 - 20)) + 'px';
    stage.appendChild(el); setTimeout(() => el.remove(), 1150);
  }
  function anim(el, cls, ms) { el.classList.remove(cls); void el.offsetWidth; el.classList.add(cls); setTimeout(() => el.classList.remove(cls), ms); }

  /* ───────── Map ───────── */
  const MAP_POS = [[250, 270], [560, 235], [870, 270], [1180, 235], [1390, 430], [1110, 580], [790, 610], [480, 720]];
  function openMap() {
    clearTimer();
    show('screen-map');
    const xp = totalXP();
    $('#map-xp').textContent = xp; $('#map-rank').textContent = rankFor(xp);
    const pts = (LEVELS.length <= 4 ? [[270, 330], [630, 560], [990, 330], [1340, 560]] : MAP_POS).slice(0, LEVELS.length);
    let d = `M${pts[0][0]} ${pts[0][1]}`;
    for (let i = 1; i < pts.length; i++) { const a = pts[i - 1], b = pts[i]; d += ` Q${(a[0] + b[0]) / 2 + (i % 2 ? 0 : 40)} ${(a[1] + b[1]) / 2 + (i % 2 ? 60 : -40)} ${b[0]} ${b[1]}`; }
    $('#map-path').innerHTML = `<path d="${d}" fill="none" stroke="#3d5450" stroke-width="10" stroke-linecap="round"/><path d="${d}" fill="none" stroke="#a8c690" stroke-width="2.5" stroke-dasharray="2 12" stroke-linecap="round" opacity=".7"/>`;
    $('#map-nodes').innerHTML = LEVELS.map((L, i) => {
      const locked = i + 1 > save.unlocked, best = save.best[L.id], m = MONSTER_OPTIONS[monsterKey(L)];
      const isCurrent = i + 1 === save.unlocked && !best;
      return `<div class="map-node${locked ? ' locked' : ''}${isCurrent ? ' current' : ''}${L.boss ? ' boss' : ''}" data-i="${i}" style="left:${pts[i][0]}px;top:${pts[i][1]}px">
        <div class="mn-art">${monsterArt(monsterKey(L))}</div>
        ${locked ? '<span class="lock">🔒</span>' : ''}
        <div class="mn-num">${L.boss ? 'Boss' : 'Level ' + L.id} &middot; ${esc(m.name)}</div>
        <div class="mn-title">${esc(L.title)}</div>
        <div class="mn-obj">${esc(L.objective)}</div>
        <div class="mn-stars">${[1, 2, 3].map(s => `<span class="${best && s <= best.stars ? 'on' : ''}">★</span>`).join('')}${best ? ` <small class="muted" style="letter-spacing:0;font-size:11px">${best.xp} XP</small>` : ''}</div>
      </div>`;
    }).join('');
    $$('.map-node').forEach(n => n.onclick = () => {
      const i = +n.dataset.i; if (i + 1 > save.unlocked) { toast('Defeat the previous monster first', 'bad'); return; }
      startLevel(i);
    });
  }

  /* ───────── Wiring ───────── */
  $('#title-hero').innerHTML = '<img class="hero-title" src="img/hero-main.png" alt="">';
  $('#hero').innerHTML = '<img class="hero-main" src="img/hero-main.png" alt="">';
  $('#btn-start').onclick = () => { if (LEVELS.length) openMap(); else toast('Levels are still loading…'); };
  LevelLoader.loadAll().then(ls => {
    LEVELS = ls;
    $('#title-monster').innerHTML = monsterArt(monsterKey(LEVELS[LEVELS.length - 1]));
    if (/[?&]all\b/.test(location.search)) save.unlocked = LEVELS.length;
  }).catch(err => {
    console.error(err);
    modal(`<h2>Couldn’t load levels</h2><p>${esc(err.message || err)}</p>
      <p class="muted">Levels are loaded with fetch(), so the game must be served over http — e.g. <code>python -m http.server 5173 --directory web</code> — not opened as a file.</p>`);
  });
  $('#btn-title-help').onclick = helpModal;
  $('#btn-map-help').onclick = helpModal;
  $('#btn-help').onclick = helpModal;
  $('#btn-moves').onclick = movesModal;
  $('#btn-map').onclick = () => { if (st && !st.over && st.di > 0) { modal(`<h2>Leave the battle?</h2><p>Your progress in this level will be lost.</p><div class="actions"><button class="btn" data-act="close">Stay</button><button class="btn warm" data-act="map">Leave</button></div>`); } else openMap(); };
  $('#btn-reset').onclick = () => modal(`<h2>Reset progress?</h2><p>This clears all XP, stars and unlocked levels on this device.</p><div class="actions"><button class="btn" data-act="close">Cancel</button><button class="btn warm" data-act="reset">Reset</button></div>`);
  let gDrag = null;
  $('#graph').addEventListener('pointerdown', e => {
    if (!st || !st.graphPannable || e.target.closest('[data-act="place-node"]')) return;
    gDrag = { x: e.clientX, y: e.clientY, moved: false }; e.currentTarget.setPointerCapture(e.pointerId);
  });
  $('#graph').addEventListener('pointermove', e => {
    if (!gDrag) return;
    const k = 540 / e.currentTarget.getBoundingClientRect().width;
    st.pan.x -= (e.clientX - gDrag.x) * k; st.pan.y -= (e.clientY - gDrag.y) * k;
    gDrag.x = e.clientX; gDrag.y = e.clientY; renderGraph();
  });
  const gUp = () => { gDrag = null; };
  $('#graph').addEventListener('pointerup', gUp); $('#graph').addEventListener('pointercancel', gUp);
  $('#graph').addEventListener('click', e => {
    if (!e.target.closest('[data-act="place-node"]')) return;
    if (st.selected) place(); else toast('Select a card from your hand first');
  });
  $('#view-btn').onclick = (e) => { e.stopPropagation(); $('#view-menu').classList.toggle('open'); };
  $$('#view-menu button').forEach(b => b.onclick = () => {
    preview.setView(b.dataset.view); $('#view-btn').firstChild.textContent = b.textContent + ' '; $('#view-menu').classList.remove('open');
  });
  document.addEventListener('click', () => $('#view-menu').classList.remove('open'));
  document.addEventListener('keydown', e => {
    if (e.key === 'Escape' && modalOpen()) { closeModal(); return; }
    if (modalOpen() || !st || !$('#screen-battle').classList.contains('active')) return;
    if (/^[1-9]$/.test(e.key)) { const id = st.hand[+e.key - 1]; if (id) select(id); }
    else if (e.key === 'Enter' && st.selected) place();
    else if (e.key.toLowerCase() === 'h') useLifesaver('hint');
  });

  // debug hook for testing
  window.PathOGen = { startLevel, get state() { return st; }, place, select, openMap };
})();
