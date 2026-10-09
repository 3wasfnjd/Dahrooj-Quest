// Preserve the geometry-bound fix when regenerating the reference stages.
export function deformedNetOverrides(path,source){
 const target=path==='src/reference/stages/hoop.js'?'ngeo':path==='src/reference/stages/goal.js'?'back.geo':null;
 if(!target)return source;
 const needle=target+'.attributes.position.needsUpdate=true;';
 if(!source.includes(needle))throw new Error('Deformed net source changed: '+path);
 return source.replace(needle,needle+'\n        // Invalidate stale bounds after vertex deformation.\n        '+target+'.boundingSphere=null;');
}
