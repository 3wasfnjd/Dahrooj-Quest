// Preserve the recorded firework cues when regenerating the reference port.
const replacements=[
  [
    "src/reference/sounds.js",
    "import {createReferenceMusic} from './music.js';\nexport function createReferenceSounds(){let audio=null,soundAt=null,soundRef=1,sfxBus=null,music=null,musicGain=null;\nfunction sfxDest(){\n",
    "import {createReferenceMusic} from './music.js';\nimport {createFireworkAudio} from './firework-audio';\nexport function createReferenceSounds(){let audio=null,soundAt=null,soundRef=1,sfxBus=null,music=null,musicGain=null,fireworks=null;\nfunction sfxDest(){\n"
  ],
  [
    "src/reference/sounds.js",
    "function ensureAudio(){\n  if(!audio){try{audio=new (window.AudioContext||window.webkitAudioContext)()}catch(_){}}\n  else if(audio.state==='suspended') audio.resume();\n",
    "function ensureAudio(){\n  if(!audio){try{audio=new (window.AudioContext||window.webkitAudioContext)();fireworks=createFireworkAudio(audio,sfxOut);void fireworks.load();}catch(_){}}\n  else if(audio.state==='suspended') audio.resume();\n"
  ],
  [
    "src/reference/sounds.js",
    "}\nreturn {sfxDest,sfxOut,playAt,setListener,ensureAudio,thump,squeak,pew,splash,boom,whoosh,swish,chime,startPopSound,get context(){return audio;},unlock(){ensureAudio();if(audio&&!music){musicGain=audio.createGain();musicGain.gain.value=.067;musicGain.connect(audio.destination);music=createReferenceMusic(audio,musicGain);music.start();}},focus(on){if(audio)(on?audio.resume():audio.suspend()).catch(()=>{});}};}",
    "}\nfunction fireworkLaunch(){if(fireworks?.play('launch'))return true;whoosh(.35);return false;}\nfunction fireworkBurst(){if(fireworks?.play('burst'))return true;startPopSound();return false;}\nreturn {sfxDest,sfxOut,playAt,setListener,ensureAudio,thump,squeak,pew,splash,boom,whoosh,swish,chime,startPopSound,fireworkLaunch,fireworkBurst,get context(){return audio;},unlock(){ensureAudio();if(audio&&!music){musicGain=audio.createGain();musicGain.gain.value=.067;musicGain.connect(audio.destination);music=createReferenceMusic(audio,musicGain);music.start();}},focus(on){if(!on)fireworks?.clear();if(audio)(on?audio.resume():audio.suspend()).catch(()=>{});}};}\n"
  ],
  [
    "src/reference/xr-runtime.js",
    "        blast.sparks.push({m:f,p:p.clone(),v:V(0,0,0),t:0,max:.07,flash:true});}\n      at(p,()=>kind_==='bolt'?g.pew?.():kind_==='firework'?g.whoosh(.35):g.whoosh(.18));buzz(h,kind_==='bubble'?.12:.3,22);\n    }\n",
    "        blast.sparks.push({m:f,p:p.clone(),v:V(0,0,0),t:0,max:.07,flash:true});}\n      at(p,()=>kind_==='bolt'?g.pew?.():kind_==='firework'?g.fireworkLaunch():g.whoosh(.18));buzz(h,kind_==='bubble'?.12:.3,22);\n    }\n"
  ],
  [
    "src/reference/xr-runtime.js",
    "      }\n      at(p,()=>g.popSound?.());\n    }\n",
    "      }\n      at(p,()=>g.fireworkBurst());\n    }\n"
  ]
];
export function fireworkOverrides(file,source){
 for(const [path,before,after] of replacements){if(path!==file)continue;if(!source.includes(before))throw Error("Missing firework marker: "+before.slice(0,100));source=source.replace(before,after);}
 return source;
}
