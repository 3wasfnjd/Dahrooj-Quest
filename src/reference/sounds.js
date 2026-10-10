/* Aboden Games reference implementation, owner-authorized complete port 2026-10-08. See COMPLETE-REFERENCE-PORT-AR.md. */
import {createReferenceMusic} from './music.js';
import {createFireworkAudio} from './firework-audio';
export function createReferenceSounds(){let audio=null,soundAt=null,soundRef=1,sfxBus=null,music=null,musicGain=null,fireworks=null;
function sfxDest(){
  if(sfxBus&&sfxBus.context===audio) return sfxBus;
  const g=audio.createGain(); g.gain.value=2.2;
  const lim=audio.createDynamicsCompressor(); lim.threshold.value=-8; lim.knee.value=6; lim.ratio.value=12; lim.attack.value=.003; lim.release.value=.15;
  g.connect(lim).connect(audio.destination); sfxBus=g; return g;
}
function sfxOut(){
  if(!soundAt||!audio||!audio.createPanner) return sfxDest();
  const p=audio.createPanner();
  p.panningModel='HRTF'; p.distanceModel='inverse'; p.refDistance=soundRef; p.rolloffFactor=1; p.maxDistance=1e4;
  if(p.positionX){ p.positionX.value=soundAt.x; p.positionY.value=soundAt.y; p.positionZ.value=soundAt.z; } else p.setPosition(soundAt.x,soundAt.y,soundAt.z);
  p.connect(sfxDest()); return p;
}
function playAt(pos,fn){ const prev=soundAt; soundAt=pos; try{ return fn(); } finally{ soundAt=prev; } }
function setListener(pos,fwd,up,ref){
  if(!audio) return; const L=audio.listener; soundRef=ref||1;
  if(L.positionX){ L.positionX.value=pos.x; L.positionY.value=pos.y; L.positionZ.value=pos.z;
    L.forwardX.value=fwd.x; L.forwardY.value=fwd.y; L.forwardZ.value=fwd.z; L.upX.value=up.x; L.upY.value=up.y; L.upZ.value=up.z; }
  else { L.setPosition(pos.x,pos.y,pos.z); L.setOrientation(fwd.x,fwd.y,fwd.z,up.x,up.y,up.z); }
}
function ensureAudio(){
  if(!audio){try{audio=new (window.AudioContext||window.webkitAudioContext)();fireworks=createFireworkAudio(audio,sfxOut);}catch(_){}}
  else if(audio.state==='suspended') audio.resume();
}
function thump(s){
  if(!audio) return;
  const t=audio.currentTime, o=audio.createOscillator(), g=audio.createGain();
  o.type='sine'; o.frequency.setValueAtTime(170+s*60,t); o.frequency.exponentialRampToValueAtTime(55,t+.14);
  g.gain.setValueAtTime(0.0001,t); g.gain.exponentialRampToValueAtTime(0.05+s*0.28,t+.006); g.gain.exponentialRampToValueAtTime(0.0001,t+.2);
  o.connect(g).connect(sfxOut()); o.start(t); o.stop(t+.22);
}
function squeak(pitch=1){
  if(!audio) return;
  const t=audio.currentTime;
  for(const [d,f0,f1] of [[0,520,980],[.09,700,1250]]){
    const o=audio.createOscillator(), g=audio.createGain(), lfo=audio.createOscillator(), lg=audio.createGain();
    o.type='sine'; o.frequency.setValueAtTime(f0*pitch,t+d); o.frequency.exponentialRampToValueAtTime(f1*pitch,t+d+.08);
    lfo.frequency.value=38; lg.gain.value=30*pitch; lfo.connect(lg).connect(o.frequency);
    g.gain.setValueAtTime(.0001,t+d); g.gain.exponentialRampToValueAtTime(.09,t+d+.012); g.gain.exponentialRampToValueAtTime(.0001,t+d+.11);
    o.connect(g).connect(sfxOut()); o.start(t+d); o.stop(t+d+.12); lfo.start(t+d); lfo.stop(t+d+.12);
  }
}
function pew(){
  if(!audio) return;
  const t=audio.currentTime, out=sfxOut(), o=audio.createOscillator(), g=audio.createGain();
  o.type='square'; o.frequency.setValueAtTime(1500,t); o.frequency.exponentialRampToValueAtTime(220,t+0.12);
  g.gain.setValueAtTime(0.0001,t); g.gain.exponentialRampToValueAtTime(0.06,t+0.004); g.gain.exponentialRampToValueAtTime(0.0001,t+0.13);
  o.connect(g).connect(out); o.start(t); o.stop(t+0.14);
  const n=Math.floor(audio.sampleRate*0.05), buf=audio.createBuffer(1,n,audio.sampleRate), d=buf.getChannelData(0);
  for(let i=0;i<n;i++) d[i]=(Math.random()*2-1)*Math.pow(1-i/n,3);
  const src=audio.createBufferSource(), f=audio.createBiquadFilter(), g2=audio.createGain();
  src.buffer=buf; f.type='highpass'; f.frequency.value=1800; g2.gain.value=0.12; src.connect(f).connect(g2).connect(out); src.start(t);
}
function splash(k=0.5){
  if(!audio) return;
  const t=audio.currentTime, out=sfxOut(), n=Math.floor(audio.sampleRate*.45), buf=audio.createBuffer(1,n,audio.sampleRate), d=buf.getChannelData(0);
  for(let i=0;i<n;i++) d[i]=(Math.random()*2-1)*Math.pow(1-i/n,3);
  const src=audio.createBufferSource(), f=audio.createBiquadFilter(), g=audio.createGain();
  src.buffer=buf; f.type='bandpass'; f.Q.value=.8; f.frequency.setValueAtTime(1800,t); f.frequency.exponentialRampToValueAtTime(500,t+.35);
  g.gain.setValueAtTime(.06+k*.16,t); src.connect(f).connect(g).connect(out); src.start(t);
  for(const [d0,f0] of [[.06,380],[.16,520]]){ const o=audio.createOscillator(), og=audio.createGain();
    o.type='sine'; o.frequency.setValueAtTime(f0,t+d0); o.frequency.exponentialRampToValueAtTime(f0*2.6,t+d0+.07);
    og.gain.setValueAtTime(.0001,t+d0); og.gain.exponentialRampToValueAtTime(.05+k*.04,t+d0+.008); og.gain.exponentialRampToValueAtTime(.0001,t+d0+.09);
    o.connect(og).connect(out); o.start(t+d0); o.stop(t+d0+.1); }
}
function boom(){
  if(!audio) return;
  const t=audio.currentTime, n=Math.floor(audio.sampleRate*.7), buf=audio.createBuffer(1,n,audio.sampleRate), d=buf.getChannelData(0);
  for(let i=0;i<n;i++) d[i]=(Math.random()*2-1)*Math.pow(1-i/n,2.5);
  const src=audio.createBufferSource(), f=audio.createBiquadFilter(), g=audio.createGain();
  src.buffer=buf; f.type='lowpass'; f.frequency.setValueAtTime(1400,t); f.frequency.exponentialRampToValueAtTime(90,t+.6);
  g.gain.setValueAtTime(.42,t); g.gain.exponentialRampToValueAtTime(.0001,t+.7);
  src.connect(f).connect(g).connect(sfxOut()); src.start(t);
  thump(1);
}
function whoosh(p){
  if(!audio) return;
  const t=audio.currentTime, o=audio.createOscillator(), g=audio.createGain();
  o.type='triangle'; o.frequency.setValueAtTime(220,t); o.frequency.exponentialRampToValueAtTime(420+p*500,t+.12);
  g.gain.setValueAtTime(0.0001,t); g.gain.exponentialRampToValueAtTime(0.05,t+.01); g.gain.exponentialRampToValueAtTime(0.0001,t+.16);
  o.connect(g).connect(sfxOut()); o.start(t); o.stop(t+.18);
}
function swish(){
  if(!audio) return;
  const t=audio.currentTime, len=0.35, buf=audio.createBuffer(1,Math.floor(audio.sampleRate*len),audio.sampleRate), d=buf.getChannelData(0);
  for(let i=0;i<d.length;i++) d[i]=(Math.random()*2-1)*Math.pow(1-i/d.length,2);
  const src=audio.createBufferSource(), f=audio.createBiquadFilter(), g=audio.createGain();
  src.buffer=buf; f.type='bandpass'; f.frequency.value=1800; f.Q.value=0.7; g.gain.value=0.12;
  src.connect(f).connect(g).connect(sfxOut()); src.start(t);
}
function chime(){
  if(!audio) return;
  [659,880,1175].forEach((f,i)=>{ const t=audio.currentTime+i*0.08, o=audio.createOscillator(), g=audio.createGain();
    o.type='triangle'; o.frequency.value=f; g.gain.setValueAtTime(0.0001,t); g.gain.exponentialRampToValueAtTime(0.07,t+0.01); g.gain.exponentialRampToValueAtTime(0.0001,t+0.3);
    o.connect(g).connect(sfxDest()); o.start(t); o.stop(t+0.32); });
}
function startPopSound(){
  if(!audio || audio.state!=='running') return;
  const t=audio.currentTime,o=audio.createOscillator(),g=audio.createGain();
  o.type='sine';o.frequency.setValueAtTime(780,t);o.frequency.exponentialRampToValueAtTime(140,t+.09);
  g.gain.setValueAtTime(.065,t);g.gain.exponentialRampToValueAtTime(.0001,t+.1);
  o.connect(g).connect(sfxOut());o.start(t);o.stop(t+.11);
}
function fireworkLaunch(){if(fireworks?.play('launch'))return true;whoosh(.35);return false;}
function fireworkBurst(){if(fireworks?.play('burst'))return true;startPopSound();return false;}
return {sfxDest,sfxOut,playAt,setListener,ensureAudio,thump,squeak,pew,splash,boom,whoosh,swish,chime,startPopSound,fireworkLaunch,fireworkBurst,get context(){return audio;},unlock(){ensureAudio();if(audio&&!music){musicGain=audio.createGain();musicGain.gain.value=.067;musicGain.connect(audio.destination);music=createReferenceMusic(audio,musicGain);music.start();}},focus(on){if(!on)fireworks?.clear();if(audio)(on?audio.resume():audio.suspend()).catch(()=>{});}};}
