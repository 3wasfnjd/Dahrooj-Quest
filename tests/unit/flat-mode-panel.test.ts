import {afterEach,describe,expect,it,vi} from 'vitest';
import {Group,NoBlending,Raycaster,Vector3} from '@iwsdk/core';
import {createFlatModePanel,MENU_PAGES,modeAtUV,type MenuModel} from '../../src/reference/flat-mode-panel';
const modes=['goal','hoop','window','cans','bowling','bricks','fair','climb','rain'].map(id=>[id,id,id] as const);
const model=(english=false,kind='immersive-vr'):MenuModel=>({english,kind,mode:'goal',style:'jelly',jellyColor:'blue',throwStyle:'trigger',shotStyle:'bolt',time:'day',weather:'snow',accessory:'',done:0,resetArmed:false,challenges:Array.from({length:16},(_,i)=>({id:String(i),title:'تحدي',en:'Challenge',value:0,goal:3}))});
afterEach(()=>vi.unstubAllGlobals());
function panel(){const ctx=new Proxy({},{get:()=>()=>{},set:()=>true});vi.stubGlobal('document',{createElement:()=>({width:0,height:0,getContext:()=>ctx})});return createFlatModePanel(modes);}
describe('single XR menu surface',()=>{
 it('selects all nine coloured modes through actual rays in both languages',()=>{
  const ui=panel(),root=new Group();root.add(ui.mesh);root.position.set(2,1,-3);root.rotation.y=.4;root.scale.setScalar(.5);root.updateMatrixWorld(true);
  for(const english of [false,true]){ui.draw(model(english));for(let i=0;i<9;i++){
   const target=root.localToWorld(ui.point(i,english)),normal=new Vector3(0,0,1).transformDirection(root.matrixWorld);
   const hit=new Raycaster(target.clone().add(normal),normal.negate()).intersectObject(ui.mesh)[0];
   expect(ui.action(ui.hit(hit.uv!.x,hit.uv!.y))?.id).toBe(modes[i][0]);
  }}
  expect(new Set(ui.buttons.filter(b=>b.kind==='mode').map(b=>b.fill)).size).toBe(9);
  expect(ui.point(0,false).x).toBeGreaterThan(ui.point(0,true).x);
  for(const [u,v] of [[0,0],[.5,.98],[.5,.02],[-1,.5],[NaN,0]])expect(modeAtUV(u,v,false)).toBe(-1);
 });
 it('reuses one nonblended, depth-independent plane across every page and hover',()=>{
  const ui=panel(),material=ui.mesh.material,texture=material.map!,m=model();
  expect(material.blending).toBe(NoBlending);expect(material.depthTest).toBe(false);expect(material.depthWrite).toBe(false);expect(material.opacity).toBe(1);
  const initial=ui.mesh.matrix.clone();ui.draw(m);const version=texture.version;ui.draw(m);expect(texture.version).toBe(version);
  for(const [page] of MENU_PAGES){ui.show(page);ui.draw(m);for(let i=0;i<ui.buttons.length;i++){ui.draw(m,i);ui.mesh.updateMatrix();expect(ui.mesh.matrix.equals(initial)).toBe(true);}expect(ui.mesh.children).toHaveLength(0);}
 });
 it('keeps visible button targets within bounds and disjoint across all sections in VR and AR',()=>{
  const ui=panel();
  for(const english of [false,true])for(const kind of ['immersive-vr','immersive-ar'])for(const [page] of MENU_PAGES){
   const m=model(english,kind);ui.show(page);ui.draw(m);
   for(const b of ui.buttons){expect(b.x).toBeGreaterThanOrEqual(0);expect(b.y).toBeGreaterThanOrEqual(0);expect(b.x+b.w).toBeLessThanOrEqual(1200);expect(b.y+b.h).toBeLessThanOrEqual(1000);}
   for(let i=0;i<ui.buttons.length;i++)for(let j=i+1;j<ui.buttons.length;j++){const a=ui.buttons[i],b=ui.buttons[j];expect(a.x<b.x+b.w&&b.x<a.x+a.w&&a.y<b.y+b.h&&b.y<a.y+a.h).toBe(false);}
   if(page==='world')expect(ui.buttons.some(b=>b.kind==='weather')).toBe(kind==='immersive-vr');
  }
 });
 it('navigates, guards locked rewards and exposes every challenge without an extra mesh',()=>{
  const ui=panel(),m=model();ui.draw(m);
  const go=(kind:string,id:string)=>{const b=ui.buttons.find(b=>b.kind===kind&&b.id===id)!;expect(b).toBeDefined();ui.navigate(b);ui.draw(m);};
  go('tab','appearance');expect(ui.buttons.filter(b=>b.kind==='jellyColor')).toHaveLength(7);
  go('appearance','accessories');const index=ui.buttons.findIndex(b=>b.id==='headphones');expect(ui.action(index)).toBeNull();
  m.done=14;ui.draw(m);expect(ui.action(index)?.id).toBe('headphones');
  go('tab','challenges');expect(ui.action(ui.buttons.findIndex(b=>b.id==='prev'))).toBeNull();
  go('page','next');go('page','next');expect(ui.challengePage).toBe(2);expect(ui.action(ui.buttons.findIndex(b=>b.id==='next'))).toBeNull();
  go('tab','about');expect(ui.page).toBe('about');ui.show('modes');ui.draw(m);expect(ui.buttons.filter(b=>b.kind==='mode')).toHaveLength(9);
 });
});
