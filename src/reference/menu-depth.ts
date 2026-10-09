import {AlwaysDepth,LessEqualDepth,NoBlending,type Material,type Object3D} from '@iwsdk/core';

export const MENU_GROUP_ORDER=1000;

/** A late, fully opaque UI group in the SAME XR render pass.
 * Three sorts opaque and transparent queues separately. `transparent` selects the late
 * queue only: NoBlending and alpha=1 keep the surfaces opaque, including in passthrough.
 * Keep real clip depth: compressing it lost precision and misreported distance to XR.
 */
export function menuDepth<T extends Material>(material:T,backdrop=false):T{
 material.transparent=true;
 material.blending=NoBlending;
 material.opacity=1;
 material.depthTest=material.depthWrite=true;
 material.depthFunc=backdrop?AlwaysDepth:LessEqualDepth;
 material.forceSinglePass=true;
 material.onBeforeCompile=shader=>{
  // Alpha test still trims label/corner cutouts; surviving pixels cannot expose passthrough.
  shader.fragmentShader=shader.fragmentShader.replace('#include <opaque_fragment>',
   '#include <opaque_fragment>\ngl_FragColor.a = 1.0;');
 };
 material.customProgramCacheKey=()=> 'dahrooj-menu-opaque-layer-v2';
 return material;
}

/** Nested Groups reset Three's group sort order, so tag every menu Group once at creation. */
export function menuGroup<T extends Object3D>(root:T):T{
 root.traverse(object=>{if('isGroup' in object&&object.isGroup)object.renderOrder=MENU_GROUP_ORDER;});
 return root;
}
