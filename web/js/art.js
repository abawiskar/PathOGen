/* PathOGen — original SVG art: monsters, hero, lifesaver icons. */

const ART = (() => {
  const eyes = (cx, cy, s = 1, gap = 30) => [cx - gap / 2, cx + gap / 2].map(x => `
    <g class="eye">
      <ellipse cx="${x}" cy="${cy}" rx="${13 * s}" ry="${17 * s}" fill="#fff" stroke="#14181a" stroke-width="${3.4 * s}"/>
      <ellipse class="pupil" cx="${x + 1.5 * s}" cy="${cy + 2 * s}" rx="${7 * s}" ry="${10 * s}" fill="#14181a"/>
      <circle cx="${x + 4 * s}" cy="${cy - 3 * s}" r="${2.6 * s}" fill="#fff"/>
    </g>`).join('');
  const leaf = (x, y, rot, c = '#9cc35a') => `<path transform="translate(${x} ${y}) rotate(${rot})" d="M0 0c6-12 22-14 28-10C22 4 8 8 0 0z" fill="${c}" stroke="#2d4a24" stroke-width="2"/>`;
  const shadow = `<ellipse cx="120" cy="205" rx="70" ry="9" fill="#000" opacity=".25"/>`;

  const monsters = {
    rootbound: () => `
      ${shadow}
      <g stroke="#3a2617" stroke-width="3" stroke-linecap="round" fill="none">
        <path d="M95 165c-10 18-30 22-55 32" /><path d="M145 165c10 18 30 22 58 30"/><path d="M110 170c-4 14-6 24-16 34"/><path d="M130 170c4 14 8 24 18 34"/>
      </g>
      <path d="M96 150c-6 20-4 36 4 52h14l-4-40zM144 150c6 20 4 36-4 52h-14l4-40z" fill="#7a5233" stroke="#3a2617" stroke-width="3"/>
      <path d="M60 120c-20 0-34 10-40 22 14-4 26-2 34 4M180 120c20 0 34 10 40 22-14-4-26-2-34 4" fill="#7a5233" stroke="#3a2617" stroke-width="3"/>
      <circle cx="120" cy="105" r="66" fill="#2e6874" stroke="#16353d" stroke-width="4"/>
      <g fill="none" stroke-linecap="round">
        <path d="M70 70c20-20 60-24 90 0s10 60-30 50-40-40-10-40" stroke="#1d4a55" stroke-width="7"/>
        <path d="M62 120c10 26 50 40 86 20" stroke="#1d4a55" stroke-width="7"/>
        <path d="M66 82c14-16 44-22 66-8M150 140c18-8 26-28 20-48" stroke="#6fb3b8" stroke-width="5"/>
        <path d="M50 105c-16-6-22 6-14 14M190 100c14-8 24 4 16 14" stroke="#3f8790" stroke-width="7"/>
      </g>
      ${leaf(60, 48, -30)}${leaf(150, 40, 20)}${leaf(178, 90, 60, '#b6d26a')}${leaf(40, 128, -120)}${leaf(168, 150, 110, '#b6d26a')}${leaf(100, 32, -70, '#88b04b')}
      <path d="M78 64l-8-12M164 70l10-10M60 150l-10 8" stroke="#d9b45a" stroke-width="4" stroke-linecap="round"/>
      ${eyes(120, 115, 1.05, 34)}`,
    mossback: () => `
      ${shadow}
      <path d="M70 175c-6 14-4 22 4 28h18l-2-26zM170 175c6 14 4 22-4 28h-18l2-26z" fill="#5a4a33" stroke="#2c241a" stroke-width="3"/>
      <path d="M40 170c0-70 36-110 80-110s80 40 80 110z" fill="#5c7d3e" stroke="#283a1b" stroke-width="4"/>
      <path d="M52 150c20-40 60-56 100-40M60 122c26-28 66-34 96-20" fill="none" stroke="#83a85a" stroke-width="6" stroke-linecap="round"/>
      <g fill="#a9c873"><circle cx="70" cy="110" r="8"/><circle cx="160" cy="96" r="10"/><circle cx="120" cy="74" r="7"/><circle cx="182" cy="140" r="6"/></g>
      <path d="M112 62c-2-16 4-26 10-30" stroke="#6b5235" stroke-width="5" fill="none"/>
      <ellipse cx="124" cy="34" rx="22" ry="12" fill="#c4553f" stroke="#5a2018" stroke-width="3"/>
      <circle cx="116" cy="30" r="3" fill="#f3d9c4"/><circle cx="130" cy="33" r="2.5" fill="#f3d9c4"/>
      <path d="M40 170h160" stroke="#283a1b" stroke-width="4"/>
      ${eyes(120, 140, 0.95, 40)}`,
    blightmoth: () => `
      ${shadow}
      <g stroke="#2a1838" stroke-width="3">
        <path d="M118 100C70 40 20 50 26 100s60 30 86 10z" fill="#7a4d9a"/>
        <path d="M122 100c48-60 98-50 92 0s-60 30-86 10z" fill="#7a4d9a"/>
        <path d="M114 118c-40 10-66 40-50 66s46 0 54-40z" fill="#5f3a7d"/>
        <path d="M126 118c40 10 66 40 50 66s-46 0-54-40z" fill="#5f3a7d"/>
      </g>
      <circle cx="62" cy="88" r="13" fill="#e2c46a" stroke="#2a1838" stroke-width="3"/><circle cx="62" cy="88" r="5" fill="#2a1838"/>
      <circle cx="178" cy="88" r="13" fill="#e2c46a" stroke="#2a1838" stroke-width="3"/><circle cx="178" cy="88" r="5" fill="#2a1838"/>
      <g fill="#d8c8ea" opacity=".75"><circle cx="40" cy="150" r="2.5"/><circle cx="196" cy="160" r="2"/><circle cx="60" cy="40" r="2"/><circle cx="200" cy="44" r="2.5"/><circle cx="30" cy="70" r="1.6"/></g>
      <ellipse cx="120" cy="125" rx="26" ry="50" fill="#3d2752" stroke="#1d1229" stroke-width="3"/>
      <path d="M110 80c-10-24-24-32-34-30M130 80c10-24 24-32 34-30" fill="none" stroke="#1d1229" stroke-width="3" stroke-linecap="round"/>
      <circle cx="76" cy="50" r="5" fill="#e2c46a"/><circle cx="164" cy="50" r="5" fill="#e2c46a"/>
      ${eyes(120, 108, 0.75, 24)}`,
    glyphleech: () => `
      ${shadow}
      <g stroke="#1e3a2c" stroke-width="3">
        <circle cx="62" cy="176" r="20" fill="#3f7d5c"/><circle cx="88" cy="160" r="25" fill="#468a66"/><circle cx="120" cy="150" r="29" fill="#4f9670"/>
        <circle cx="152" cy="132" r="33" fill="#58a17a"/>
      </g>
      <circle cx="166" cy="96" r="44" fill="#5fae84" stroke="#1e3a2c" stroke-width="4"/>
      <path d="M150 128c10 8 24 8 32 0" fill="#1e3a2c" stroke="#1e3a2c" stroke-width="4" stroke-linecap="round"/>
      <g fill="none" stroke="#d8f0a0" stroke-width="2.5" stroke-linecap="round" class="glow">
        <path d="M84 150l6-8 6 8M112 140v12M108 146h8M146 120l8 8M154 120l-8 8M60 172h6l-3 6z"/>
        <path d="M30 60l8 10M40 56v18M200 40l-8 10 8 6M206 160h10M211 155v10"/>
      </g>
      ${eyes(166, 90, 0.95, 32)}`,
    wraith: () => `
      ${shadow}
      <g class="float-cards">
        <rect x="24" y="60" width="30" height="40" rx="4" fill="#e9dfc4" stroke="#47507a" stroke-width="2.5" transform="rotate(-18 39 80)"/>
        <rect x="186" y="50" width="30" height="40" rx="4" fill="#e9dfc4" stroke="#47507a" stroke-width="2.5" transform="rotate(14 201 70)"/>
        <rect x="196" y="130" width="26" height="34" rx="4" fill="#e9dfc4" stroke="#47507a" stroke-width="2.5" transform="rotate(26 209 147)"/>
      </g>
      <path d="M60 190c0-110 20-160 60-160s60 50 60 160l-15-12-15 14-15-14-15 14-15-14-15 14-15-14z" fill="#a9b8e6" stroke="#3a4470" stroke-width="4" opacity=".95"/>
      <path d="M78 120c-20 10-34 30-36 46M162 120c20 10 34 30 36 46" fill="none" stroke="#3a4470" stroke-width="4" stroke-linecap="round"/>
      <path d="M100 130c10 10 30 10 40 0" fill="none" stroke="#3a4470" stroke-width="4" stroke-linecap="round"/>
      ${eyes(120, 92, 0.95, 36)}`,
    hexwarden: () => `
      ${shadow}
      <path d="M70 52l-16-30 30 20M170 52l16-30-30 20" fill="#8a8f95" stroke="#2a2e33" stroke-width="3"/>
      <path d="M50 190l10-130 60-20 60 20 10 130z" fill="#6c737b" stroke="#2a2e33" stroke-width="4"/>
      <path d="M62 110l116 0M58 150h124M90 60l-6 50M150 60l6 50M110 110l-4 40M140 150l4 40M80 150l-4 40" stroke="#4d535a" stroke-width="3"/>
      <rect x="100" y="150" width="40" height="32" rx="5" fill="#d8b552" stroke="#2a2e33" stroke-width="3"/>
      <path d="M108 150v-10a12 12 0 0 1 24 0v10" fill="none" stroke="#2a2e33" stroke-width="5"/>
      <circle cx="120" cy="164" r="4" fill="#2a2e33"/><path d="M120 166v8" stroke="#2a2e33" stroke-width="3"/>
      <rect x="84" y="78" width="72" height="34" rx="6" fill="#2a2e33"/>
      <ellipse cx="104" cy="95" rx="9" ry="7" fill="#f2c94c" class="glow"/><ellipse cx="136" cy="95" rx="9" ry="7" fill="#f2c94c" class="glow"/>`,
    branchmaw: () => `
      ${shadow}
      <path d="M80 200c-4-50 10-80 40-90s46 40 40 90z" fill="#6b5235" stroke="#2f2416" stroke-width="4"/>
      <g fill="none" stroke="#6b5235" stroke-width="16" stroke-linecap="round">
        <path d="M110 120c-20-20-40-30-58-40"/><path d="M120 115c0-30 0-50 0-64"/><path d="M130 120c20-20 40-30 58-40"/>
      </g>
      <g fill="none" stroke="#2f2416" stroke-width="3"><path d="M110 112c-20-20-40-30-58-40M120 108V48M130 112c20-20 40-30 58-40"/></g>
      ${[[50, 76], [120, 46], [190, 76]].map(([x, y], i) => `
        <circle cx="${x}" cy="${y}" r="27" fill="${['#4f8a4a', '#5d9a52', '#4f8a4a'][i]}" stroke="#203b1d" stroke-width="3.5"/>
        <path d="M${x - 14} ${y + 12}c6 6 22 6 28 0" fill="none" stroke="#203b1d" stroke-width="3" stroke-linecap="round"/>
        ${leaf(x - 6, y - 26, -80, '#a8cf6a')}
        <ellipse cx="${x - 8}" cy="${y - 2}" rx="6" ry="8" fill="#fff" stroke="#111" stroke-width="2.4"/><ellipse cx="${x - 7}" cy="${y}" rx="3" ry="5" fill="#111"/>
        <ellipse cx="${x + 8}" cy="${y - 2}" rx="6" ry="8" fill="#fff" stroke="#111" stroke-width="2.4"/><ellipse cx="${x + 9}" cy="${y}" rx="3" ry="5" fill="#111"/>`).join('')}
      <g fill="#d8e8b0" font-family="Barlow,sans-serif" font-size="11" font-weight="700"><text x="20" y="128">{0}</text><text x="104" y="104">{1}</text><text x="190" y="128">{2}</text></g>`,
    wyrm: () => `
      ${shadow}
      <g fill="none" stroke-linecap="round">
        <path d="M30 180c30-70 80 20 110-40s70-30 70 20-60 40-90 0" stroke="#7a1f2b" stroke-width="16"/>
        <path d="M30 180c30-70 80 20 110-40s70-30 70 20-60 40-90 0" stroke="#c23a4b" stroke-width="9"/>
        <path d="M40 120c40 40 100-60 150 0M20 150c60-30 120 60 200 10" stroke="#e6c35a" stroke-width="3.5" stroke-dasharray="1 9"/>
        <path d="M50 200c20-30 60-10 80-30M150 205c10-30 40-20 60-40" stroke="#8a2a36" stroke-width="7"/>
      </g>
      <g fill="#f4ecd6" stroke="#4a1018" stroke-width="2.5">
        <circle cx="30" cy="180" r="6"/><circle cx="140" cy="140" r="6"/><circle cx="210" cy="160" r="6"/><circle cx="120" cy="180" r="6"/><circle cx="50" cy="200" r="5"/><circle cx="210" cy="165" r="0"/>
      </g>
      <path d="M90 40c-6-16 0-30 0-30l14 16 16-20 16 20 14-16s6 14 0 30z" fill="#e6c35a" stroke="#5a3d10" stroke-width="3"/>
      <ellipse cx="120" cy="82" rx="58" ry="46" fill="#b8323f" stroke="#4a1018" stroke-width="4"/>
      <path d="M82 104c10 18 66 18 76 0" fill="#4a1018"/>
      <path d="M92 106l6 9 6-8 6 9 6-9 6 9 6-9 6 8 6-9" fill="#f4ecd6" stroke="#4a1018" stroke-width="1.5"/>
      ${eyes(120, 72, 0.95, 40)}`,
  };

  function monster(kind) {
    return `<svg viewBox="0 0 240 220" xmlns="http://www.w3.org/2000/svg" class="monster-svg">${(monsters[kind] || monsters.rootbound)()}</svg>`;
  }

  function hero() {
    return `<svg viewBox="0 0 300 260" xmlns="http://www.w3.org/2000/svg" class="hero-svg">
      <ellipse cx="140" cy="248" rx="100" ry="10" fill="#000" opacity=".3"/>
      <g class="hero-spear">
        <path d="M238 250L282 38" stroke="#3b2a1c" stroke-width="9" stroke-linecap="round"/>
        <path d="M238 250L282 38" stroke="#8a6a48" stroke-width="5" stroke-linecap="round"/>
        <path d="M276 46l14-36 2 40z" fill="#bfe0d0" stroke="#24423a" stroke-width="3" stroke-linejoin="round"/>
        <path d="M268 74l26 6" stroke="#24423a" stroke-width="4" stroke-linecap="round"/>
      </g>
      <path d="M70 250c-10-60 0-100 70-110 60 4 80 50 70 110z" fill="#7a5a3e" stroke="#2c1f14" stroke-width="5"/>
      <path d="M190 170c20-10 36-34 54-70" stroke="#2c1f14" stroke-width="22" stroke-linecap="round" fill="none"/>
      <path d="M190 170c20-10 36-34 54-70" stroke="#7a5a3e" stroke-width="14" stroke-linecap="round" fill="none"/>
      <circle cx="248" cy="96" r="13" fill="#f0c9a0" stroke="#2c1f14" stroke-width="4"/>
      <path d="M86 196c-20 10-40 8-58 0" stroke="#2c1f14" stroke-width="22" stroke-linecap="round" fill="none"/>
      <path d="M86 196c-20 10-40 8-58 0" stroke="#7a5a3e" stroke-width="14" stroke-linecap="round" fill="none"/>
      <path d="M96 146c20 16 70 16 90 0l-6 24c-24 12-54 12-78 0z" fill="#3f8f8a" stroke="#1b3d3b" stroke-width="4"/>
      <circle cx="140" cy="108" r="40" fill="#f0c9a0" stroke="#2c1f14" stroke-width="5"/>
      <circle cx="126" cy="112" r="4.5" fill="#2c1f14"/><circle cx="156" cy="112" r="4.5" fill="#2c1f14"/>
      <path d="M132 130c6 4 14 4 20 0" stroke="#2c1f14" stroke-width="3.5" fill="none" stroke-linecap="round"/>
      <path d="M94 100c0-34 20-54 46-54s48 20 48 54z" fill="#9a7650" stroke="#2c1f14" stroke-width="5"/>
      <path d="M84 102h112" stroke="#2c1f14" stroke-width="10" stroke-linecap="round"/>
      <path d="M84 102h112" stroke="#b08a5e" stroke-width="5" stroke-linecap="round"/>
      <path d="M116 60c10-6 26-8 36-4" stroke="#c9a77a" stroke-width="4" fill="none" stroke-linecap="round"/>
    </svg>`;
  }

  const lifesaver = {
    hint: '<path d="M9 18h6M10 21h4"/><path d="M12 3a6 6 0 0 0-3.5 10.9c.7.5 1 1.2 1 2.1h5c0-.9.3-1.6 1-2.1A6 6 0 0 0 12 3z"/>',
    potion: '<path d="M10 3h4M10.5 3v5L5.6 17a3 3 0 0 0 2.7 4h7.4a3 3 0 0 0 2.7-4L13.5 8V3"/><path d="M7.5 14h9" /><path d="M12 15.5v3M10.5 17h3"/>',
    fifty: '<text x="12" y="15.5" text-anchor="middle" font-size="9" font-weight="800" fill="currentColor" stroke="none" font-family="Barlow,sans-serif">50/50</text><rect x="2.5" y="5" width="19" height="14" rx="3"/>',
    clear: '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
    shield: '<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/><path d="M9 12l2 2 4-4"/>',
    second: '<path d="M3 12a9 9 0 1 0 3-6.7"/><path d="M3 4v5h5"/><path d="M12 8v4l3 2"/>',
  };
  const lsIcon = (k) => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${lifesaver[k]}</svg>`;
  const heart = `<svg viewBox="0 0 24 24"><path d="M12 21s-7.5-4.6-9.5-9.6C1.2 8 3.3 4.5 6.8 4.5c2.1 0 3.8 1.2 5.2 3 1.4-1.8 3.1-3 5.2-3 3.5 0 5.6 3.5 4.3 6.9C19.5 16.4 12 21 12 21z"/></svg>`;

  return { monster, hero, lsIcon, heart };
})();
