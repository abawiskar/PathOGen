/* Original PathOGen music. The Music toggle also gates sound effects. */
(() => {
  'use strict';
  const base = new URL('../audio/bgm/', document.currentScript.src);
  const tracks = new Map(['title', 'battle', 'critical', 'defeat'].map(name => {
    const audio = new Audio(new URL(name + '.wav', base).href);
    audio.preload = name === 'title' ? 'auto' : 'metadata';
    audio.loop = name !== 'defeat';
    return [name, audio];
  }));
  let enabled = true, volume = .22, unlocked = false, current = null, fade = null;
  try {
    const pref = JSON.parse(localStorage.getItem('pathogen.music.v1') || '{}');
    enabled = pref.enabled !== false;
    if (Number.isFinite(pref.volume)) volume = Math.max(0, Math.min(1, pref.volume));
  } catch (_) { /* Music also works without storage. */ }
  const control = document.createElement('div');
  control.id = 'music-controls';
  control.innerHTML = '<button type="button" aria-label="Toggle background music"></button><input type="range" min="0" max="100" step="1" aria-label="Music volume" title="Music volume">';
  // lives inside the 1600x900 stage so it scales with the game and keeps its spot at any window size
  // (top-right, inside the frame and above the panels; below the modal layer, z-index 80)
  Object.assign(control.style, { position: 'absolute', right: '58px', top: '8px', zIndex: '75', display: 'flex', alignItems: 'center', gap: '8px', padding: '7px 10px', borderRadius: '8px', background: '#152823e6', color: '#ece9de', fontFamily: 'Barlow, sans-serif', fontSize: '13px' });
  const button = control.querySelector('button'), slider = control.querySelector('input');
  Object.assign(button.style, { background: 'transparent', color: 'inherit', border: '0', cursor: 'pointer', font: 'inherit', padding: '2px' });
  Object.assign(slider.style, { width: '70px', accentColor: '#a8c690' });
  (document.getElementById('stage') || document.body).append(control);
  function updateControl() {
    button.textContent = enabled ? 'Music: On' : 'Music: Off';
    button.setAttribute('aria-pressed', String(enabled));
    slider.value = String(Math.round(volume * 100));
  }
  function save() {
    try { localStorage.setItem('pathogen.music.v1', JSON.stringify({ enabled, volume })); } catch (_) {}
  }
  function pauseAll() {
    clearInterval(fade); fade = null;
    for (const audio of tracks.values()) audio.pause();
  }
  function resume() {
    if (!enabled || !unlocked || document.hidden || !current) return;
    const audio = tracks.get(current);
    if (!audio.paused || (current === 'defeat' && audio.ended)) return;
    audio.volume = volume;
    audio.play().catch(error => {
      if (error.name !== 'AbortError' && error.name !== 'NotAllowedError') console.warn('PathOGen music:', error.message);
    });
  }
  function choose(name) {
    if (name === current) return;
    pauseAll();
    current = name;
    if (!name) return;
    const audio = tracks.get(name);
    audio.currentTime = 0;
    resume();
    if (!audio.paused && name !== 'defeat') {
      audio.volume = 0;
      const started = performance.now();
      fade = setInterval(() => {
        const progress = Math.min(1, (performance.now() - started) / 180);
        audio.volume = volume * progress;
        if (progress === 1) { clearInterval(fade); fade = null; }
      }, 20);
    }
  }
  function sync() {
    const screen = document.querySelector('.screen.active')?.id;
    const state = window.PathOGen?.state;
    if (screen !== 'screen-battle') return choose('title');
    if (!state) return choose(null);
    if (state.won) return choose(null); // Let the existing victory effect finish clearly.
    if (state.over || state.health <= 0) return choose('defeat');
    choose(state.health <= Math.max(1, Math.floor(state.max * .3)) ? 'critical' : 'battle');
  }
  function unlock() { unlocked = true; sync(); resume(); }
  function setEnabled(value) {
    enabled = Boolean(value); save(); updateControl();
    window.PathOGenSound?.setEnabled(enabled);
    if (!enabled) pauseAll(); else resume();
  }
  button.addEventListener('click', () => { setEnabled(!enabled); unlock(); });
  slider.addEventListener('input', () => { unlock(); setVolume(Number(slider.value) / 100); });
  function setVolume(value) {
    if (!Number.isFinite(value)) return;
    volume = Math.max(0, Math.min(1, value));
    for (const audio of tracks.values()) audio.volume = volume;
    save(); updateControl();
  }
  document.addEventListener('pointerdown', unlock, { capture: true });
  document.addEventListener('keydown', unlock, { capture: true });
  document.addEventListener('visibilitychange', () => { if (document.hidden) pauseAll(); else { sync(); resume(); } });
  window.addEventListener('pagehide', pauseAll);
  const observer = new MutationObserver(sync);
  observer.observe(document.querySelector('#stage'), { subtree: true, childList: true, characterData: true, attributes: true, attributeFilter: ['class'] });
  window.PathOGenMusic = {
    sync, setEnabled, setVolume,
    get state() { const a = tracks.get(current); return { track: current, enabled, volume, unlocked, paused: a ? a.paused : true, loop: a ? a.loop : false }; }
  };
  window.PathOGenSound?.setEnabled(enabled);
  updateControl(); sync();
})();
