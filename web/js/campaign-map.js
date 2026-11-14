/* Campaign presentation only; stage data, unlock rules and battles stay in game.js. */
(() => {
  const screen = document.querySelector('#screen-map');
  const nodes = document.querySelector('#map-nodes');
  const svg = document.querySelector('#map-path');
  const ns = 'http://www.w3.org/2000/svg';
  const land = document.createElementNS(ns, 'svg');
  land.setAttribute('viewBox', '0 0 1600 900');
  land.classList.add('campaign-land');
  land.setAttribute('aria-hidden', 'true');
  land.innerHTML = `<path class="continent" d="M85 330L130 250 220 264 280 190 370 210 405 270 520 245 595 200 690 225 750 190 850 240 960 210 1040 255 1140 205 1190 170 1260 205 1350 190 1435 260 1490 280 1470 355 1520 425 1470 480 1490 550 1410 590 1360 655 1270 640 1200 685 1130 620 1030 660 930 615 850 660 750 620 665 665 585 615 490 645 435 580 335 600 280 550 200 570 165 495 95 465 115 400Z"/><path class="regions" d="M405 270L380 350 435 410 395 490 435 580M750 190L710 300 770 385 720 470 750 620M1040 255L990 345 1065 440 1010 530 1030 660M1260 205L1220 340 1300 445 1230 550 1270 640"/>`;
  screen.insertBefore(land, svg);
  const detail = document.createElement('div');
  detail.className = 'campaign-detail';
  detail.setAttribute('aria-live', 'polite');
  screen.append(detail);
  const progress = document.createElement('div');
  progress.className = 'campaign-progress';
  screen.append(progress);

  function refresh() {
    const items = [...nodes.querySelectorAll('.map-node')];
    if (!items.length) return;
    const pts = items.map((_, i) => [210 + i * (1180 / Math.max(1, items.length - 1)), 390 + (i % 2 ? 95 : -20)]);
    let route = '';
    for (let i = 1; i < pts.length; i++) {
      const a = pts[i - 1], b = pts[i];
      route += `<path class="campaign-route${items[i].classList.contains('locked') ? ' future' : ''}" d="M${a[0]} ${a[1]} C${(a[0]+b[0])/2} ${a[1]},${(a[0]+b[0])/2} ${b[1]},${b[0]} ${b[1]}"/>`;
    }
    svg.innerHTML = route;
    function select(node) {
      items.forEach(n => { n.classList.toggle('selected', n === node); n.setAttribute('aria-pressed', String(n === node)); });
      const locked = node.classList.contains('locked');
      const title = node.querySelector('.mn-title').textContent;
      const objective = node.querySelector('.mn-obj').textContent;
      const monster = node.querySelector('.mn-num').textContent;
      detail.replaceChildren();
      const text = document.createElement('div'); text.className = 'campaign-summary';
      const heading = document.createElement('h3'); heading.textContent = title;
      const desc = document.createElement('p'); desc.textContent = objective;
      text.append(heading, desc);
      const info = document.createElement('div'); info.className = 'campaign-info';
      const label = document.createElement('span'); label.textContent = monster;
      const status = document.createElement('p'); status.textContent = locked ? 'Defeat the previous monster to unlock' : 'Choose your difficulty and build the script';
      info.append(label, status);
      const button = document.createElement('button'); button.className = 'btn primary campaign-challenge';
      button.textContent = locked ? 'Locked' : 'Challenge \u2192'; button.disabled = locked;
      button.onclick = () => node._campaignLaunch?.();
      detail.append(text, info, button);
    }
    items.forEach((node, i) => {
      node._campaignLaunch = node.onclick;
      node.style.left = pts[i][0] + 'px'; node.style.top = pts[i][1] + 'px';
      node.setAttribute('role', 'button'); node.tabIndex = 0;
      const marker = document.createElement('span'); marker.className = 'campaign-marker'; marker.textContent = String(i + 1).padStart(2, '0');
      const completed = !!node.querySelector('.mn-stars .on');
      if (completed) node.classList.add('completed');
      node.prepend(marker);
      const art = node.querySelector('.mn-art');
      if (art) art.innerHTML = '<img class="campaign-hero" src="img/hero-main.png" alt="Hero">';
      node.onclick = () => select(node);
      node.onkeydown = event => { if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); select(node); } };
      const lock = node.querySelector('.lock'); if (lock) lock.innerHTML = '&#128274;';
    });
    progress.textContent = `${String(items.filter(n => n.classList.contains('completed')).length).padStart(2, '0')} / ${String(items.length).padStart(2, '0')} CLEARED`;
    select(items.find(n => n.classList.contains('current')) || items.find(n => !n.classList.contains('locked')) || items[0]);
  }
  new MutationObserver(refresh).observe(nodes, { childList: true });
  refresh();
})();
