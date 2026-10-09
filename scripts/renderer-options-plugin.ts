import type {Plugin} from 'vite';
import {fileURLToPath} from 'node:url';

// IWSDK 1.0.1 hardcodes multiview at construction. One guarded build-time hook
// avoids node_modules edits and never toggles an active XR framebuffer.
export function injectRendererOptions(source:string,importPath:string){
 const needle='multiviewStereo: true,';
 if(source.split(needle).length!==2)throw new Error('IWSDK renderer hook changed; review before updating the SDK');
 return `import {questRendererOptions} from ${JSON.stringify(importPath)};\n`+source.replace(needle,'...questRendererOptions(),');
}
export function injectQualityHooks(source:string,importPath:string){
 const replacements=[
  ['framebufferScaleFactor: framebufferScaleFactor','framebufferScaleFactor: automaticLayerScale(framebufferScaleFactor, () => XRWebGLLayer.getNativeFramebufferScaleFactor(session))'],
  ['scaleFactor: framebufferScaleFactor','scaleFactor: automaticLayerScale(framebufferScaleFactor, () => this.getBinding().nativeProjectionScaleFactor)'],
  ['const views = pose.views;','const views = pose.views;\n automaticViews(views, session, time);'],
 ];
 for(const [needle,replacement] of replacements){
  if(source.split(needle).length!==2)throw new Error('XR quality hook changed; review before updating Three');
  source=source.replace(needle,replacement);
 }
 return `import {automaticLayerScale,automaticViews} from ${JSON.stringify(importPath)};\n`+source;
}
export function questRendererPlugin():Plugin{
 const options=fileURLToPath(new URL('../src/rendering/diagnostic-options.ts',import.meta.url));
 const quality=fileURLToPath(new URL('../src/rendering/auto-quality-bridge.ts',import.meta.url));
 return {name:'quest-renderer-options',enforce:'pre',transform(code,id){
  const path=id.split('?')[0].replaceAll('\\','/');
  if(path.endsWith('/src/renderers/webxr/WebXRManager.js')||path.endsWith('/three/build/three.module.js'))return {code:injectQualityHooks(code,quality),map:null};
  if(!id.split('?')[0].replaceAll('\\','/').endsWith('/@iwsdk/core/dist/init/world-initializer.js'))return;
  return {code:injectRendererOptions(code,options),map:null};
 }};
}
