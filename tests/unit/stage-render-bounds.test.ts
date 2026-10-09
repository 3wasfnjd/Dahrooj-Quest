/* eslint-disable @typescript-eslint/no-explicit-any -- Exercise the original JS stage and Three's actual culling path. */
import {describe,it,expect} from 'vitest';
import * as T from '@iwsdk/core';
import {stageArt} from '../../src/reference/stage-art.js';
import hoop from '../../src/reference/stages/hoop.js';
import goal from '../../src/reference/stages/goal.js';
import {GOAL_Z} from '../../src/reference/court-layout.js';
const V=(x=0,y=0,z=0)=>new T.Vector3(x,y,z);
function context(){
 const ctx:any={T,scene:new T.Scene(),V,UP:V(0,1,0),S:{pos:V(),vel:V(),side:V(),shot:true,scoredT:0,shotT:.2,prevY:3.1},BR:.24,GRAV:13,time:0,INK:0x2c2d3d,hit(){},ooh(){},miss(){},success(){},swish(){},chProgress(){}};
 Object.assign(ctx,stageArt(ctx));return ctx;
}
function currentBoundsContainVertices(mesh:T.LineSegments){
 // This is the renderer's lazy bounding-sphere path, not a property-only check.
 mesh.updateMatrixWorld(true);new T.Frustum().intersectsObject(mesh);
 const positions=mesh.geometry.attributes.position,sphere=mesh.geometry.boundingSphere!;
 for(let i=0;i<positions.count;i++)expect(V().fromBufferAttribute(positions,i).distanceTo(sphere.center)).toBeLessThanOrEqual(sphere.radius+1e-6);
}
describe('deforming mode nets retain valid culling bounds',()=>{
 it('keeps the hoop net visible after the real score/stretch animation',()=>{
  const ctx=context(),stage=hoop(ctx);let net!:T.LineSegments;stage.grp.traverse((o:any)=>{if(o.isLineSegments&&o.material===ctx.netMat)net=o;});
  net.geometry.computeBoundingSphere();const original=net.geometry.boundingSphere!.clone();
  ctx.S.pos.set(0,3.04,-8.37);ctx.S.vel.set(8,-2,0);stage.collide!();ctx.S.shot=false;let maximumExcess=0;
  for(let frame=0;frame<24;frame++){
   stage.update(1/72);const points=net.geometry.attributes.position;
   for(let i=0;i<points.count;i++)maximumExcess=Math.max(maximumExcess,V().fromBufferAttribute(points,i).distanceTo(original.center)-original.radius);
   currentBoundsContainVertices(net);
  }
  expect(maximumExcess).toBeGreaterThan(.07); // Demonstrates why the original cached sphere is invalid.
 });
 it('rebuilds the goal back-net bounds after a real impact',()=>{
  const ctx=context(),stage=goal(ctx);const nets:T.LineSegments[]=[];stage.grp.traverse((o:any)=>{if(o.isLineSegments&&o.material===ctx.netMat)nets.push(o);});
  const net=nets[0];net.geometry.computeBoundingSphere();const previous=net.geometry.boundingSphere;
  ctx.S.pos.set(0,1,GOAL_Z-1.8+.1);ctx.S.vel.set(0,0,-16);stage.collide!();ctx.S.shot=false;stage.update(1/72);
  currentBoundsContainVertices(net);expect(net.geometry.boundingSphere).not.toBe(previous);
 });
});
