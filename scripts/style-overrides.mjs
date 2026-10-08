/** Owner-requested clean, cheerful palette. Applied after reference extraction so regeneration keeps it. */
export function styleOverrides(file,s){
 if(file.endsWith('/character.js')){
  s="import {DAHROOJ_COLORS} from './palette.js';\n"+s;
  const cut=(a,b)=>{const start=s.indexOf(a),end=s.indexOf(b,start);if(start<0||end<0)throw Error('Missing character surface marker: '+a);s=s.slice(0,start)+s.slice(end);};
  cut('    let seed=7;','    /* ---------- a soft room');
  cut('    const feltMap=','    // The fur ball');
  cut('    // Move the random sequence','    /* ---------- jelly:');
  cut('    function stitches(){','    // The ribbon sits');
  s=s.replace('({bandaid,stitches,bow})','({bandaid,bow})').replace("      if(style==='fabric')inner.add(decoration('stitches'));",'');
  s=s.replace('uAbsorb:{value:new T.Vector3(.55,.5,.4)},uTint:{value:new T.Color(0x5d616e)}','uAbsorb:{value:new T.Vector3(.08,1.15,.3)},uTint:{value:new T.Color(DAHROOJ_COLORS.jelly)}');
  const a=s.indexOf('      fabric:()=>'),b=s.indexOf('      // The skin',a);if(a<0||b<0)throw Error('Missing material block');
  s=s.slice(0,a)+`      fabric:()=>new T.MeshStandardMaterial({color:DAHROOJ_COLORS.fabric,roughness:.82,envMap:env,envMapIntensity:.35}),
      clay:()=>new T.MeshStandardMaterial({color:DAHROOJ_COLORS.clay,roughness:.72,envMap:env,envMapIntensity:.5}),
`+s.slice(b);
 }
 if(file.endsWith('/face.js'))s=s.replace(/  if\(ballStyle==='fabric'\)\{ c\.save\(\);[^\n]+\n/,'');
 if(file.endsWith('/xr-runtime.js')){
  s="import {DAHROOJ_COLORS,DAHROOJ_SWATCHES} from './palette.js';\n"+s;
  s=s.replace(/const STYLE_DOTS=\{[^\n]+\};/,'const STYLE_DOTS=DAHROOJ_SWATCHES;').replace(/const STYLE_COLORS=\{[^\n]+\};/,'const STYLE_COLORS=DAHROOJ_COLORS;');
  s=s.replace("bg.addColorStop(0,'#6b6f7a');bg.addColorStop(1,'#3a3d45');",'bg.addColorStop(0,DAHROOJ_SWATCHES.jelly[0]);bg.addColorStop(1,DAHROOJ_SWATCHES.jelly[1]);');
 }
 return s;
}
