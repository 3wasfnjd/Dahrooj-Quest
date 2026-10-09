import type {WebXRManager} from '@iwsdk/core';

export interface XRQualityOptions {foveation:number;framebufferScale:number}

// Restore the owner-tested request. The browser may clamp actual layer dimensions.
export function readXRQualityOptions(search:string):XRQualityOptions{
 const query=new URLSearchParams(search),enabled=query.get('xrdiag')==='1',requestedScale=Number(query.get('xrdiagScale'));
 if(!enabled)return {foveation:0,framebufferScale:10};
 return {foveation:enabled&&query.get('xrdiagFoveation')==='0'?0:.6,
  framebufferScale:enabled&&[1.25,1.5,2,4,5,10].includes(requestedScale)?requestedScale:1};
}

export function prepareXRQuality(xr:Pick<WebXRManager,'isPresenting'|'setFramebufferScaleFactor'>,quality:XRQualityOptions){
 // Layer size must be selected BEFORE launchXR; never resize an active session.
 if(xr.isPresenting)return;
 xr.setFramebufferScaleFactor(quality.framebufferScale);
}

export function diagnosticFoveation(preset:string,quality:XRQualityOptions){
 return preset==='no-foveation'?0:quality.foveation;
}
