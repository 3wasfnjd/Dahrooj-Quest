import type {Material} from '@iwsdk/core';

/** Reserve a thin near-depth band for the mode picker, preserving miniature self-occlusion.
 * Only clip depth changes: cards keep their real stereo positions and the head never moves.
 * This avoids world snow, projectiles and transparent effects cutting through the picker.
 */
export function menuDepth<T extends Material>(material:T):T{
 material.onBeforeCompile=shader=>{
  shader.vertexShader=shader.vertexShader.replace('#include <project_vertex>',
   '#include <project_vertex>\ngl_Position.z = gl_Position.z * 0.001 - gl_Position.w * 0.999;');
 };
 material.customProgramCacheKey=()=> 'dahrooj-menu-depth-v1';
 return material;
}
