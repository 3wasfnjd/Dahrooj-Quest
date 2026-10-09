/* eslint-disable @typescript-eslint/no-explicit-any -- Test the original JavaScript collision boundary with real Three bodies. */
import {it,expect} from 'vitest';
import * as T from 'three';
import createCans from '../../src/reference/stages/cans.js';
function scenario(secondThrow=false,blaster=false){
 const V=(x=0,y=0,z=0)=>new T.Vector3(x,y,z),S={pos:V(99,1,0),vel:V(),shot:true,shotId:1},awards:string[]=[];let bodies:any[]=[];
 const noop=()=>{};
 const stage:any=createCans({T,scene:new T.Scene(),INK:0x222222,bar:noop,V,S,audio:null,sfxOut:noop,bodyOf:(all:any[],obj:any)=>{bodies=all;return all.find(b=>b.mesh===obj);},shove:noop,miss:noop,pointCollide:noop,BR:.24,hit:noop,react:noop,GRAV:13,UP:V(0,1,0),addCount:noop,chProgress:(id:string)=>awards.push(id),success:noop,time:0});
 stage.shoot(null,V(),V());stage.onThrow();
 const contact=(index:number)=>{S.pos.copy(bodies[index].x).add(V(.44,0,0));S.vel.set(-8,0,0);stage.ballContact();S.pos.set(99,1,0);};
 contact(0);
 if(secondThrow){for(let i=0;i<3;i++)bodies[i].x.y=.1;stage.update(.001);S.shotId=2;stage.onThrow();contact(5);}
 if(blaster)stage.shoot(bodies[4].mesh,V(),V(0,0,-1));
 for(const b of bodies)b.x.y=.1;
 stage.update(.001);
 return awards;
}
it('awards a full physical can clear from one thrown ball',()=>expect(scenario()).toContain('cansOne'));
it('does not award cansOne when six cans fall over two actual throws',()=>expect(scenario(true)).not.toContain('cansOne'));
it('does not award cansOne when the blaster helps the ball',()=>expect(scenario(false,true)).not.toContain('cansOne'));
