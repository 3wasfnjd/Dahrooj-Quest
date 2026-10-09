import {describe,it,expect} from 'vitest';
import {readFileSync} from 'node:fs';
import {Color,Fog,PointLight,Group,Scene,Mesh,MeshBasicMaterial,PlaneGeometry,AlwaysDepth,LessEqualDepth} from '@iwsdk/core';
import {readDiagnosticOptions} from '../../src/rendering/diagnostic-options';
import {initialDiagnosticView,withRenderIsolation} from '../../src/rendering/diagnostic-isolation';
import {injectRendererOptions} from '../../scripts/renderer-options-plugin';

describe('opt-in rendering diagnostics',()=>{
 it('requires opt-in for direct comparison links and rejects unknown presets',()=>{
  expect(initialDiagnosticView('?xrdiagPreset=no-world&xrdiagBadge=0')).toEqual({preset:'baseline',badgeShown:true});
  expect(initialDiagnosticView('?xrdiag=1&xrdiagPreset=no-world&xrdiagBadge=0')).toEqual({preset:'no-world',badgeShown:false});
  expect(initialDiagnosticView('?xrdiag=1&xrdiagPreset=unknown')).toEqual({preset:'baseline',badgeShown:true});
 });
 it('hides only world geometry in VR, preserves gameplay and lights, and restores on failure',()=>{
  const scene=new Scene(),nature=new Group(),stage=new Group(),menu=new Group(),rain=new Group(),light=new PointLight(),geometry=new PlaneGeometry(1,1),material=new MeshBasicMaterial();
  const terrain=new Mesh(geometry,material),alreadyHidden=new Mesh(geometry,material),ground=new Mesh(geometry,material),floor=new Mesh(geometry,material),character=new Mesh(geometry,material);
  alreadyHidden.visible=false;ground.name='xr-world-shadow-ground';floor.name='xr-world-fallback-floor';
  nature.add(terrain,alreadyHidden,light);stage.add(new Mesh(geometry,material));rain.add(new Mesh(geometry,material));scene.add(nature,stage,menu,rain,ground,floor,character);
  const background=new Color(0x123456),fog=new Fog(0x998877,20,50);scene.background=background;scene.fog=fog;
  expect(()=>withRenderIsolation(scene,'no-world',{kind:'immersive-vr',nature,stage,menu},()=>{
   expect([terrain.visible,alreadyHidden.visible,ground.visible,floor.visible]).toEqual([false,false,false,false]);
   expect([nature.visible,light.visible,stage.visible,stage.children[0].visible,menu.visible,rain.visible,rain.children[0].visible,character.visible]).toEqual(Array(8).fill(true));
   expect(scene.background).not.toBe(background);expect(scene.fog).toBe(fog);throw Error('draw failed');
  })).toThrow('draw failed');
  expect([terrain.visible,alreadyHidden.visible,ground.visible,floor.visible]).toEqual([true,false,true,true]);expect(scene.background).toBe(background);
  for(const kind of ['immersive-ar',null])withRenderIsolation(scene,'no-world',{kind,nature,stage,menu},()=>{
   expect(terrain.visible).toBe(true);expect(ground.visible).toBe(true);expect(floor.visible).toBe(true);expect(scene.background).toBe(background);
  });
  geometry.dispose();material.dispose();
 });
 it('cannot change normal rendering through subordinate query parameters',()=>{
  for(const query of ['', '?xrdiag=0&xrdiagStereo=separate&xrdiagAA=0','?xrdiagStereo=separate&xrdiagAA=0'])expect(readDiagnosticOptions(query)).toEqual({enabled:false,stereo:'auto',antialias:true});
  expect(readDiagnosticOptions('?xrdiag=1&xrdiagStereo=separate&xrdiagAA=0')).toEqual({enabled:true,stereo:'separate',antialias:false});
  expect(readDiagnosticOptions('?xrdiag=1&xrdiagStereo=invalid&xrdiagAA=invalid')).toEqual({enabled:true,stereo:'auto',antialias:true});
 });
 it('hooks the installed SDK constructor and fails closed if its contract changes',()=>{
  const source=readFileSync(new URL('../../node_modules/@iwsdk/core/dist/init/world-initializer.js',import.meta.url),'utf8');
  const injected=injectRendererOptions(source,'/options.ts');
  expect(injected).toContain('...questRendererOptions(),');expect(injected).not.toContain('multiviewStereo: true,');
  expect(()=>injectRendererOptions('multiviewStereo: false,','/options.ts')).toThrow('hook changed');
  expect(()=>injectRendererOptions(source+source,'/options.ts')).toThrow('hook changed');
 });
 it('isolates the active stage without hiding menus, and restores all state even on render failure',()=>{
  const scene=new Scene(),stage=new Group(),menu=new Group(),nature=new Group();scene.add(stage,menu,nature);
  expect(()=>withRenderIsolation(scene,'no-stage',{stage,menu,nature},()=>{expect(stage.visible).toBe(false);expect(menu.visible).toBe(true);expect(nature.visible).toBe(true);throw new Error('GPU failure');})).toThrow('GPU failure');
  expect(stage.visible).toBe(true);stage.visible=false;
  withRenderIsolation(scene,'no-stage',{stage},()=>{});expect(stage.visible).toBe(false);
 });
 it('restores shared menu depth materials and keeps depth changes local to UI',()=>{
  const scene=new Scene(),menu=new Group(),material=new MeshBasicMaterial({depthFunc:AlwaysDepth}),geometry=new PlaneGeometry(1,1);
  menu.add(new Mesh(geometry,material),new Mesh(geometry,material));scene.add(menu);
  withRenderIsolation(scene,'world-depth',{menu},()=>expect(material.depthFunc).toBe(LessEqualDepth));expect(material.depthFunc).toBe(AlwaysDepth);
  expect(()=>withRenderIsolation(scene,'no-menu-depth',{menu},()=>{expect(material.depthTest).toBe(false);expect(material.depthWrite).toBe(false);throw Error('stop');})).toThrow('stop');
  expect(material.depthWrite).toBe(true);expect(material.depthTest).toBe(true);expect(material.depthFunc).toBe(AlwaysDepth);geometry.dispose();material.dispose();
 });
 it('separately masks weather particles and snow ground, while menus-only preserves nested UI',()=>{
  const scene=new Scene(),menu=new Group(),nested=new Group(),geometry=new PlaneGeometry(1,1),material=new MeshBasicMaterial();menu.add(nested);
  const label=new Mesh(geometry,material),particles=new Mesh(geometry,material),snow=new Mesh(geometry,material);nested.add(label);particles.name='xr-weather-particles';snow.name='xr-snow-ground';scene.add(menu,particles,snow);
  withRenderIsolation(scene,'no-particles',{menu},()=>{expect(particles.visible).toBe(false);expect(snow.visible).toBe(true);});
  withRenderIsolation(scene,'no-snow-ground',{menu},()=>{expect(snow.visible).toBe(false);expect(particles.visible).toBe(true);});
  withRenderIsolation(scene,'menus-only',{menu},()=>{expect(label.visible).toBe(true);expect(snow.visible).toBe(false);expect(particles.visible).toBe(false);});
  expect(snow.visible).toBe(true);expect(particles.visible).toBe(true);geometry.dispose();material.dispose();
 });
});
