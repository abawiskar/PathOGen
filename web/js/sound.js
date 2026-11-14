/* Native WAV playback shared by mouse and keyboard game actions. */
(() => {
'use strict';
let enabled=true, volume=.85;
const base=new URL('../audio/',document.currentScript.src);
const names=['click','card_select','component_place','wire_connect','correct','incorrect','monster_attack','player_damage','victory'];
const pools=new Map(names.map(name=>[name,Array.from({length:4},()=>{const a=new Audio(new URL((name === 'player_damage' ? 'player_damage_v3' : ['incorrect','monster_attack'].includes(name) ? name+'_v2' : name)+'.wav',base).href);a.preload='auto';return a;})]));
const pending=new Set(); let unlocked=false;
function unlock(){if(unlocked)return;unlocked=true;for(const pool of pools.values())for(const a of pool){a.muted=true;const p=a.play();if(p)p.then(()=>{if(!a.muted)return;a.pause();a.currentTime=0;a.muted=false;}).catch(()=>{a.muted=false;});}}
function play(name,delay=0){if(!enabled)return;if(delay){const timer=setTimeout(()=>{pending.delete(timer);play(name);},delay);pending.add(timer);return;}const pool=pools.get(name);if(!pool)return;const a=pool.find(v=>v.paused||v.ended);if(!a)return;a.muted=false;a.volume=volume;a.currentTime=0;const p=a.play();if(p)p.catch(e=>console.warn('PathOGen audio:',name,e.name,e.message));}
function stop(){for(const t of pending)clearTimeout(t);pending.clear();for(const pool of pools.values())for(const a of pool){a.pause();a.currentTime=0;}}
window.PathOGenSound={play,click:()=>play('click'),stop,setEnabled(v){enabled=Boolean(v);if(!enabled)stop();},setVolume(v){if(Number.isFinite(v))volume=Math.max(0,Math.min(1,v));}};
document.addEventListener('pointerdown',unlock,{once:true,capture:true});
document.addEventListener('keydown',unlock,{once:true,capture:true});
document.addEventListener('click',e=>{const b=e.target instanceof Element&&e.target.closest('button,[role="button"]');if(!b||b.matches(':disabled,[aria-disabled="true"]')||b.closest('[inert],[aria-disabled="true"]')||b.matches('.place'))return;play('click');},true);
})();
