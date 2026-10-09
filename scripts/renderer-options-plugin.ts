import type {Plugin} from 'vite';
import {fileURLToPath} from 'node:url';

// IWSDK 1.0.1 hardcodes multiview at construction. One guarded build-time hook
// avoids node_modules edits and never toggles an active XR framebuffer.
export function injectRendererOptions(source:string,importPath:string){
 const needle='multiviewStereo: true,';
 if(source.split(needle).length!==2)throw new Error('IWSDK renderer hook changed; review before updating the SDK');
 return `import {questRendererOptions} from ${JSON.stringify(importPath)};\n`+source.replace(needle,'...questRendererOptions(),');
}
export function questRendererPlugin():Plugin{
 const options=fileURLToPath(new URL('../src/rendering/diagnostic-options.ts',import.meta.url));
 return {name:'quest-renderer-options',enforce:'pre',transform(code,id){
  if(!id.split('?')[0].replaceAll('\\','/').endsWith('/@iwsdk/core/dist/init/world-initializer.js'))return;
  return {code:injectRendererOptions(code,options),map:null};
 }};
}
