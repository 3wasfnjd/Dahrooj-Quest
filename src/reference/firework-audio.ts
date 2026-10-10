export type FireworkCue='launch'|'burst';
export const FIREWORK_SECONDS={launch:.24,burst:.72} as const;
/** Original synthesis: a short rising air whistle and a separate impact/crackle tail. */
export function synthesizeFirework(cue:FireworkCue,sampleRate:number,seed=1){
 const duration=FIREWORK_SECONDS[cue],samples=new Float32Array(Math.ceil(sampleRate*duration));
 let state=seed||1,low=0,phase=0;
 for(let i=0;i<samples.length;i++){
  state=(Math.imul(state,1664525)+1013904223)>>>0;
  const noise=state/2147483648-1,t=i/sampleRate,p=t/duration;
  low+=(noise-low)*(1-Math.exp(-2*Math.PI*1900/sampleRate));
  const fade=Math.min(1,t/.003)*Math.min(1,(duration-t)/.02);
  if(cue==='launch'){
   phase+=2*Math.PI*(650+1550*p*p)/sampleRate;
   samples[i]=fade*Math.pow(1-p,1.4)*(.45*low+.14*Math.sin(phase));
  }else{
   phase+=2*Math.PI*(52+90*Math.exp(-t*24))/sampleRate;
   const crackle=Math.pow(Math.max(0,Math.sin(t*177)+Math.sin(t*289)),4)/16;
   samples[i]=fade*(.42*Math.sin(phase)*Math.exp(-t*24)+.42*low*Math.exp(-t*8)+.18*noise*crackle*Math.exp(-t*5));
  }
 }
 samples[samples.length-1]=0;return samples;
}
/** Cached generated buffers use the existing spatial bus; every visual event starts its cue immediately. */
export function createFireworkAudio(context:AudioContext,output:()=>AudioNode){
 const buffers:Partial<Record<FireworkCue,AudioBuffer[]>>={},voices=new Set<{stop():void}>();let sequence=0;
 const clear=()=>{for(const voice of voices)voice.stop();};
 return {clear,play(cue:FireworkCue){
  if(context.state!=='running')return false;
  buffers[cue]??=Array.from({length:3},(_,i)=>{
   const data=synthesizeFirework(cue,context.sampleRate,17+i*7919),buffer=context.createBuffer(1,data.length,context.sampleRate);
   buffer.copyToChannel(data,0);return buffer;
  });
  while(voices.size>=12)voices.values().next().value!.stop();
  const source=context.createBufferSource(),gain=context.createGain(),out=output();
  source.buffer=buffers[cue]![sequence++%3];gain.gain.value=cue==='launch'?.28:.5;
  source.connect(gain).connect(out);let ended=false;
  const finish=()=>{if(ended)return;ended=true;voices.delete(voice);source.disconnect();gain.disconnect();
   if(typeof PannerNode!=='undefined'&&out instanceof PannerNode)out.disconnect();};
  const voice={stop(){if(!ended){source.stop();finish();}}};
  source.onended=finish;voices.add(voice);source.start(context.currentTime);return true;
 }};
}
