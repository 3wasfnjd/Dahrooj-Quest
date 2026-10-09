// Preserve compact mode cards, smaller pole fireflies and vegetation edge stability when regenerating the reference port.
const replacements=[
  [
    "src/reference/nature.js",
    "gl_PointSize=clamp(90.*uScale/-mv.z,0.,14.);",
    "gl_PointSize=clamp(45.*uScale/-mv.z,0.,7.);"
  ],
  [
    "src/reference/nature.js",
    "const pts=new T.Points(geo,mat);pts.frustumCulled=false;root.add(pts);return mat.uniforms.uScale;",
    "const pts=new T.Points(geo,mat);pts.name='xr-pole-fireflies';pts.frustumCulled=false;root.add(pts);return mat.uniforms.uScale;"
  ],
  [
    "src/reference/xr-runtime.js",
    "    // B opens it: eight cards in two arcs around you at chest height. Point at one and it comes forward and its\n    // miniature comes alive; pull the trigger on it, or throw Dahrooj into it, to go there.",
    "    // Y opens nine compact cards on a single arc below the view. They stay at the opening pose.\n    // Point to enlarge one, then pull the trigger to select it. Old throws cannot choose a mode."
  ],
  [
    "src/reference/xr-runtime.js",
    "    const CARD_W=.26,CARD_H=.34;",
    "    const CARD_W=.26,CARD_H=.34,CARD_REST=.5,CARD_HOVER=.9;"
  ],
  [
    "src/reference/xr-runtime.js",
    "    // Two arcs of four, a little over a metre away, centred on where you look when it opens.\n    function placePlaza(){\n      const {pos,dir}=headLocal(),yaw=Math.atan2(dir.x,dir.z);\n      plaza.position.set(pos.x,0,pos.z);plaza.rotation.set(0,yaw,0);\n      // Five over four.\n      pcards.forEach((c,i)=>{const row=i<5?0:1,col=row?i-5:i,ang=(col-(row?1.5:2))*.34*(lang==='en'?1:-1),R=1.15;\n        c.home=V(Math.sin(ang)*R,pos.y+(row?-.42:.0)-.02,Math.cos(ang)*R);c.root.position.copy(c.home);c.root.rotation.set(0,ang+Math.PI,0);});\n    }",
    "    // One low arc, anchored once on opening: it does not chase the eyes as the player looks down.\n    function placePlaza(){\n      const {pos,dir}=headLocal(),yaw=Math.atan2(dir.x,dir.z),R=1.1;\n      plaza.position.set(pos.x,0,pos.z);plaza.rotation.set(0,yaw,0);\n      const viewer=V(0,pos.y,0),look=new T.Matrix4();\n      pcards.forEach((c,i)=>{\n        const ang=(i-(pcards.length-1)/2)*.17*(lang==='en'?1:-1);\n        c.home=V(Math.sin(ang)*R,pos.y-.44,Math.cos(ang)*R);c.root.position.copy(c.home);\n        c.root.quaternion.setFromRotationMatrix(look.lookAt(viewer,c.home,UP));\n        c.hot=0;c.mini.g.rotation.y=0;\n      });\n    }"
  ],
  [
    "src/reference/xr-runtime.js",
    "c.hot+=((hot?1:0)-c.hot)*Math.min(1,dt*10);",
    "c.hot+=((hot?1:0)-c.hot)*(1-Math.exp(-dt*12));"
  ],
  [
    "src/reference/xr-runtime.js",
    "const appear=clamp(plazaK*1.6-i*.08,0,1)",
    "const appear=clamp(plazaK*1.3-i*.03,0,1)"
  ],
  [
    "src/reference/xr-runtime.js",
    "        c.root.position.copy(c.home);\n        // The pointed card comes toward you.\n        c.root.position.multiplyScalar(1-.12*c.hot);\n        c.root.scale.setScalar(Math.max(.001,e*(1+.14*c.hot)));",
    "        c.root.position.copy(c.home);\n        // Enlarge upward from the same low strip without pulling the card off the pointer ray.\n        c.root.position.y+=(CARD_HOVER-CARD_REST)*CARD_H*.5*c.hot;\n        c.root.scale.setScalar(Math.max(.001,e*(CARD_REST+(CARD_HOVER-CARD_REST)*c.hot)));"
  ],
  [
    "src/reference/xr-runtime.js",
    "if(hot||clock<1)c.mini.step(clock);c.mini.g.rotation.y=Math.sin(clock*.6+i)*.35+(hot?clock*.8:0);",
    "if(hot)c.mini.step(clock);c.mini.g.rotation.y+=(Math.sin(clock*.9+i)*.25*c.hot-c.mini.g.rotation.y)*(1-Math.exp(-dt*8));"
  ],
  [
    "src/reference/nature.js",
    "  }\n\n  return (_T,{scene,hemi,sun,lineMat,court={x:0,z:-10}})=>{\n    const root=new T.Group();root.name='xr-nature';root.visible=false;scene.add(root);\n    let seed=7;const rng=()=>(seed=(seed*16807)%2147483647)/2147483647;\n    const perlin=perlinTexture();\n",
    "  }\n\n  return (_T,{scene,renderer,hemi,sun,lineMat,court={x:0,z:-10}})=>{\n    const root=new T.Group();root.name='xr-nature';root.visible=false;scene.add(root);\n    // Use the active XR target's MSAA when available; keep a hard-cutout fallback without MSAA.\n    const layer=renderer?.xr.getBaseLayer(),target=renderer?.getRenderTarget();\n    const coverageAA=target?.samples>0||(typeof layer?.antialias==='boolean'?layer.antialias:!!renderer?.getContext().getContextAttributes()?.antialias);\n    let seed=7;const rng=()=>(seed=(seed*16807)%2147483647)/2147483647;\n    const perlin=perlinTexture();\n"
  ],
  [
    "src/reference/nature.js",
    "          void main(){\n            vec3 p=position;float tip=corner<.5?1.:0.;vTip=tip;\n            float heightVariation=texture2D(uPerlin,p.xz*.0321).r+.5;\n            float h=bladeHeight*(bladeHeightRandomness*heightRandomness+(1.-bladeHeightRandomness))*heightVariation;\n            // On the pitch the grass is mown short so Dahrooj and the lines stay visible; Motri's height around it.\n            vec2 q=abs(p.xz-uPitch.xy)-uPitch.zw;h*=mix(.28,1.,smoothstep(0.,3.,max(q.x,q.y)));\n",
    "          void main(){\n            vec3 p=position;float tip=corner<.5?1.:0.;vTip=tip;\n            // Fade fine blades into the existing ground colour before they become distant pixel noise.\n            float distanceFade=1.-smoothstep(12.,24.,length(p.xz-uCam.xz));\n            if(distanceFade<=0.){gl_Position=vec4(2.,2.,2.,1.);return;}\n            float heightVariation=texture2D(uPerlin,p.xz*.0321).r+.5;\n            float h=bladeHeight*(bladeHeightRandomness*heightRandomness+(1.-bladeHeightRandomness))*heightVariation*distanceFade;\n            // On the pitch the grass is mown short so Dahrooj and the lines stay visible; Motri's height around it.\n            vec2 q=abs(p.xz-uPitch.xy)-uPitch.zw;h*=mix(.28,1.,smoothstep(0.,3.,max(q.x,q.y)));\n"
  ],
  [
    "src/reference/nature.js",
    "    })();\n    function foliage(matrices,colorA,colorB){\n      const mat=referenceShader(T,{uniforms:{...U,uFoliage:{value:foliageTexture},uColorA:{value:C(colorA)},uColorB:{value:C(colorB)},threshold:{value:.3}},side:T.DoubleSide,\n        vertexShader:WIND+`\n          varying vec4 vClip;varying float vDist;varying vec2 vUv;varying vec3 vNormal;varying float vTurn;\n",
    "    })();\n    function foliage(matrices,colorA,colorB){\n      const mat=referenceShader(T,{uniforms:{...U,uFoliage:{value:foliageTexture},uColorA:{value:C(colorA)},uColorB:{value:C(colorB)},threshold:{value:.3},uCoverageAA:{value:coverageAA?1:0}},side:T.DoubleSide,alphaToCoverage:coverageAA,transparent:false,depthWrite:true,\n        vertexShader:WIND+`\n          varying vec4 vClip;varying float vDist;varying vec2 vUv;varying vec3 vNormal;varying float vTurn;\n"
  ],
  [
    "src/reference/nature.js",
    "            vec4 mv=viewMatrix*modelMatrix*instanceMatrix*vec4(position,1.);vDist=-mv.z;gl_Position=projectionMatrix*mv;vClip=gl_Position;}`,\n        fragmentShader:SHADE+`\n          uniform sampler2D uFoliage;uniform vec3 uColorA,uColorB;uniform float threshold;varying vec2 vUv;varying vec3 vNormal;varying float vTurn;\n          void main(){\n            vec2 c=vUv-.5;float s=sin(vTurn),k=cos(vTurn);vec2 ruv=vec2(c.x*k-c.y*s,c.x*s+c.y*k)+.5;\n            float alpha=texture2D(uFoliage,ruv).r-threshold;if(alpha<.1)discard;\n            vec3 n=normalize(vNormal);if(!gl_FrontFacing)n=-n;\n            vec3 base=mix(uColorA,uColorB,smoothstep(0.,1.,dot(n,uLightDir)));\n            gl_FragColor=vec4(motriShade(base,n,0.),1.);}`});\n      const mesh=new T.InstancedMesh(foliageGeometry,mat,matrices.length);\n      matrices.forEach((m,i)=>mesh.setMatrixAt(i,m));mesh.frustumCulled=false;root.add(mesh);return mesh;\n    }\n    // Clumps face the player's usual view at a random roll, as Foliage.js faces the default camera.\n",
    "            vec4 mv=viewMatrix*modelMatrix*instanceMatrix*vec4(position,1.);vDist=-mv.z;gl_Position=projectionMatrix*mv;vClip=gl_Position;}`,\n        fragmentShader:SHADE+`\n          uniform sampler2D uFoliage;uniform vec3 uColorA,uColorB;uniform float threshold,uCoverageAA;varying vec2 vUv;varying vec3 vNormal;varying float vTurn;\n          void main(){\n            vec2 c=vUv-.5;float s=sin(vTurn),k=cos(vTurn);vec2 ruv=vec2(c.x*k-c.y*s,c.x*s+c.y*k)+.5;\n            float edge=texture2D(uFoliage,ruv).r-threshold-.1;\n            float width=max(fwidth(edge),.01);\n            float coverage=uCoverageAA>.5?smoothstep(-width,width,edge):step(0.,edge);\n            if(coverage<.001)discard;\n            vec3 n=normalize(vNormal);if(!gl_FrontFacing)n=-n;\n            vec3 base=mix(uColorA,uColorB,smoothstep(0.,1.,dot(n,uLightDir)));\n            gl_FragColor=vec4(motriShade(base,n,0.),coverage);}`});\n      const mesh=new T.InstancedMesh(foliageGeometry,mat,matrices.length);\n      matrices.forEach((m,i)=>mesh.setMatrixAt(i,m));mesh.computeBoundingSphere();mesh.name='xr-foliage';root.add(mesh);return mesh;\n    }\n    // Clumps face the player's usual view at a random roll, as Foliage.js faces the default camera.\n"
  ],
  [
    "src/reference/xr-runtime.js",
    "      renderer.xr.enabled=true;renderer.xr.setReferenceSpaceType('local-floor');\n      place();\n      if(mode==='immersive-vr'&&!nature&&createReferenceNature)nature=createReferenceNature(T,{scene,hemi:g.hemi,sun:g.sun,lineMat:g.lineMat});\n      // The world's own sounds: wind, leaves, rain, the pond, birds by day and crickets at night.\n      if(nature&&!ambience&&createReferenceAmbience&&g.audio)ambience=createReferenceAmbience({audio:g.audio,nature});\n",
    "      renderer.xr.enabled=true;renderer.xr.setReferenceSpaceType('local-floor');\n      place();\n      if(mode==='immersive-vr'&&!nature&&createReferenceNature)nature=createReferenceNature(T,{scene,renderer,hemi:g.hemi,sun:g.sun,lineMat:g.lineMat});\n      // The world's own sounds: wind, leaves, rain, the pond, birds by day and crickets at night.\n      if(nature&&!ambience&&createReferenceAmbience&&g.audio)ambience=createReferenceAmbience({audio:g.audio,nature});\n"
  ]
];
export function compactModesOverrides(file,source){
 for(const [path,before,after] of replacements){if(path!==file)continue;if(!source.includes(before))throw Error('Missing compact modes marker: '+before.slice(0,100));source=source.replace(before,after);}
 return source;
}
