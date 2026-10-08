// Reference shaders shade in linear light, just like Three's built-in materials.
// Apply the renderer's output transform once, including XR linear render targets.
export function referenceShader(T,options){
 const end=options.fragmentShader.lastIndexOf('}');
 if(end<0)throw new Error('Missing shader main body');
 const fragmentShader=options.fragmentShader.slice(0,end)+'\n#include <tonemapping_fragment>\n#include <colorspace_fragment>\n'+options.fragmentShader.slice(end);
 return new T.ShaderMaterial({...options,fragmentShader});
}
