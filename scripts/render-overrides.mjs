// Keep owner-requested VR readability fixes when regenerating the reference port.
export function renderOverrides(file,s){
 if(file.endsWith('/nature.js')||file.endsWith('/character.js')){
  s="import {referenceShader} from './render-color.js';\n"+s;
  s=s.replaceAll('new T.ShaderMaterial(', 'referenceShader(T,');
 }
 if(file.endsWith('/nature.js')){
  const presets={
   day:"lightColor:C('#fff1dd'),lightIntensity:1.35,shadowColor:C('#8b9cae'),fogColorA:C('#dcebf4'),fogColorB:C('#83b7e0'),fogNearRatio:.5,fogFarRatio:2,temperature:5",
   dusk:"lightColor:C('#ffd5b2'),lightIntensity:1.05,shadowColor:C('#7c7694'),fogColorA:C('#e1b8ad'),fogColorB:C('#7a8dab'),fogNearRatio:.5,fogFarRatio:2,temperature:0",
   night:"lightColor:C('#c4d6ff'),lightIntensity:.9,shadowColor:C('#525f7a'),fogColorA:C('#384a69'),fogColorB:C('#172b4a'),fogNearRatio:.65,fogFarRatio:2.4,temperature:-7.5",
   dawn:"lightColor:C('#ffe0c2'),lightIntensity:1.15,shadowColor:C('#8891a8'),fogColorA:C('#f2d4bd'),fogColorB:C('#9dbbda'),fogNearRatio:.5,fogFarRatio:2,temperature:0"
  };
  for(const [key,value] of Object.entries(presets))s=s.replace(new RegExp(key+':\\s*\\{lightColor:[^\\n]+?\\}'),key+':{'+value+'}');
 }
 if(file.endsWith('/xr-runtime.js')){
  s=s.replace('const tex=new T.CanvasTexture(canvas);','const tex=new T.CanvasTexture(canvas);tex.colorSpace=T.SRGBColorSpace;tex.anisotropy=Math.min(4,renderer.capabilities.getMaxAnisotropy());');
  s=s.replace('map:tex,transparent:true,depthTest:false','map:tex,transparent:true,depthTest:false,depthWrite:false,fog:false,toneMapped:false');
  s=s.replace('rgba(255,252,246,.78)','rgba(255,252,246,.98)').replace('rgba(240,234,224,.62)','rgba(240,234,224,.97)');
  s=s.replace("gr.addColorStop(0,'rgba(255,255,255,.55)')","gr.addColorStop(0,'rgba(255,255,255,.12)')").replace("gr.addColorStop(.7,'rgba(255,255,255,.18)')","gr.addColorStop(.7,'rgba(255,255,255,.04)')");
  s=s.replaceAll('rgba(44,45,61,.62)','rgba(44,45,61,.85)');
  s=s.replace('opacity:.86,depthWrite:false','opacity:.98,depthWrite:false,fog:false,toneMapped:false').replace('c.pane.material.opacity=.86*e','c.pane.material.opacity=.98*e');
  s=s.replace('lc.width=256;lc.height=96;const lt=new T.CanvasTexture(lc);','lc.width=512;lc.height=192;const lt=new T.CanvasTexture(lc);lt.colorSpace=T.SRGBColorSpace;lt.anisotropy=Math.min(4,renderer.capabilities.getMaxAnisotropy());');
  s=s.replace('map:lt,transparent:true,depthWrite:false','map:lt,transparent:true,depthWrite:false,fog:false,toneMapped:false');
  s=s.replace("const x=c.lc.getContext('2d');x.clearRect","const x=c.lc.getContext('2d');x.setTransform(2,0,0,2,0,0);x.clearRect");
  s=s.replace("try{const bl=s.renderState.baseLayer;if(bl&&'fixedFoveation' in bl)bl.fixedFoveation=1;}catch(_){}",'renderer.xr.setFoveation(.6);');
 }
 return s;
}
