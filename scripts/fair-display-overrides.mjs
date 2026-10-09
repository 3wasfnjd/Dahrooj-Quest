// Preserve the owner-requested fair display, collision and stable menu/weather rendering.
const replacements=[
  [
    "src/reference/stages/fair.js",
    "export default function create(ctx)",
    "import {collideSolidBox} from '../solid-box';\nexport default function create(ctx)"
  ],
  [
    "src/reference/stages/fair.js",
    "const signC=document.createElement('canvas'); signC.width=512; signC.height=128; const sg=signC.getContext('2d'), signT=new T.CanvasTexture(signC);",
    "const signC=document.createElement('canvas');signC.width=1024;signC.height=256;const sg=signC.getContext('2d'),signT=new T.CanvasTexture(signC);\n    signT.colorSpace=T.SRGBColorSpace;signT.generateMipmaps=false;signT.minFilter=T.LinearFilter;"
  ],
  [
    "src/reference/stages/fair.js",
    "add(rbox(2.6,0.66,0.12,0.05,cream),0,4.05,FZ-0.35);",
    "add(rbox(2.7,0.76,0.14,0.05,mat(0x243133,{roughness:.85})),0,4.05,FZ-0.35);"
  ],
  [
    "src/reference/stages/fair.js",
    "const sign=new T.Mesh(new T.PlaneGeometry(2.4,0.6),new T.MeshBasicMaterial({map:signT,transparent:true})); sign.position.set(0,4.05,FZ-0.28); grp.add(sign);",
    "const sign=new T.Mesh(new T.PlaneGeometry(2.5,0.625),new T.MeshBasicMaterial({map:signT,toneMapped:false,fog:false}));sign.name='xr-fair-screen';sign.position.set(0,4.05,FZ-0.268);grp.add(sign);"
  ],
  [
    "src/reference/stages/fair.js",
    "      sg.clearRect(0,0,512,128); sg.fillStyle=COL.ink; sg.textAlign='center'; sg.font='800 64px \"Dahrooj\",Tahoma,sans-serif';\n      const t=Math.ceil(F.time), left=F.on?(en?`${t}s`:`${ar(t)} ث`):(en?'Throw to start':'ارمِ وابدأ');\n      sg.fillText(left,128,84); sg.fillStyle=COL.coral||'#e2603f'; sg.fillText(en?String(F.score):ar(F.score),384,84);\n      sg.font='600 22px Tahoma,sans-serif'; sg.fillStyle='rgba(44,45,61,.6)'; sg.fillText(en?`best ${F.best}`:`أفضل ${ar(F.best)}`,384,118);\n      signT.needsUpdate=true;",
    "      // Cached retro LED display: steady light, no flashing scanlines or new textures.\n      sg.fillStyle='#081816';sg.fillRect(0,0,1024,256);\n      sg.fillStyle='#112520';for(let y=8;y<256;y+=12)for(let x=8;x<1024;x+=12){sg.beginPath();sg.arc(x,y,1.1,0,Math.PI*2);sg.fill();}\n      sg.fillStyle='#486052';sg.fillRect(507,24,3,208);\n      sg.textAlign='center';sg.direction=en?'ltr':'rtl';sg.font='700 31px \"Dahrooj\",Tahoma,sans-serif';\n      sg.fillStyle='#b7dec3';sg.fillText(en?'TIME':'الوقت',252,42);sg.fillText(en?'SCORE':'النقاط',766,42);\n      const segments=[0x3f,0x06,0x5b,0x4f,0x66,0x6d,0x7d,0x07,0x7f,0x6f];\n      const bars=[[7,0,44,9],[52,8,9,43],[52,59,9,43],[7,101,44,9],[0,59,9,43],[0,8,9,43],[7,51,44,9]];\n      function led(value,cx,color){const text=String(value).padStart(2,'0'),scale=Math.min(1,410/(text.length*76));sg.save();sg.translate(cx-text.length*76*scale/2,67);sg.scale(scale,scale);\n        for(let i=0;i<text.length;i++)for(let j=0;j<7;j++){sg.fillStyle=(segments[+text[i]]&(1<<j))?color:'#18312a';const b=bars[j];sg.fillRect(i*76+b[0],b[1],b[2],b[3]);}sg.restore();}\n      led(Math.max(0,Math.ceil(F.time)),252,'#ffcb62');led(F.score,766,'#79f5b3');\n      sg.fillStyle='#c9d8b2';sg.font='600 29px \"Dahrooj\",Tahoma,sans-serif';\n      sg.fillText(F.on?(en?'SECONDS':'ثانية'):(en?'THROW TO START':'ارمِ وابدأ'),252,229);\n      sg.fillText(en?`BEST ${F.best}`:`أفضل ${ar(F.best)}`,766,229);\n      signT.needsUpdate=true;"
  ],
  [
    "src/reference/stages/fair.js",
    "    const wp=V(0,0,0);",
    "    const wp=V(0,0,0),bodyPrev=V(),bodyNormal=V();\n    function collideBody(p,v,r,previous){\n      // Counter and lower cabinet are solid on every face, with a sweep for hard throws.\n      return collideSolidBox(p,v,r,previous,stall[1].c,stall[1].h,bodyNormal);\n    }"
  ],
  [
    "src/reference/stages/fair.js",
    "      grp, aimZ:FZ, farZ:FZ-1.5, reachZ:-18.5,",
    "      grp, aimZ:FZ, farZ:FZ-1.5, reachZ:-18.5,collideBody,"
  ],
  [
    "src/reference/stages/fair.js",
    "        if(!S.shot||F.over>0) return;",
    "        if(!S.shot)return;\n        bodyPrev.set(S.prevX??P.x,S.prevY??P.y,S.prevZ??P.z);\n        const incoming=S.vel.length();if(collideBody(P,S.vel,BR,bodyPrev)){hit(bodyNormal,incoming,P);S.side.set(0,0,0);}\n        if(F.over>0)return;"
  ],
  [
    "src/reference/stages/fair.js",
    "        if(Math.abs(P.x)<3.3&&P.z>FZ-0.3&&P.z<FZ+0.7&&P.y-BR<CY+0.08&&P.y>CY-0.3){ P.y=CY+0.08+BR; if(S.vel.y<0){ hit(UP,-S.vel.y,V(P.x,CY+0.08,P.z)); S.vel.y=-S.vel.y*0.45; } }",
    ""
  ],
  [
    "src/reference/game-state.js",
    "'prevZ','prevY'",
    "'prevX','prevZ','prevY'"
  ],
  [
    "src/reference/game-state.js",
    "S.prevZ=S.pos.z; S.prevY=S.pos.y;",
    "S.prevX=S.pos.x; S.prevZ=S.pos.z; S.prevY=S.pos.y;"
  ],
  [
    "src/reference/game-state.js",
    "S.prevZ=P.z; S.prevY=P.y;",
    "S.prevX=P.x; S.prevZ=P.z; S.prevY=P.y;"
  ],
  [
    "src/reference/xr-runtime.js",
    "import {ballImpactSpeed}",
    "import {menuDepth} from './menu-depth';\nimport {ballImpactSpeed}"
  ],
  [
    "src/reference/xr-runtime.js",
    "    function stepRests(dt){",
    "    const restPrev=V();\n    function stepRests(dt){"
  ],
  [
    "src/reference/xr-runtime.js",
    "        const p=r.p,v=r.v;v.y-=G*dt;p.addScaledVector(v,dt);",
    "        const p=r.p,v=r.v;restPrev.copy(p);v.y-=G*dt;p.addScaledVector(v,dt);g.stage()?.collideBody?.(p,v,BR,restPrev);"
  ],
  [
    "src/reference/xr-runtime.js",
    "const pm=(c,o={})=>new T.MeshStandardMaterial({color:c,roughness:.5,...o});",
    "const pm=(c,o={})=>menuDepth(new T.MeshStandardMaterial({color:c,roughness:.8,...o,toneMapped:false,fog:false}));"
  ],
  [
    "src/reference/xr-runtime.js",
    "new T.MeshBasicMaterial({color:0xfffaf2,transparent:true,opacity:.98,depthWrite:false,fog:false,toneMapped:false}));pane.renderOrder=6;",
    "menuDepth(new T.MeshBasicMaterial({color:0xf2eddf,transparent:true,opacity:.98,depthWrite:false,fog:false,toneMapped:false})));pane.renderOrder=50;"
  ],
  [
    "src/reference/xr-runtime.js",
    "new T.MeshBasicMaterial({color:0xf2c14e,transparent:true,opacity:0,depthWrite:false}));ring.scale.setScalar(1.06);ring.position.z=-.002;ring.renderOrder=5;",
    "menuDepth(new T.MeshBasicMaterial({color:0xf2c14e,transparent:true,opacity:0,depthWrite:false,fog:false,toneMapped:false})));ring.scale.setScalar(1.06);ring.position.z=-.012;ring.renderOrder=49;"
  ],
  [
    "src/reference/xr-runtime.js",
    "new T.MeshBasicMaterial({map:lt,transparent:true,depthWrite:false,fog:false,toneMapped:false}));label.position.set(0,-CARD_H/2+.045,.003);label.renderOrder=7;",
    "menuDepth(new T.MeshBasicMaterial({map:lt,transparent:true,depthWrite:false,fog:false,toneMapped:false})));label.position.set(0,-CARD_H/2+.045,.012);label.renderOrder=51;"
  ],
  [
    "src/reference/xr-runtime.js",
    "c.root.position.copy(c.home);c.root.position.y+=Math.sin(clock*1.3+i)*.012;",
    "c.root.position.copy(c.home);"
  ],
  [
    "src/reference/nature.js",
    "uniforms:rainU,transparent:true,side:T.DoubleSide,",
    "uniforms:rainU,transparent:true,depthWrite:false,side:T.DoubleSide,forceSinglePass:true,"
  ],
  [
    "src/reference/nature.js",
    "varying vec4 vClip;varying float vDist;\n          void main(){vec3 p=position;vec2 tangent=vec2(.707,-.707);",
    "varying vec4 vClip;varying float vDist;varying vec2 vFlake;\n          void main(){vFlake=offset;vec3 p=position;vec2 tangent=vec2(.707,-.707);"
  ],
  [
    "src/reference/nature.js",
    "fragmentShader:SHADE+'void main(){gl_FragColor=vec4(motriShade(vec3(1.),vec3(0.,1.,0.),0.),1.);}'",
    "fragmentShader:SHADE+'varying vec2 vFlake;void main(){vec2 edge=min(vFlake,1.-vFlake);float alpha=smoothstep(0.,.25,edge.x)*smoothstep(0.,.18,edge.y)*.65;gl_FragColor=vec4(motriShade(vec3(.82,.86,.9),vec3(0.,1.,0.),0.),alpha);}'"
  ],
  [
    "src/reference/nature.js",
    "m.frustumCulled=false;m.renderOrder=1;root.add(m);return m;",
    "m.name='xr-weather-particles';m.frustumCulled=false;m.renderOrder=1;root.add(m);return m;"
  ],
  [
    "src/reference/nature.js",
    "/* ---------- Snow.js: snow that builds up on the ground in noisy drifts, with glitter ---------- */",
    "/* ---------- Snow.js: soft, stable snow drifts without animated glitter ---------- */"
  ],
  [
    "src/reference/nature.js",
    "uniforms:snowU,transparent:true,",
    "uniforms:snowU,transparent:true,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-1,polygonOffsetUnits:-1,"
  ],
  [
    "src/reference/nature.js",
    "p.y=max(e,0.)*.25+.01;",
    "p.y=max(e,0.)*.25+.025;"
  ],
  [
    "src/reference/nature.js",
    "            vec3 col=motriShade(vec3(1.),vec3(0.,1.,0.),0.);\n            float glitter=abs(mod(hash(floor(vWorld*.2*64.))*2.+uTime*.024,2.)-1.)*clamp(texture2D(uPerlin,vWorld*.05).r*2.,0.,1.);\n            col+=pow(glitter,1000.)*2.;gl_FragColor=vec4(col,alpha);",
    "            float grain=texture2D(uPerlin,vWorld*.18).r;\n            vec3 col=motriShade(vec3(.86,.9,.94)*(.96+grain*.04),vec3(0.,1.,0.),0.);\n            gl_FragColor=vec4(col,alpha);"
  ],
  [
    "src/reference/nature.js",
    "m.frustumCulled=false;m.visible=false;root.add(m);return m;",
    "m.name='xr-snow-ground';m.frustumCulled=false;m.visible=false;root.add(m);return m;"
  ],
  [
    "src/reference/stages/cans.js",
    "color:0xeeeae3,metalness:0.12,roughness:0.48",
    "color:0xa4a9ad,metalness:0.18,roughness:0.6"
  ]
];
export function fairDisplayOverrides(file,source){
 for(const [path,before,after] of replacements){if(path!==file)continue;if(!source.includes(before))throw Error('Missing fair/display marker in '+file+': '+before.slice(0,100));source=source.replace(before,after);}
 return source;
}
