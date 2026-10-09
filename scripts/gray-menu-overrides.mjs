// Owner-requested gray UI trial. World, character and projectile colours are unchanged.
export function grayMenuOverrides(file,source){
 if(file!=='src/reference/xr-runtime.js')return source;
 const end=source.indexOf('    function menuHit(uv){');
 if(end<0)throw Error('Missing gray menu boundary');
 let ui=source.slice(0,end);
 const colours=[
  ["PAPER='#fffaf2'","PAPER='#d0d0d0'"],
  ['rgba(255,252,246,','rgba(184,184,184,'],
  ["'#f6ede0'","'#c4c4c4'"],
  ["'#fffcf6'","'#a6a6a6'"],
  ["'#f0eae0'","'#969696'"],
  ['rgba(255,255,255,','rgba(196,196,196,'],
  ["'#fff'","'#c4c4c4'"],
  ["'#fff4d6'","'#c4c4c4'"]
 ];
 for(const [before,after] of colours){if(!ui.includes(before))throw Error('Missing gray UI colour: '+before);ui=ui.replaceAll(before,after);}
 source=ui+source.slice(end);
 for(const [before,after] of [['cream:pm(0xfffaf2)','cream:pm(0x909090)'],['color:0xf2eddf,depthWrite:true','color:0xa6a6a6,depthWrite:true']]){
  if(!source.includes(before))throw Error('Missing gray mode card colour: '+before);
  source=source.replace(before,after);
 }
 return source;
}
