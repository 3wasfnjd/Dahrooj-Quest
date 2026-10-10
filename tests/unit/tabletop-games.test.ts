import {describe,expect,it,vi} from 'vitest';
import {BALANCE_LEVELS,RICOCHET_LEVELS,createTabletopGame,sweepBox} from '../../src/reference/tabletop-games';

describe('balance courses',()=>{
 it.each([72,90,120])('finishes all three courses through tilt physics at %i Hz, including the moving gate',fps=>{
  const won=vi.fn(),g=createTabletopGame('balance',won);
  for(let level=0;level<3;level++){
   g.reset(level);const path=BALANCE_LEVELS[level].path;let target=1,frames=0;
   while(g.phase!=='won'&&frames++<fps*80){
    const p=path[target],x=p.x-g.ball.x,z=p.z-g.ball.z;
    if(Math.hypot(x,z)<.095&&target<path.length-1)target++;
    g.setTilt((x*4-g.velocity.x*3)/7,(z*4-g.velocity.z*3)/7);g.step(1/fps);
    expect(Number.isFinite(g.ball.x+g.ball.z)).toBe(true);
   }
   expect(g.phase,`level ${level+1}, ball ${JSON.stringify(g.ball)}, target ${target}`).toBe('won');expect(g.stars.size).toBe(3);
   expect(won).toHaveBeenCalledTimes(level+1);g.step(.05);expect(won).toHaveBeenCalledTimes(level+1);
  }
 });
 it('drops off a bridge, resets safely, and freezes exactly without an active grip',()=>{
  const g=createTabletopGame('balance');g.reset(1);g.setTilt(.32,0);
  for(let i=0;i<300&&g.phase!=='falling';i++)g.step(1/120);
  expect(g.phase).toBe('falling');for(let i=0;i<110&&g.phase==='falling';i++)g.step(1/120);
  expect(g.phase).toBe('ready');expect(g.ball).toEqual(BALANCE_LEVELS[1].path[0]);expect(g.stars.size).toBe(0);
  g.setTilt(0,-.2);g.step(.05);const before={...g.ball};for(let i=0;i<500;i++)g.step(.05,false);expect(g.ball).toEqual(before);
  g.step(NaN);g.setTilt(Infinity,NaN);expect(g.tilt).toEqual({x:0,z:0});
  g.reset(0);Object.assign(g.ball,BALANCE_LEVELS[0].holes[0].p);g.step(1/120);expect(g.phase).toBe('falling');
 });
});
describe('ricochet courses',()=>{
 it.each([72,90,120])('solves one, two and three distinct paddle routes at %i Hz without tunnelling',fps=>{
  const won=vi.fn(),g=createTabletopGame('ricochet',won);
  for(let level=0;level<3;level++){
   g.reset(level);const l=RICOCHET_LEVELS[level];l.solution.forEach((angle,i)=>g.turnMirror(i,angle));expect(g.launch({x:0,z:-1})).toBe(true);
   for(let f=0;f<fps*8&&g.phase==='playing';f++)g.step(1/fps);
   expect(g.phase,`level ${level+1}: ${JSON.stringify(g.ball)}, bounces ${[...g.bounces]}`).toBe('won');
   expect(g.bounces.size).toBe(l.required);expect(g.attempts).toBe(1);expect(won).toHaveBeenNthCalledWith(level+1,3);
  }
 });
 it('requires a paddle bounce, locks moving paddles and duplicate launches during flight, and resets attempts by round',()=>{
  const won=vi.fn(),g=createTabletopGame('ricochet',won),l=RICOCHET_LEVELS[0];
  expect(g.launch({x:NaN,z:0})).toBe(false);expect(g.launch({x:0,z:0})).toBe(false);
  g.launch({x:l.goal.x-l.start.x,z:l.goal.z-l.start.z});const before=g.angles[0];
  expect(g.turnMirror(0,0)).toBe(false);expect(g.angles[0]).toBe(before);expect(g.launch({x:0,z:-1})).toBe(false);
  for(let i=0;i<1000&&g.phase!=='ready';i++)g.step(1/120);expect(g.phase).toBe('ready');expect(won).not.toHaveBeenCalled();
  l.solution.forEach((angle,i)=>g.turnMirror(i,angle));g.launch({x:0,z:-1});
  for(let i=0;i<1000&&g.phase==='playing';i++)g.step(1/120);expect(g.phase).toBe('won');expect(g.attempts).toBe(2);expect(won).toHaveBeenCalledExactlyOnceWith(2);
  for(let i=0;i<220;i++)g.step(1/120);expect(g.level).toBe(1);expect(g.attempts).toBe(0);expect(g.phase).toBe('ready');expect(won).toHaveBeenCalledTimes(1);
 });
 it('pauses a flying ball without accumulating hidden simulation time',()=>{
  const a=createTabletopGame('ricochet'),b=createTabletopGame('ricochet');a.launch({x:0,z:-1});b.launch({x:0,z:-1});a.step(.05);b.step(.05);
  for(let i=0;i<200;i++)a.step(.05,false);a.step(1/120);b.step(1/120);expect(a.ball).toEqual(b.ball);
 });
 it('sweeps through thin rotated boards and rejects separated or outgoing paths',()=>{
  const box={x:0,z:0,hx:.5,hz:.045};
  expect(sweepBox({x:0,z:2},{x:0,z:-4},box,-Math.PI/4)?.t).toBeGreaterThan(0);
  expect(sweepBox({x:2,z:2},{x:0,z:-4},box,-Math.PI/4)).toBeNull();
  expect(sweepBox({x:0,z:.16},{x:0,z:.2},box)).toBeNull();
 });
});
