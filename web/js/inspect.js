/* PathOGen — testing inspector. Only loaded with ?inspect in the URL (see index.html).
 * A bar across the top jumps to any level / difficulty and steps through its definition: the game auto-places the
 * correct answers up to the chosen stage, so the graph, live preview, sliders and goal show that point in the build.
 * Nothing is saved: progress is cleared when you leave. */
(() => {
  const css = `
  #inspect-bar { position: fixed; left: 0; right: 0; top: 0; z-index: 200; display: flex; gap: 10px; align-items: center; flex-wrap: wrap;
    padding: 7px 12px; background: #0b1312ee; border-bottom: 1px solid #c9b26a; font: 600 12px Barlow, system-ui, sans-serif; color: #dfe6dc; }
  #inspect-bar b { color: #e6c35a; letter-spacing: .14em; text-transform: uppercase; font-size: 11px; }
  #inspect-bar select, #inspect-bar button, #inspect-bar input { font: inherit; background: #1c2c2a; color: #dfe6dc; border: 1px solid #3d5450; border-radius: 3px; padding: 3px 7px; }
  #inspect-bar button { cursor: pointer; } #inspect-bar button:hover { border-color: #a8c690; }
  #inspect-bar input[type=range] { width: 220px; padding: 0; accent-color: #e6c35a; }
  #inspect-bar .meta { color: #8fa29b; font-weight: 500; max-width: 520px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }`;
  const style = document.createElement('style'); style.textContent = css; document.head.appendChild(style);

  const bar = document.createElement('div'); bar.id = 'inspect-bar';
  bar.innerHTML = `<b>Inspector</b>
    <label>Level <select id="ins-level"></select></label>
    <label>Difficulty <select id="ins-diff"></select></label>
    <button id="ins-prev" title="Previous stage">&#9664;</button>
    <input type="range" id="ins-step" min="0" value="0">
    <button id="ins-next" title="Next stage">&#9654;</button>
    <span id="ins-step-label"></span>
    <button id="ins-start">Start</button><button id="ins-end">Finished</button>
    <span class="meta" id="ins-meta"></span>`;
  document.body.appendChild(bar);
  const $ = (id) => document.getElementById(id);

  function wait() {   // levels load asynchronously
    if (!window.PathOGen || !window.LEVELS || !LEVELS.length) return setTimeout(wait, 150);
    $('ins-level').innerHTML = LEVELS.map((L, i) => `<option value="${i}">${L.id} · ${L.title}</option>`).join('');
    fillDiffs(); go();
  }
  function fillDiffs() {
    const S = LEVELS[+$('ins-level').value];
    $('ins-diff').innerHTML = S.difficulties.map((d, j) => `<option value="${j}">${d.id} · ${d.name}</option>`).join('');
  }
  function go(step) {
    const i = +$('ins-level').value, d = +$('ins-diff').value;
    PathOGen.startLevel(i, d);
    document.getElementById('modal').classList.add('hidden');   // skip the briefing
    const s = PathOGen.state, n = s.decisions.length;
    $('ins-step').max = n;
    const target = step == null ? n : Math.max(0, Math.min(n, step));
    let guard = 0;
    while (s.di < target && guard++ < 200) {   // place the right answers, like a perfect player
      const dd = s.decisions[s.di];
      PathOGen.select(dd.kind === 'comp' ? dd.step.comp : 'port:' + dd.quiz.answerIdx);
      PathOGen.place();
    }
    // keep the end-of-level modal out of the way while inspecting
    setTimeout(() => document.getElementById('modal').classList.add('hidden'), 1300);
    $('ins-step').value = s.di;
    const cur = s.decisions[s.di - 1];
    $('ins-step-label').textContent = `Stage ${s.di} / ${n}`;
    $('ins-meta').textContent = (s.L.source ? s.L.source + ' · ' : '') + (s.di ? 'last placed: ' + (cur.kind === 'comp' ? COMPONENTS[cur.step.comp].name : 'wire check') : 'nothing placed yet') +
      ` · ${s.L.nodes.length} nodes, ${s.L.wires.length} wires`;
    try { localStorage.removeItem('pathogen.save.v1'); } catch (e) { /* ignore */ }
  }
  $('ins-level').onchange = () => { fillDiffs(); go(); };
  $('ins-diff').onchange = () => go();
  $('ins-step').oninput = () => go(+$('ins-step').value);
  $('ins-prev').onclick = () => go(+$('ins-step').value - 1);
  $('ins-next').onclick = () => go(+$('ins-step').value + 1);
  $('ins-start').onclick = () => go(0);
  $('ins-end').onclick = () => go();
  wait();
})();
