import {describe,it,expect} from 'vitest';
import {rainSpawn,guideRain} from '../../src/reference/rain-field';
describe('front-facing Rain field',()=>{
 it('spawns only ahead and spreads evenly on both sides at VR and AR radii',()=>{
  const head={x:3,y:1.6,z:-7},out={x:0,y:2,z:0};
  for(const radius of [2.6,4.4])for(const yaw of [0,Math.PI/2,Math.PI,Math.PI*1.5]){
   const dir={x:Math.sin(yaw),y:0,z:-Math.cos(yaw)};let left=0,right=0,maxSide=0;
   for(let i=0;i<100;i++){
    rainSpawn(out,head,dir,radius,(i+.5)/100,((i*37)%100+.5)/100);
    const x=out.x-head.x,z=out.z-head.z,ahead=x*dir.x+z*dir.z,side=-x*dir.z+z*dir.x;
    expect(ahead).toBeGreaterThan(.43);expect(Math.hypot(x,z)).toBeLessThanOrEqual(radius);
    if(side<0)left++;else right++;maxSide=Math.max(maxSide,Math.abs(side));
    expect(out.y).toBe(2);
   }
   expect(left).toBe(50);expect(right).toBe(50);expect(maxSide).toBeGreaterThan(radius*.7);
  }
 });
 it('allows ordinary wandering but guides rear and distant balls back without changing positions',()=>{
  const head={x:0,y:1.6,z:0},dir={x:0,y:0,z:-1},wander={gx:.2,gz:.1};
  guideRain({x:1,y:.1,z:-2},wander,head,dir,4.4);expect(wander).toEqual({gx:.2,gz:.1});
  const rear={x:0,y:.1,z:.5};guideRain(rear,wander,head,dir,4.4);
  expect(wander.gz).toBeCloseTo(-.65);expect(rear).toEqual({x:0,y:.1,z:.5});
  guideRain({x:5,y:.1,z:-2},wander,head,dir,4.4);expect(wander.gx).toBeLessThan(0);
  expect(Math.hypot(wander.gx,wander.gz)).toBeCloseTo(.65);
 });
});
