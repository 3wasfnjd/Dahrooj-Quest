import type {WebXRManager} from '@iwsdk/core';

export interface XRQualityOptions {foveation:number;framebufferScale:number}

// Explicit, bounded experiments only. Removing xrdiag restores shipped quality.
export function readXRQualityOptions(search:string):XRQualityOptions{
 const query=new URLSearchParams(search),enabled=query.get('xrdiag')==='1';
 return {foveation:enabled&&query.get('xrdiagFoveation')==='0'?0:.6,
  framebufferScale:enabled&&query.get('xrdiagScale')==='1.25'?1.25:1};
}

export function prepareXRQuality(xr:Pick<WebXRManager,'isPresenting'|'setFramebufferScaleFactor'>,quality:XRQualityOptions){
 // Layer size must be selected BEFORE launchXR; never resize an active session.
 if(xr.isPresenting)return;
 xr.setFramebufferScaleFactor(quality.framebufferScale);
}

export function diagnosticFoveation(preset:string,quality:XRQualityOptions){
 return preset==='no-foveation'?0:quality.foveation;
}
