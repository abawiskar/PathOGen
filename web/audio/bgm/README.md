# PathOGen background music

Original synthesized music composed for this game; these files contain no Pokemon recordings or melodies.

| File | Selected version | Playback |
| --- | --- | --- |
| title.wav | Title v2 | Title and campaign map; loop |
| battle.wav | Battle Momentum v6, 168 BPM | Normal battle; loop |
| critical.wav | Critical Hybrid v5, 176 BPM | HP <= 30% (rounded down), or last heart; loop |
| defeat.wav | Defeat v3 | Defeat; once |

`js/music.js` observes the rendered screen and current game state. Restoring health restores the battle track, and Second Chance or Retry can leave defeat playback. Victory stops music for the existing victory sound effect. Browsers require a first click or key press to start sound. Hidden tabs pause music. Music defaults to 22%, with a separate persistent volume/mute control, leaving sound effects independent.

All files are 32 kHz, stereo, 16-bit PCM WAV. No build step is required.
