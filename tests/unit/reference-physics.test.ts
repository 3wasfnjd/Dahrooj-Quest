import { describe,it,expect } from 'vitest';
import { Vector3 } from '@iwsdk/core';
import { referenceBallPhysics } from '../../src/reference/ball-physics.js';
import { SHOT_STYLE, advanceShot, groundMini } from '../../src/reference/projectile-spec.js';
import core from '../../src/reference/summit-core.js';
describe('Physics reused from quest c7925b7',()=>{
 it('retains the original 0.55 ground restitution and 0.85 horizontal impact damping',()=>{
  const S={pos:new Vector3(0,.25,0),vel:new Vector3(4,-8,0),side:new Vector3(),grounded:false,shot:false,prevY:0,prevZ:0};
  const step=referenceBallPhysics({S,BR:.24,GRAV:13,UP:new Vector3(0,1,0),V:(x:number,y:number,z:number)=>new Vector3(x,y,z),hit:()=>{},waterHook:null,splash:()=>{},miss:()=>{},stage:{collide:()=>{}}});
  step(1/120);expect(S.pos.y).toBe(.24);expect(S.vel.y).toBeCloseTo((8+13/120)*Math.pow(.9,1/120)*.55,8);expect(S.vel.x).toBeCloseTo(4*Math.pow(.9,1/120)*.85,8);
 });
 it('keeps original projectile dimensions, gravity and mini bounce',()=>{
  expect(SHOT_STYLE.mini.r).toBe(.022);expect(SHOT_STYLE.bolt.r).toBe(.02);expect(SHOT_STYLE.firework.burst).toBe(.55);
  const s={kind:'mini' as const,p:new Vector3(),v:new Vector3(11,-2,0),wob:0,r:.022};advanceShot(s,.1,1);expect(s.v.y).toBeCloseTo(-2.98);groundMini(s,.1,0,1);expect(s.v.y).toBeCloseTo(2.98*.45);expect(s.p.y).toBe(.022);
 });
 it('uses the original Summit rules, including three hearts and a three-projectile cap',()=>{
  const s=core.createState(16.25);expect(s.ball.hearts).toBe(3);expect(core.G).toBe(60);expect(core.JUMP).toBe(28);expect(core.TOP).toBe(148);for(let i=0;i<60;i++){core.throwBall(s);core.step(s,1/60);expect(s.shots.length).toBeLessThanOrEqual(3);}
 });
});
