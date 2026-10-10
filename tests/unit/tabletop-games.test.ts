import {describe,expect,it,vi} from 'vitest';
import {BALANCE_LEVELS,RICOCHET_LEVELS,MAZE_LEVELS,TABLE_RADIUS,createTabletopGame,sweepBox} from '../../src/reference/tabletop-games';

describe('balance courses',()=>{
 it.each([72,90,120])('finishes all five courses through tilt physics at %i Hz, including the moving gate',fps=>{
  const won=vi.fn(),g=createTabletopGame('balance',won);
  for(let level=0;level<5;level++){
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
 it('completes round three despite two degrees of paddle input error and one degree of aim error',()=>{
  const radians=(d:number)=>d*Math.PI/180,l=RICOCHET_LEVELS[2];
  for(const aim of [-1,0,1])for(const a of [-2,0,2])for(const b of [-2,0,2])for(const c of [-2,0,2]){
   const g=createTabletopGame('ricochet');g.reset(2);l.solution.forEach((v,i)=>g.turnMirror(i,v+radians([a,b,c][i])));
   g.launch({x:Math.sin(radians(aim)),z:-Math.cos(radians(aim))});for(let i=0;i<1000&&g.phase==='playing';i++)g.step(1/120);
   expect(g.phase,`aim ${aim}, paddles ${a},${b},${c}`).toBe('won');expect(g.bounces.size).toBe(3);
  }
 });
 it.each([72,90,120])('solves all five distinct paddle routes at %i Hz without tunnelling',fps=>{
  const won=vi.fn(),g=createTabletopGame('ricochet',won);
  for(let level=0;level<5;level++){
   g.reset(level);const l=RICOCHET_LEVELS[level];l.solution.forEach((angle,i)=>g.turnMirror(i,angle));expect(g.launch({x:0,z:-1})).toBe(true);
   for(let f=0;f<fps*8&&g.phase==='playing';f++)g.step(1/fps);
   expect(g.phase,`level ${level+1}: ${JSON.stringify(g.ball)}, bounces ${[...g.bounces]}`).toBe('won');
   expect(g.bounces.size).toBe(l.required);expect(g.attempts).toBe(1);expect(won).toHaveBeenNthCalledWith(level+1,3,expect.objectContaining({mode:'ricochet',level,attempts:1,failures:0}));
  }
 });
 it('requires a paddle bounce, locks moving paddles and duplicate launches during flight, and resets attempts by round',()=>{
  const won=vi.fn(),g=createTabletopGame('ricochet',won),l=RICOCHET_LEVELS[0];
  expect(g.launch({x:NaN,z:0})).toBe(false);expect(g.launch({x:0,z:0})).toBe(false);
  g.launch({x:l.goal.x-l.start.x,z:l.goal.z-l.start.z});const before=g.angles[0];
  expect(g.turnMirror(0,0)).toBe(false);expect(g.angles[0]).toBe(before);expect(g.launch({x:0,z:-1})).toBe(false);
  for(let i=0;i<1000&&g.phase!=='ready';i++)g.step(1/120);expect(g.phase).toBe('ready');expect(won).not.toHaveBeenCalled();
  l.solution.forEach((angle,i)=>g.turnMirror(i,angle));g.launch({x:0,z:-1});
  for(let i=0;i<1000&&g.phase==='playing';i++)g.step(1/120);expect(g.phase).toBe('won');expect(g.attempts).toBe(2);expect(won).toHaveBeenCalledExactlyOnceWith(2,expect.objectContaining({attempts:2,failures:1}));
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

describe('maze courses with a continuous floor',()=>{
 it.each([72,90,120])('navigates all five mazes through actual tilt and wall collisions at %i Hz',fps=>{
  const won=vi.fn(),g=createTabletopGame('maze',won);
  for(let level=0;level<MAZE_LEVELS.length;level++){
   g.reset(level);const route=MAZE_LEVELS[level].route;let target=1,frames=0;
   while(g.phase!=='won'&&frames++<fps*150){
    const p=route[target],x=p.x-g.ball.x,z=p.z-g.ball.z;
    if(Math.hypot(x,z)<.07&&target<route.length-1)target++;
    g.setTilt((x*4-g.velocity.x*3)/7,(z*4-g.velocity.z*3)/7);g.step(1/fps);
    expect(g.fall).toBe(0);expect(g.failures).toBe(0);
   }
   expect(g.phase,`maze ${level+1}: ${JSON.stringify(g.ball)}, waypoint ${target}`).toBe('won');
   expect(g.stars.size).toBe(3);expect(won).toHaveBeenNthCalledWith(level+1,3,expect.objectContaining({mode:'maze',level,stars:3,failures:0}));
  }
  for(let i=0;i<210;i++)g.step(1/120);expect(g.level).toBe(0);expect(won).toHaveBeenCalledTimes(5);
 });
 it('keeps Dahrooj on the board under sustained maximum tilt toward walls and corners',()=>{
  const g=createTabletopGame('maze');
  for(let level=0;level<5;level++)for(let d=0;d<8;d++){
   g.reset(level);g.setTilt(Math.cos(d*Math.PI/4),Math.sin(d*Math.PI/4));
   for(let i=0;i<300;i++){
    g.step(.05);expect(g.phase).not.toBe('falling');expect(g.fall).toBe(0);expect(g.failures).toBe(0);
    expect(Math.abs(g.ball.x)).toBeLessThanOrEqual(1.5-.09-TABLE_RADIUS+.00001);
    expect(Math.abs(g.ball.z)).toBeLessThanOrEqual(1.7-.09-TABLE_RADIUS+.00001);
    for(const wall of MAZE_LEVELS[g.level].walls)expect(Math.abs(g.ball.x-wall.x)<wall.hx+TABLE_RADIUS-.00001&&Math.abs(g.ball.z-wall.z)<wall.hz+TABLE_RADIUS-.00001).toBe(false);
   }
  }
 });
 it('stops a fast ball at an internal divider and slides along it',()=>{
  const g=createTabletopGame('maze');g.reset(4);const wall=MAZE_LEVELS[4].walls.slice(4).find(w=>w.hx<w.hz)!;
  Object.assign(g.ball,{x:wall.x-wall.hx-TABLE_RADIUS-.05,z:wall.z});Object.assign(g.velocity,{x:40,z:0});g.step(.05);
  expect(g.ball.x).toBeLessThan(wall.x-wall.hx-TABLE_RADIUS);expect(g.fall).toBe(0);expect(g.velocity.x).toBe(0);
  g.setTilt(.32,.15);const z=g.ball.z;g.step(.05);expect(g.ball.z).toBeGreaterThan(z);
 });
 it('has no overlapping coplanar wall tops and keeps every wall inside the solid floor',()=>{
  for(const l of MAZE_LEVELS)for(let i=0;i<l.walls.length;i++){
   const a=l.walls[i];expect(Math.abs(a.x)+a.hx).toBeLessThanOrEqual(1.5+1e-9);expect(Math.abs(a.z)+a.hz).toBeLessThanOrEqual(1.7+1e-9);
   for(const b of l.walls.slice(i+1))expect(Math.abs(a.x-b.x)<a.hx+b.hx-1e-9&&Math.abs(a.z-b.z)<a.hz+b.hz-1e-9).toBe(false);
  }
 });
 it('requires all stars, rejects launching, freezes without a grip and retries without a drop',()=>{
  const won=vi.fn(),g=createTabletopGame('maze',won);Object.assign(g.ball,MAZE_LEVELS[0].goal);g.step(.05);expect(won).not.toHaveBeenCalled();
  g.reset();expect(g.launch({x:0,z:-1})).toBe(false);g.setTilt(.2,-.2);g.step(.05);const saved={ball:{...g.ball},velocity:{...g.velocity},stars:[...g.stars]};
  for(let i=0;i<200;i++)g.step(.05,false);expect(g.ball).toEqual(saved.ball);expect(g.velocity).toEqual(saved.velocity);expect([...g.stars]).toEqual(saved.stars);
  g.retry();expect(g.phase).toBe('ready');expect(g.ball).toEqual(MAZE_LEVELS[0].start);expect(g.failures).toBe(1);expect(g.fall).toBe(0);
 });
});
