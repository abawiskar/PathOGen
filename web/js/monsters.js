/* PathOGen — monsters. `intents` are weighted attacks rolled after each mistake; `frenzy` times every decision (seconds). */
const MONSTERS = {
  rootbound: { name: 'The Rootbound', place: 'Tangled Grove', art: 'rootbound', intents: { hit: 1 },
    trait: 'Slow and clumsy. It only knows how to hit.' },
  mossback: { name: 'Mossback', place: 'Moss Hollow', art: 'mossback', intents: { hit: 2, scramble: 2 },
    trait: 'Rolls through your hand, scrambling your cards.' },
  blightmoth: { name: 'Blightmoth', place: 'Dusk Hollow', art: 'blightmoth', intents: { blur: 3, hit: 1 },
    trait: 'Its dust blurs component names and your preview.' },
  glyphleech: { name: 'Glyph Leech', place: 'Rune Marsh', art: 'glyphleech', intents: { icon: 3, blur: 1, hit: 1 },
    trait: 'Drinks the words off your cards, leaving only icons.' },
  wraith: { name: 'Shuffle Wraith', place: 'Mirror Halls', art: 'wraith', intents: { scramble: 2, locked: 2, hit: 1 },
    trait: 'Shuffles your hand and hides the labels of placed nodes.' },
  hexwarden: { name: 'Hexwarden', place: 'Lockstone Keep', art: 'hexwarden', intents: { locked: 2, icon: 1, time: 2, damage: 1 },
    trait: 'Locks your nodes and puts you on the clock.' },
  branchmaw: { name: 'Branchmaw', place: 'Canopy of Branches', art: 'branchmaw', intents: { scramble: 1, blur: 1, locked: 1, time: 1, damage: 1, hit: 1 },
    trait: 'A many-headed tangle of data branches. Expect anything.' },
  wyrm: { name: 'The Spaghetti Wyrm', place: 'The Tangle', art: 'wyrm', intents: { damage: 2, blur: 1, icon: 1, scramble: 1, locked: 1, time: 1 }, frenzy: 35,
    trait: 'Boss. Every decision is timed, and it uses every trick.' },
};
