import {describe,it,expect,vi} from 'vitest';
import {diagnosticFoveation,prepareXRQuality,readXRQualityOptions} from '../../src/rendering/diagnostic-quality';
import {initialDiagnosticView} from '../../src/rendering/diagnostic-isolation';

describe('VR and AR quality comparisons',()=>{
 it('requires opt-in and bounds the render target allocation',()=>{
  for(const query of ['', '?xrdiagScale=1.25&xrdiagFoveation=0','?xrdiag=0&xrdiagScale=1.25&xrdiagFoveation=0','?xrdiag=1&xrdiagScale=999&xrdiagFoveation=-1']){
   expect(readXRQualityOptions(query)).toEqual({framebufferScale:1,foveation:.6});
  }
  expect(readXRQualityOptions('?xrdiag=1&xrdiagFoveation=0')).toEqual({framebufferScale:1,foveation:0});
  expect(readXRQualityOptions('?xrdiag=1&xrdiagFoveation=0&xrdiagScale=1.25')).toEqual({framebufferScale:1.25,foveation:0});
 });
 it('sets the same scale on successive VR and AR entries, and never resizes a live session',()=>{
  const xr={isPresenting:false,setFramebufferScaleFactor:vi.fn()},quality={framebufferScale:1.25,foveation:0};
  prepareXRQuality(xr,quality);expect(xr.setFramebufferScaleFactor).toHaveBeenLastCalledWith(1.25);
  prepareXRQuality(xr,quality);expect(xr.setFramebufferScaleFactor).toHaveBeenLastCalledWith(1.25);
  xr.isPresenting=true;prepareXRQuality(xr,quality);expect(xr.setFramebufferScaleFactor).toHaveBeenCalledTimes(2);
 });
 it('combines quality with world hiding and preserves the explicit foveation comparison',()=>{
  const query='?xrdiag=1&xrdiagPreset=no-world&xrdiagBadge=0&xrdiagFoveation=0&xrdiagScale=1.25';
  const quality=readXRQualityOptions(query),view=initialDiagnosticView(query);
  expect(view).toEqual({preset:'no-world',badgeShown:false});
  expect(diagnosticFoveation(view.preset,quality)).toBe(0);
  expect(diagnosticFoveation('baseline',readXRQualityOptions(''))).toBe(.6);
  expect(diagnosticFoveation('no-foveation',quality)).toBe(0);
 });
});
