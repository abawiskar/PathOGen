/* PathOGen — monsters.
 *
 * Each level names its monster with "monster" in its level.json (a key below).
 * `img` is artwork from Images/Monster (web-sized copy in web/img); `art` falls back to a built-in SVG.
 * Attacks escalate with the level's position on the path (MONSTER_PHASES), whichever monster it is.
 * `intents` are weighted attacks rolled after each mistake; `frenzy` times every decision (seconds).
 * Add ?monster=<key> to the URL to preview one monster on every level.
 */
const MONSTER_OPTIONS = {
  tower: {
    name: 'The Twisted Tower', img: 'img/monster-tower.png' /* Images/Monster/Twisted Tower Monster_v3.png */, place: 'The Skyline',
    trait: 'A tower that twisted itself out of shape. It wants your definition to collapse the same way.',
  },
  spaghetti: {
    name: 'The Spaghetti Boss', img: 'img/monster-spaghetti.png', place: 'The Tangle',
    trait: 'A knot of crossed wires and orphaned components — every messy definition ever made.',
  },
  tree: {
    name: 'The Branch Tree', img: 'img/monster-tree.png', place: 'The Data Grove',
    trait: 'It grows a new branch for every item you forget to flatten.',
  },
  voronoi: {
    name: 'The Voronoi Golem', img: 'img/monster-voronoi.png' /* Images/Monster/voronoi_v1.png */, place: 'The Cell Quarry',
    trait: 'A body of cells grown around stolen points. Feed it the wrong points and it only gets bigger.',
  },
  /* fallback for a level whose monster key is unknown */
  placeholder: {
    name: 'The Blightmoth', art: 'blightmoth', place: 'Dusk Hollow', placeholder: true,
    trait: 'Its dust blurs names and smears your preview.',
  },
};

/* Attack set by level position (the last one repeats if there are more levels). */
const MONSTER_PHASES = [
  { line: 'Slow and clumsy — it only knows how to hit.', intents: { hit: 1 } },
  { line: 'It throws your cards around and blurs your vision.', intents: { hit: 2, scramble: 1, blur: 1 } },
  { line: 'It fights dirty: blurring names, stealing words, locking your nodes.', intents: { hit: 1, blur: 2, icon: 2, locked: 1 } },
  { line: 'The last guardian. It uses every trick there is.', intents: { damage: 2, blur: 1, icon: 1, scramble: 1, locked: 1, time: 1 } },
];
