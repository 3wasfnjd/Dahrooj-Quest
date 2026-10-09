export type StereoRequest = 'auto' | 'separate';
export interface DiagnosticOptions { enabled:boolean; stereo:StereoRequest; antialias:boolean }

// No storage: removing xrdiag=1 restores the shipped renderer on the next load.
export function readDiagnosticOptions(search:string):DiagnosticOptions {
 const query=new URLSearchParams(search),enabled=query.get('xrdiag')==='1';
 return {enabled,stereo:enabled&&query.get('xrdiagStereo')==='separate'?'separate':'auto',antialias:!enabled||query.get('xrdiagAA')!=='0'};
}
export function questRendererOptions(){
 const options=readDiagnosticOptions(typeof location==='undefined'?'':location.search);
 return {multiviewStereo:options.stereo!=='separate',antialias:options.antialias};
}
