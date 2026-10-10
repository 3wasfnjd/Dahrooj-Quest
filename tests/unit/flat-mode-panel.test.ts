import {afterEach,describe,expect,it,vi} from 'vitest';
import {Group,LinearMipmapLinearFilter,NoBlending,Raycaster,Vector3} from '@iwsdk/core';
import {createFlatModePanel,MENU_PAGES,modeAtUV,type MenuModel} from '../../src/reference/flat-mode-panel';
import {XR_MODE_CATALOG} from '../../src/reference/mode-catalog';
const modes=XR_MODE_CATALOG;
const model=(english=false,kind='immersive-vr'):MenuModel=>({english,kind,mode:'goal',style:'jelly',jellyColor:'blue',throwStyle:'trigger',shotStyle:'bolt',time:'day',weather:'snow',accessory:'',done:0,resetArmed:false,challenges:Array.from({length:16},(_,i)=>({id:String(i),title:`تحدي ${i}`,en:`Challenge ${i}`,value:0,goal:3}))});
afterEach(()=>vi.unstubAllGlobals());
function panel(drawn:string[]=[]){const ctx=new Proxy({},{get:(_t,k)=>k==='fillText'?(t:string)=>drawn.push(t):k==='createLinearGradient'||k==='createRadialGradient'?()=>({addColorStop(){}}):()=>{},set:()=>true});vi.stubGlobal('document',{createElement:()=>({width:0,height:0,getContext:()=>ctx})});return createFlatModePanel(modes);}
describe('single XR menu surface',()=>{
 it('selects all twelve icon modes through actual rays in both languages',()=>{
  const drawn:string[]=[],ui=panel(drawn),root=new Group();root.add(ui.mesh);root.position.set(2,1,-3);root.rotation.y=.4;root.scale.setScalar(.5);root.updateMatrixWorld(true);
  for(const english of [false,true]){drawn.length=0;ui.draw(model(english));for(const [,ar,en] of modes)expect(drawn).not.toContain(english?en:ar);for(let i=0;i<modes.length;i++){
   const target=root.localToWorld(ui.point(i,english)),normal=new Vector3(0,0,1).transformDirection(root.matrixWorld);
   const hit=new Raycaster(target.clone().add(normal),normal.negate()).intersectObject(ui.mesh)[0];
   const index=ui.hit(hit.uv!.x,hit.uv!.y);expect(ui.action(index)?.id).toBe(modes[i][0]);
   drawn.length=0;ui.draw(model(english),index);expect(drawn).toEqual([english?'Dahrooj':'دحروج',modes[i][english?2:1]]);
  }}
  expect(ui.buttons.filter(b=>b.kind==='mode').every(b=>!b.fill&&!b.color)).toBe(true);
  expect(ui.point(0,false).x).toBeGreaterThan(ui.point(0,true).x);
  for(const [u,v] of [[0,0],[.5,.98],[.5,.02],[-1,.5],[NaN,0]])expect(modeAtUV(u,v,false)).toBe(-1);
 });
 it('reuses one nonblended, depth-independent plane across every page and hover',()=>{
  const ui=panel(),material=ui.mesh.material,texture=material.map!,m=model();
  expect(material.blending).toBe(NoBlending);expect(material.depthTest).toBe(false);expect(material.depthWrite).toBe(false);expect(material.opacity).toBe(1);
  expect(texture.generateMipmaps).toBe(true);expect(texture.minFilter).toBe(LinearMipmapLinearFilter);expect(texture.anisotropy).toBe(4);
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
  const locked=ui.buttons[index];expect(ui.hit((locked.x+locked.w/2)/1200,1-(locked.y+locked.h/2)/1000)).toBe(index);expect(locked.sub).toContain('12');
  m.done=25;ui.draw(m);expect(ui.action(index)?.id).toBe('headphones');
  const mastery=ui.buttons.findIndex(b=>b.id==='laurel');expect(ui.action(mastery)).toBeNull();expect(ui.buttons[mastery].sub).toContain('التوازن');
  m.challenges.push({id:'balance5',title:'مراحل التوازن الخمس',en:'All five balance rounds',value:5,goal:5});ui.draw(m);expect(ui.action(mastery)?.id).toBe('laurel');
  for(const b of ui.buttons.filter(b=>b.kind==='acc'))expect(b.y+b.h).toBeLessThan(855);
  go('tab','challenges');expect(ui.action(ui.buttons.findIndex(b=>b.id==='up'))).toBeNull();
  go('scrollStep','down');expect(ui.challengeScroll.offset).toBeGreaterThan(0);
  ui.scrollBy(100000);ui.draw(m);expect(ui.challengeScroll.offset).toBe(ui.challengeScroll.max);expect(ui.action(ui.buttons.findIndex(b=>b.id==='down'))).toBeNull();
  go('tab','about');expect(ui.page).toBe('about');ui.show('modes');ui.draw(m);expect(ui.buttons.filter(b=>b.kind==='mode')).toHaveLength(modes.length);
 });
 it('scrolls one clipped list by stick or dragging, reaches every row and clamps both ends',()=>{
  const drawn:string[]=[],ui=panel(drawn),m=model(true);ui.draw(m);expect(ui.scrollAxis(1,.02)).toBe(false);
  ui.show('challenges');ui.draw(m);expect(drawn).toContain('Challenge 0');expect(drawn).not.toContain('Challenge 15');
  expect(ui.scrollAxis(.1,.02)).toBe(false);expect(ui.scrollAxis(NaN,.02)).toBe(false);
  ui.scrollAxis(1,.02);expect(ui.challengeScroll.offset).toBeGreaterThan(0);
  const before=ui.challengeScroll.offset;ui.dragScroll(.5,.6);expect(ui.challengeScroll.offset).toBeGreaterThan(before);
  for(let i=0;i<20;i++){ui.scrollBy(96);ui.draw(m);}for(let i=0;i<16;i++)expect(drawn).toContain(`Challenge ${i}`);
  expect(ui.challengeScroll.offset).toBe(ui.challengeScroll.max);
  drawn.length=0;ui.draw({...m,resetArmed:true});expect(drawn).not.toContain('Challenge 0');expect(drawn).toContain('Challenge 15');
  ui.dragScroll(.5,1,true);expect(ui.challengeScroll.offset).toBeLessThan(ui.challengeScroll.max);
  ui.scrollBy(-100000);expect(ui.challengeScroll.offset).toBe(0);
  m.challenges=[];ui.draw(m);expect(ui.challengeScroll.max).toBe(0);expect(ui.dragScroll(.4,.5,true)).toBe(false);
  expect(ui.buttons.some(b=>b.kind==='page')).toBe(false);
 });
 it('holds an edge through tiny hand tremors but releases into gaps and adjacent targets',()=>{
  const ui=panel(),m=model();ui.draw(m);const i=ui.buttons.findIndex(b=>b.kind==='mode'),b=ui.buttons[i];
  const at=(x:number,y:number,previous=-1)=>ui.hit(x/1200,1-y/1000,previous),y=b.y+b.h/2;
  let hot=i;for(const dx of [-2,2,-1,3,-3,1]){hot=at(b.x+b.w+dx,y,hot);expect(hot).toBe(i);}
  expect(at(b.x+b.w+7,y,hot)).toBe(-1);
  const other=ui.buttons[i+1];expect(at(other.x+other.w/2,other.y+other.h/2,hot)).toBe(i+1);
  expect(ui.hit(NaN,.5,hot)).toBe(-1);expect(ui.hit(-1,.5,hot)).toBe(-1);
 });
 it('uploads only visible changes, exposes all colours for every look, and names About Dahrooj',()=>{
  const drawn:string[]=[],ui=panel(drawn),m=model();ui.draw(m);const texture=ui.mesh.material.map!,v=texture.version;
  ui.draw({...m,done:7,weather:'rain',challenges:[]});expect(texture.version).toBe(v);
  ui.show('appearance');for(const style of ['jelly','fur','bubble']){ui.draw({...m,style});expect(ui.buttons.filter(b=>b.kind==='jellyColor')).toHaveLength(7);}
  for(const english of [false,true]){drawn.length=0;ui.show('about');ui.draw({...m,english});expect(drawn).toContain(english?'Dahrooj':'دحروج');expect(drawn.some(s=>/quest|كويست/i.test(s))).toBe(false);}
 });
});
