/* eslint-disable @typescript-eslint/no-explicit-any -- Read actual GPU pixels for sub-millimetre UI depth separation. */
import {test,expect} from '@playwright/test';
test('menu surfaces keep correct depth separation across 100 viewer positions',async({page},info)=>{
 await page.goto('/');await page.waitForFunction(()=>!!(window as any).__DAHROOJ_REFERENCE__?.ready);
 const result=await page.evaluate(async()=>{
  const source='/src/reference/menu-depth.ts',{menuDepth}=await import(source);
  const g=(window as any).__DAHROOJ_REFERENCE__.game,T=g.ctx.T,renderer=g.world.renderer;
  const saved=renderer.getRenderTarget(),target=new T.WebGLRenderTarget(16,16,{depthTexture:new T.DepthTexture(16,16,T.UnsignedIntType)});
  const scene=new T.Scene(),camera=new T.PerspectiveCamera(50,1,.03,65),geometry=new T.PlaneGeometry(.4,.4),pixels=new Uint8Array(4);
  const front=new T.Mesh(geometry,menuDepth(new T.MeshBasicMaterial({color:0x00ff00}))),back=new T.Mesh(geometry,menuDepth(new T.MeshBasicMaterial({color:0xff0000})));
  front.position.z=-1.1;back.position.z=-1.101;back.renderOrder=1;scene.add(front,back);
  const runs=[];renderer.setRenderTarget(target);
  try{
   for(let i=0;i<100;i++){
    camera.position.z=(i-50)*.002;camera.updateMatrixWorld();renderer.render(scene,camera);renderer.readRenderTargetPixels(target,8,8,1,1,pixels);
    runs.push({z:camera.position.z,color:Array.from(pixels)});
   }
   return {depthBits:renderer.getContext().getParameter(renderer.getContext().DEPTH_BITS),wrong:runs.filter(x=>x.color[0]>200).length,correct:runs.filter(x=>x.color[1]>200).length,runs};
  }finally{renderer.setRenderTarget(saved);target.dispose();geometry.dispose();front.material.dispose();back.material.dispose();}
 });
 await info.attach('menu-depth-probe',{body:JSON.stringify(result,null,2),contentType:'application/json'});
 console.log('Menu depth separation:',JSON.stringify({depthBits:result.depthBits,wrong:result.wrong,correct:result.correct}));
 expect(result.depthBits).toBe(24);expect(result.wrong).toBe(0);expect(result.correct).toBe(100);
});

test('opaque menus cover world effects without changing their real depth or passthrough alpha',async({page},info)=>{
 await page.goto('/');await page.waitForFunction(()=>!!(window as any).__DAHROOJ_REFERENCE__?.ready);
 const result=await page.evaluate(async()=>{
  const source='/src/reference/menu-depth.ts',{menuDepth,menuGroup}=await import(source);
  const g=(window as any).__DAHROOJ_REFERENCE__.game,T=g.ctx.T,r=g.world.renderer,saved=r.getRenderTarget();
  const target=new T.WebGLRenderTarget(32,32,{depthTexture:new T.DepthTexture(32,32,T.UnsignedIntType)}),readback=new T.WebGLRenderTarget(32,32),camera=new T.PerspectiveCamera(50,1,.03,65),scene=new T.Scene(),plane=new T.PlaneGeometry(2,2),pixel=new Uint8Array(4);
  // A world effect in front of the panel must finish before UI even with high renderOrder.
  const effect=new T.Mesh(plane,new T.MeshBasicMaterial({color:0xff0000,transparent:true,opacity:.7}));effect.position.z=-.4;effect.renderOrder=9999;scene.add(effect);
  const root=new T.Group(),nested=new T.Group();root.add(nested);scene.add(root);
  const backdrop=new T.Mesh(plane,menuDepth(new T.MeshBasicMaterial({color:0x0000ff}),true));backdrop.scale.setScalar(.2);backdrop.position.z=-1.1;backdrop.renderOrder=50;nested.add(backdrop);
  const canvas=document.createElement('canvas');canvas.width=canvas.height=2;const context=canvas.getContext('2d')!;context.fillStyle='rgba(0,255,0,.75)';context.fillRect(0,0,2,2);
  const map=new T.CanvasTexture(canvas),label=new T.Mesh(plane,menuDepth(new T.MeshBasicMaterial({map,alphaTest:.5})));label.scale.setScalar(.1);label.position.z=-1.099;label.renderOrder=70;nested.add(label);menuGroup(root);
  const depthScene=new T.Scene(),depthMaterial=new T.ShaderMaterial({uniforms:{depth:{value:target.depthTexture}},vertexShader:'varying vec2 p;void main(){p=uv;gl_Position=vec4(position.xy,0.,1.);}',fragmentShader:'uniform sampler2D depth;varying vec2 p;void main(){gl_FragColor=vec4(vec3(texture2D(depth,p).r),1.);}'});depthScene.add(new T.Mesh(plane,depthMaterial));
  try{
   r.setRenderTarget(target);r.render(scene,camera);r.readRenderTargetPixels(target,16,16,1,1,pixel);const centre=Array.from(pixel);r.readRenderTargetPixels(target,1,1,1,1,pixel);const outside=Array.from(pixel);
   r.setRenderTarget(readback);r.render(depthScene,camera);r.readRenderTargetPixels(readback,16,16,1,1,pixel);const depth=Array.from(pixel);
   return {centre,outside,depth};
  }finally{r.setRenderTarget(saved);target.dispose();readback.dispose();plane.dispose();effect.material.dispose();backdrop.material.dispose();label.material.dispose();map.dispose();depthMaterial.dispose();}
 });
 expect(result.centre[0]).toBe(0);expect(result.centre[1]).toBeGreaterThan(245);expect(result.centre[2]).toBe(0);expect(result.centre[3]).toBe(255);
 expect(result.outside[0]).toBeGreaterThan(150);expect(result.outside[1]).toBe(0);
 expect(result.depth[0]).toBeGreaterThan(240);
 await info.attach('world-and-menu-pixels',{body:JSON.stringify(result,null,2),contentType:'application/json'});
});
