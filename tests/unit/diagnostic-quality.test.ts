import {describe,it,expect,vi} from 'vitest';
import {diagnosticFoveation,prepareXRQuality,readXRQualityOptions} from '../../src/rendering/diagnostic-quality';
import {initialDiagnosticView} from '../../src/rendering/diagnostic-isolation';

describe('VR and AR quality comparisons',()=>{
 it('requires opt-in and bounds the render target allocation',()=>{
  for(const query of ['', '?xrdiagScale=1.25&xrdiagFoveation=0','?xrdiag=0&xrdiagScale=1.25&xrdiagFoveation=0']){
   expect(readXRQualityOptions(query)).toEqual({framebufferScale:10,foveation:0});
  }
  expect(readXRQualityOptions('?xrdiag=1&xrdiagFoveation=0')).toEqual({framebufferScale:1,foveation:0});
  expect(readXRQualityOptions('?xrdiag=1&xrdiagFoveation=0&xrdiagScale=1.25')).toEqual({framebufferScale:1.25,foveation:0});
  for(const scale of [1.25,1.5,2,4,5,10]){
   expect(readXRQualityOptions(`?xrdiag=1&xrdiagFoveation=0&xrdiagScale=${scale}`)).toEqual({framebufferScale:scale,foveation:0});
   expect(readXRQualityOptions(`?xrdiagScale=${scale}`).framebufferScale).toBe(10);
  }
  for(const scale of ['2.01','3','4.01','5.01','6','10.01','11','Infinity','NaN','-2','0','invalid'])expect(readXRQualityOptions(`?xrdiag=1&xrdiagScale=${scale}`).framebufferScale).toBe(1);
 });
 it('sets the same scale on successive VR and AR entries, and never resizes a live session',()=>{
  const xr={isPresenting:false,setFramebufferScaleFactor:vi.fn()},quality={framebufferScale:10,foveation:0};
  prepareXRQuality(xr,quality);expect(xr.setFramebufferScaleFactor).toHaveBeenLastCalledWith(10);
  prepareXRQuality(xr,quality);expect(xr.setFramebufferScaleFactor).toHaveBeenLastCalledWith(10);
  xr.isPresenting=true;prepareXRQuality(xr,quality);expect(xr.setFramebufferScaleFactor).toHaveBeenCalledTimes(2);
 });
 it('combines quality with world hiding and preserves the explicit foveation comparison',()=>{
  const query='?xrdiag=1&xrdiagPreset=no-world&xrdiagBadge=0&xrdiagFoveation=0&xrdiagScale=1.25';
  const quality=readXRQualityOptions(query),view=initialDiagnosticView(query);
  expect(view).toEqual({preset:'no-world',badgeShown:false});
  const worldLink='?xrdiag=1&xrdiagPreset=baseline&xrdiagBadge=0&xrdiagFoveation=0&xrdiagScale=10';
  expect(initialDiagnosticView(worldLink)).toEqual({preset:'baseline',badgeShown:false});
  expect(readXRQualityOptions(worldLink)).toEqual({framebufferScale:10,foveation:0});
  expect(diagnosticFoveation(view.preset,quality)).toBe(0);
  expect(diagnosticFoveation('baseline',readXRQualityOptions(''))).toBe(0);
  expect(diagnosticFoveation('no-foveation',quality)).toBe(0);
 });
});
