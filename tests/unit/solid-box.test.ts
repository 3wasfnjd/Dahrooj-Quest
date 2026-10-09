import {describe,it,expect} from 'vitest';
import {collideSolidBox} from '../../src/reference/solid-box';
const vec=(x=0,y=0,z=0)=>({x,y,z});
describe('fair cabinet swept collision',()=>{
 it('stops a hard throw that crosses the entire platform in one step',()=>{
  const p=vec(0,.5,-2),v=vec(0,0,-40),n=vec();
  expect(collideSolidBox(p,v,.24,vec(0,.5,2),vec(0,.525,0),vec(3.3,.605,.5),n)).toBe(true);
  expect(p.z).toBeCloseTo(.741);expect(v.z).toBe(20);expect(n.z).toBe(1);
 });
 it('blocks side contact and the top while allowing a throw above the cabinet',()=>{
  const c=vec(0,.525,0),h=vec(3.3,.605,.5),n=vec(),side=vec(3.2,.5,0),v=vec(-3,0,0);
  expect(collideSolidBox(side,v,.24,vec(4,.5,0),c,h,n)).toBe(true);expect(v.x).toBe(1.5);
  const top=vec(0,.9,0),down=vec(0,-3,0);
  expect(collideSolidBox(top,down,.24,vec(0,2,0),c,h,n)).toBe(true);expect(top.y).toBeCloseTo(1.371);expect(down.y).toBe(1.5);
  expect(collideSolidBox(vec(0,2,-2),vec(0,0,-40),.24,vec(0,2,2),c,h,n)).toBe(false);
 });
 it('does not pull a departing ball back or block a parallel near miss',()=>{
  const c=vec(),h=vec(1,1,1),n=vec();
  expect(collideSolidBox(vec(0,0,3),vec(0,0,1),.2,vec(0,0,2),c,h,n)).toBe(false);
  expect(collideSolidBox(vec(2,0,-2),vec(0,0,-10),.2,vec(2,0,2),c,h,n)).toBe(false);
 });
});
