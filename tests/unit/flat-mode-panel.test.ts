import {afterEach,describe,expect,it,vi} from 'vitest';
import {Group,NoBlending,Raycaster,Vector3} from '@iwsdk/core';
import {createFlatModePanel,modeAtUV} from '../../src/reference/flat-mode-panel';
const modes=['goal','hoop','window','cans','bowling','bricks','fair','climb','rain'].map(id=>[id,id,id] as const);
afterEach(()=>vi.unstubAllGlobals());
function panel(){
 const ctx=new Proxy({},{get:()=>()=>{},set:()=>true});
 vi.stubGlobal('document',{createElement:()=>({width:0,height:0,getContext:()=>ctx})});
 return createFlatModePanel(modes);
}
describe('flat XR mode selector',()=>{
 it('selects all nine modes using real ray intersections, including mirrored Arabic layout',()=>{
  const ui=panel(),root=new Group();root.add(ui.mesh);root.position.set(2,1,-3);root.rotation.y=.4;root.scale.setScalar(.5);root.updateMatrixWorld(true);
  for(const english of [false,true])for(let i=0;i<9;i++){
   const target=root.localToWorld(ui.point(i,english));const normal=new Vector3(0,0,1).transformDirection(root.matrixWorld);
   const ray=new Raycaster(target.clone().add(normal),normal.negate());const hit=ray.intersectObject(ui.mesh)[0];
   expect(hit).toBeDefined();expect(ui.hit(hit.uv!.x,hit.uv!.y,english)).toBe(i);
  }
  expect(ui.point(0,false).x).toBeGreaterThan(ui.point(0,true).x);
  for(const [u,v] of [[0,0],[.5,.98],[.5,.02],[-1,.5],[NaN,0]])expect(modeAtUV(u,v,false)).toBe(-1);
 });
 it('keeps a single nonblended plane independent of world depth and never scales on hover',()=>{
  const ui=panel(),material=ui.mesh.material,texture=material.map!;
  expect(ui.mesh.children).toHaveLength(0);expect(material.blending).toBe(NoBlending);
  expect(material.depthTest).toBe(false);expect(material.depthWrite).toBe(false);expect(material.opacity).toBe(1);
  const initial=ui.mesh.matrix.clone();ui.draw(false,-1,'goal');const version=texture.version;
  ui.draw(false,-1,'goal');expect(texture.version).toBe(version);
  for(let i=0;i<9;i++){ui.draw(false,i,'goal');ui.mesh.updateMatrix();expect(ui.mesh.matrix.equals(initial)).toBe(true);}
  expect(texture.version).toBe(version+9);
 });
});
