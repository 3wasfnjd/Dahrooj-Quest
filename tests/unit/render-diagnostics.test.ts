import {describe,it,expect} from 'vitest';
import {readFileSync} from 'node:fs';
import {Group,Scene,Mesh,MeshBasicMaterial,PlaneGeometry,AlwaysDepth,LessEqualDepth} from '@iwsdk/core';
import {readDiagnosticOptions} from '../../src/rendering/diagnostic-options';
import {withRenderIsolation} from '../../src/rendering/diagnostic-isolation';
import {injectRendererOptions} from '../../scripts/renderer-options-plugin';

describe('opt-in rendering diagnostics',()=>{
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
