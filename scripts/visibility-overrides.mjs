// Keep the shared mode materials and fill light readable on the IWSDK renderer.
const replacements = [
 ['src/reference/stage-art.js',
  'postMat=new T.MeshStandardMaterial({color:INK,roughness:.7}),netMat=new T.LineBasicMaterial({color:INK,transparent:true,opacity:.3})',
  'postMat=new T.MeshStandardMaterial({color:0xf6eee2,roughness:.7,emissive:0xf6eee2,emissiveIntensity:.025}),netMat=new T.LineBasicMaterial({color:0xf3eddf,transparent:true,opacity:.65,depthWrite:false})'],
 ['src/reference/stages/hoop.js',
  'new T.TorusGeometry(RR,TUBE,10,48),postMat',
  'new T.TorusGeometry(RR,TUBE,10,48),new T.MeshStandardMaterial({color:0xff703c,roughness:.65,emissive:0xff703c,emissiveIntensity:.035})'],
 ['src/reference/stages/hoop.js',
  'bar,INK,postMat,netMat',
  'bar,INK,netMat'],
 ['src/reference/stages/cans.js',
  'color:0xc9c4bb,metalness:0.35,roughness:0.35',
  'color:0xeeeae3,metalness:0.12,roughness:0.48'],
 ['src/reference/stages/cans.js',
  'new T.MeshStandardMaterial({color:0xe2603f,roughness:0.6}),new T.MeshStandardMaterial({color:0x2c2d3d,roughness:0.6})',
  'new T.MeshStandardMaterial({color:0xff805c,roughness:0.6,emissive:0xff805c,emissiveIntensity:.035}),new T.MeshStandardMaterial({color:0x57b8f0,roughness:0.6,emissive:0x57b8f0,emissiveIntensity:.035})'],
 ['src/reference/nature.js',
  'hemi.groundColor.copy(d.shadowColor).lerp(grassColor,.5).lerp(C(\'#8c8aa8\'),night*.4);',
  "hemi.groundColor.copy(d.shadowColor).lerp(C('#c1c8d6'),.6);"],
 ['src/reference/nature.js',
  'hemi.intensity=Math.max(.75,.6*d.lightIntensity*k);',
  'hemi.intensity=Math.max(1.65,1.4*d.lightIntensity*k);'],
 ['src/reference/nature.js',
  'sun.intensity=Math.max(.35,.5*d.lightIntensity*k);',
  'sun.intensity=Math.max(1.15,1.6*d.lightIntensity*k);'],
];
export function visibilityOverrides(file,source){
 for(const [path,before,after] of replacements){
  if(path!==file)continue;
  if(!source.includes(before))throw new Error('Visibility override no longer matches: '+file);
  source=source.replaceAll(before,after);
 }
 return source;
}
