/* eslint-disable @typescript-eslint/no-explicit-any -- Exercise Web Audio lifetime with controllable platform nodes. */
import {describe,expect,it,vi} from 'vitest';
import {createFireworkAudio,FIREWORK_SECONDS,synthesizeFirework} from '../../src/reference/firework-audio';
describe('procedural firework cues',()=>{
 it('generates finite offline cues with immediate attacks and silent ends at either common sample rate',()=>{
  for(const rate of [44100,48000])for(const cue of ['launch','burst'] as const){
   const data=synthesizeFirework(cue,rate);expect(data.length).toBe(Math.ceil(rate*FIREWORK_SECONDS[cue]));
   expect(data.every(v=>Number.isFinite(v)&&Math.abs(v)<1)).toBe(true);expect(Math.abs(data[0])).toBe(0);expect(data.at(-1)).toBe(0);
   const energy=(slice:Float32Array)=>slice.reduce((n,v)=>n+v*v,0)/slice.length;
   expect(energy(data.slice(0,rate*.02))).toBeGreaterThan(.001);
   expect(energy(data.slice(-rate*.04))).toBeLessThan(energy(data.slice(0,rate*.04))*.05);
  }
 });
 it('starts each visual event now, caches synthesis, bounds overlaps and releases voices on focus loss',()=>{
  let active=0,maximum=0;const sources:any[]=[],buffer=vi.fn(()=>({copyToChannel:vi.fn()}));
  const bus={disconnect:vi.fn()},context:any={state:'running',sampleRate:48000,currentTime:12,createBuffer:buffer,
   createGain:()=>({gain:{value:0},connect:()=>bus,disconnect:vi.fn()}),createBufferSource:()=>{
    const source:any={onended:null,connect:(node:any)=>node,disconnect:vi.fn(),start:vi.fn(()=>{active++;maximum=Math.max(active,maximum);}),stop:vi.fn(()=>{active--;})};sources.push(source);return source;
   }};
  const sound=createFireworkAudio(context,()=>bus as any);
  for(let i=0;i<40;i++)expect(sound.play(i%2?'burst':'launch')).toBe(true);
  expect(maximum).toBe(12);expect(buffer).toHaveBeenCalledTimes(6);
  for(const source of sources)expect(source.start).toHaveBeenCalledWith(12);
  sound.clear();sound.clear();expect(active).toBe(0);expect(bus.disconnect).not.toHaveBeenCalled();
  for(const source of sources){expect(source.stop).toHaveBeenCalledTimes(1);expect(source.disconnect).toHaveBeenCalledTimes(1);}
  context.state='suspended';expect(sound.play('burst')).toBe(false);expect(sources).toHaveLength(40);
 });
});
