// Preserve the requested Rain, jelly score and continuous blaster changes on regeneration.
const replacements=[
  [
    "src/reference/xr-runtime.js",
    "import {GOAL_AIM_Z}",
    "import {createScorePopup} from './score-popup';\nimport {GOAL_AIM_Z}"
  ],
  [
    "src/reference/xr-runtime.js",
    "    // The score board: a fixed paper plaque high over the play area, facing you.\n    const hud=panel(1,.3,1024,300);rig.add(hud.mesh);\n    function drawHud(){\n      const t=g.texts(),name=LABEL(g.mode()),turn=t.turn==='Your turn'?tr('دورك','Your turn'):t.turn?tr('دور الخصم','Their turn'):'';\n      if(rainOn){\n        const n=intro?intro.popped:0,key='rain|'+n+'|'+lang;if(key===hud.key)return;hud.key=key;\n        const c=hud.ctx;c.clearRect(0,0,1024,300);c.textAlign='center';c.direction=tr('rtl','ltr');\n        paperCard(c,282,26,460,200,56);c.fillStyle=INK;c.font=font(800,92);c.fillText(String(n),512,128);\n        c.font=font(700,36);c.fillStyle='rgba(44,45,61,.66)';c.fillText(tr('مطر دحاريج','Dahrooj Rain'),512,186);hud.tex.needsUpdate=true;return;\n      }\n      const ch=climbOn&&climb3?climb3.hud():null;\n      const key=placing?'placing':ch?['climb',ch.hearts,ch.height,ch.checkpoint,ch.again,t.title].join('|'):[t.title,t.count,turn,name,lang].join('|');if(key===hud.key)return;hud.key=key;\n      const c=hud.ctx;c.clearRect(0,0,1024,300);c.textAlign='center';c.direction=tr('rtl','ltr');\n      if(placing){\n        c.fillStyle='rgba(255,252,246,.88)';round(c,62,30,900,230,46);c.fill();c.fillStyle=INK;\n        c.font=font(800,52);c.fillText(tr('وجّه على سطح واضغط الزناد للتثبيت','Aim at a surface and pull the trigger to pin'),512,125);\n        c.font=font(700,40);c.fillStyle='rgba(44,45,61,.7)';c.fillText(tr('العصا للأعلى والأسفل تكبّر وتصغّر قبل التثبيت','Stick up and down: bigger and smaller, until you pin'),512,200);\n      }else if(ch){\n        // Big hearts that read at a glance from the climb.\n        paperCard(c,202,14,620,236,60);\n        c.font=font(800,112);for(let i=0;i<ch.max;i++){c.fillStyle=i<ch.hearts?'#c8584b':'rgba(44,45,61,.2)';c.fillText('♥',512+(i-(ch.max-1)/2)*128,138);}\n        c.font=font(800,46);c.fillStyle='rgba(44,45,61,.8)';c.fillText(ch.again?tr('A للتسلق من جديد','A to climb again'):t.title||tr(`${ch.height} م`,`${ch.height} m`),512,214);\n      }else{\n        paperCard(c,282,26,460,200,56);\n        c.fillStyle=INK;c.font=font(800,92);c.fillText(t.title||t.count||'0',512,128);\n        c.font=font(700,36);c.fillStyle='rgba(44,45,61,.66)';c.fillText(turn||name,512,186);\n      }\n      hud.tex.needsUpdate=true;\n    }\n\n",
    "    // Transient jelly digits; placement instructions and Summit health stay available.\n    const hud=panel(1,.3,1024,300),scorePopup=createScorePopup();rig.add(hud.mesh);hud.mesh.add(scorePopup.root);\n    function drawHud(){\n      const t=g.texts(),ch=climbOn&&climb3?climb3.hud():null;\n      scorePopup.observe(placing?'placing':ch?'climb':rainOn?'rain':g.mode(),placing||ch?0:rainOn?(intro?.popped||0):Number(t.count));\n      hud.mesh.material.visible=!!(placing||ch);\n      if(!placing&&!ch){hud.key='';return;}\n      const key=placing?'placing|'+lang:['climb',ch.hearts,ch.height,ch.checkpoint,ch.again,t.title,lang].join('|');if(key===hud.key)return;hud.key=key;\n      const c=hud.ctx;c.clearRect(0,0,1024,300);c.textAlign='center';c.direction=tr('rtl','ltr');\n      if(placing){\n        c.fillStyle='rgba(255,252,246,.88)';round(c,62,30,900,230,46);c.fill();c.fillStyle=INK;\n        c.font=font(800,52);c.fillText(tr('وجّه على سطح واضغط الزناد للتثبيت','Aim at a surface and pull the trigger to pin'),512,125);\n        c.font=font(700,40);c.fillStyle='rgba(44,45,61,.7)';c.fillText(tr('العصا للأعلى والأسفل تكبّر وتصغّر قبل التثبيت','Stick up and down: bigger and smaller, until you pin'),512,200);\n      }else if(ch){\n        // Big hearts that read at a glance from the climb.\n        paperCard(c,202,14,620,236,60);\n        c.font=font(800,112);for(let i=0;i<ch.max;i++){c.fillStyle=i<ch.hearts?'#c8584b':'rgba(44,45,61,.2)';c.fillText('♥',512+(i-(ch.max-1)/2)*128,138);}\n        c.font=font(800,46);c.fillStyle='rgba(44,45,61,.8)';c.fillText(ch.again?tr('A للتسلق من جديد','A to climb again'):t.title||tr(`${ch.height} م`,`${ch.height} m`),512,214);\n      }\n      hud.tex.needsUpdate=true;\n    }\n\n"
  ],
  [
    "src/reference/xr-runtime.js",
    "drawMenu(hover);drawHud();",
    "drawMenu(hover);drawHud();scorePopup.step(dt);"
  ],
  [
    "src/reference/xr-runtime.js",
    "INTRO_STYLES=['jelly','fabric','clay','fur','bubble'],CROWD_MAX=120;",
    "INTRO_STYLES=['jelly','fabric','clay','fur','bubble'],RAIN_ACCESSORIES=['party','glasses','cap','flower','crown'],CROWD_MAX=120;"
  ],
  [
    "src/reference/xr-runtime.js",
    "models.crowd(CROWD_MAX)",
    "models.crowd(CROWD_MAX,true)"
  ],
  [
    "src/reference/xr-runtime.js",
    "const rad=INTRO_R*(.75+Math.random()*.5),sp=.2+Math.random()*.5,dirA=Math.random()*Math.PI*2;",
    "const raw=INTRO_R*(.75+Math.random()*.5),rad=I.rain&&raw>INTRO_R?INTRO_R+(raw-INTRO_R)*.5:raw,sp=.2+Math.random()*.5,dirA=Math.random()*Math.PI*2;\n      // Pick once per spawn; cosmetics never change the player's unlocks or add physics bodies.\n      const accessory=I.rain?RAIN_ACCESSORIES[Math.random()*RAIN_ACCESSORIES.length|0]:'';"
  ],
  [
    "src/reference/xr-runtime.js",
    "R:rad,p:V(c.x",
    "R:rad,accessory,p:V(c.x"
  ],
  [
    "src/reference/xr-runtime.js",
    "b.hit>0||b.blink>0?'shut':falling?'wide':'open');",
    "b.hit>0||b.blink>0?'shut':falling?'wide':'open',b.accessory);"
  ],
  [
    "src/reference/xr-runtime.js",
    "if(blast.shots.length>=16)return;const kind_=styleFor(fromIntro),P=SHOT_STYLE[kind_];\n      if(clock-(h.lastShot||0)<P.cool)return;h.lastShot=clock;blast.fired++;g.noteStyle?.();",
    "const kind_=styleFor(fromIntro),P=SHOT_STYLE[kind_];\n      if(clock-(h.lastShot||0)<P.cool)return;\n      // Reuse the bounded flight budget instead of stalling a held trigger until old shots expire.\n      if(blast.shots.length>=16){const oldest=blast.shots.shift();if(oldest.m)scene.remove(oldest.m);}\n      h.lastShot=clock;blast.fired++;g.noteStyle?.();"
  ],
  [
    "src/reference/character.js",
    "function accessory(id){\n      if(!accTemplates[id]){",
    "function accessory(id,lite=false){\n      const key=lite?'crowd/'+id:id;\n      if(!accTemplates[key]){"
  ],
  [
    "src/reference/character.js",
    "accTemplates[id]=g;",
    "accTemplates[key]=g;"
  ],
  [
    "src/reference/character.js",
    "return accTemplates[id].clone();",
    "return accTemplates[key].clone();"
  ],
  [
    "src/reference/character.js",
    "    function accessory(id,lite=false){\n      const key=lite?'crowd/'+id:id;\n      if(!accTemplates[key]){\n        const g=new T.Group(),mat=(o)=>new T.MeshStandardMaterial({roughness:.5,...o});\n        const add=(geo,m,pos,rot,scale)=>{const o=new T.Mesh(geo,m);if(pos)o.position.copy(pos);if(rot)o.rotation.set(...rot);if(scale)o.scale.set(...scale);o.castShadow=true;g.add(o);return o;};\n        if(id==='party'){\n          const stripes=canvas(64,128,(c,w,h)=>{for(let i=0;i<8;i++){c.fillStyle=i%2?'#fffaf2':'#e2603f';c.fillRect(0,i*h/8,w,h/8);}});\n          const hat=new T.Group();hat.position.set(r*.12,r*.92,r*.05);hat.rotation.set(-.15,0,-.32);g.add(hat);\n          const cone=new T.Mesh(new T.ConeGeometry(r*.3,r*.72,28,1,true),mat({map:stripes,side:T.DoubleSide}));cone.position.y=r*.36;hat.add(cone);\n          const pom=new T.Mesh(new T.SphereGeometry(r*.09,16,12),mat({color:0xf2c14e,roughness:.8}));pom.position.y=r*.74;hat.add(pom);\n        }else if(id==='glasses'){\n          // Out in front of the 3D eyes, which stand a little proud of the face.\n          const frame=mat({color:0x2c2d3d,roughness:.35}),lens=new T.MeshPhysicalMaterial({color:0x1b2233,roughness:.08,metalness:.2,clearcoat:1,envMap:env,envMapIntensity:.8,transparent:true,opacity:.86});\n          for(const sd of [-1,1]){\n            const a=sd*.32,out=V(Math.sin(a),0,Math.cos(a)),p=out.clone().multiplyScalar(r*1.17).setY(r*.1);\n            add(new T.TorusGeometry(r*.21,r*.035,10,28),frame,p,[0,a,0],[1,.8,1]);\n            add(new T.CircleGeometry(r*.2,28),lens,p.clone().addScaledVector(out,-r*.005),[0,a,0],[1,.8,1]);\n            // The arms run back from the lenses along the side of the head.\n            const arm=add(new T.BoxGeometry(r*.035,r*.035,r*1.05),frame,V(sd*r*.74,r*.13,r*.66),[0,-sd*.56,0]);arm.castShadow=false;\n          }\n          add(new T.TorusGeometry(r*.08,r*.026,8,16,Math.PI),frame,V(0,r*.15,r*1.2),[0,0,0]);\n        }else if(id==='cap'){\n          const red=mat({color:0xc8442f,roughness:.7}),white=mat({color:0xfffaf2,roughness:.7});\n          add(new T.SphereGeometry(r*1.05,36,16,0,Math.PI*2,0,Math.PI*.36),red,V(0,r*.02,0));\n          // The peak sticks out over the eyes, tipped down so it shows from the front.\n          add(new T.CylinderGeometry(r*.68,r*.68,r*.04,32,1,false,-Math.PI/2,Math.PI),red,V(0,r*.5,r*.55),[.42,0,0],[1,1,.9]);\n          add(new T.SphereGeometry(r*.07,12,10),white,V(0,r*1.06,0));\n        }else if(id==='flower'){\n          const petal=mat({color:0xff7f9a,roughness:.6}),mid=mat({color:0xf2c14e,roughness:.6});\n          const f=new T.Group();f.position.set(r*.55,r*.72,r*.42);f.lookAt(V(r*1.1,r*1.44,r*.84));g.add(f);\n          for(let i=0;i<5;i++){const a=i/5*Math.PI*2,m=new T.Mesh(new T.SphereGeometry(r*.14,14,10),petal);m.position.set(Math.cos(a)*r*.17,Math.sin(a)*r*.17,0);m.scale.set(1,1,.45);f.add(m);}\n          const c=new T.Mesh(new T.SphereGeometry(r*.08,14,10),mid);c.position.z=r*.03;f.add(c);\n        }else if(id==='crown'){\n          const gold=new T.MeshPhysicalMaterial({color:0xf2c14e,roughness:.25,metalness:.85,clearcoat:.6,envMap:env,envMapIntensity:1.2}),gem=mat({color:0xc8442f,roughness:.15});\n          const c=new T.Group();c.position.set(0,r*.86,0);c.rotation.x=-.12;g.add(c);\n          const band=new T.Mesh(new T.CylinderGeometry(r*.4,r*.44,r*.2,28,1,true),gold);band.material.side=T.DoubleSide;c.add(band);\n          for(let i=0;i<7;i++){const a=i/7*Math.PI*2,sp=new T.Mesh(new T.ConeGeometry(r*.07,r*.2,10),gold);sp.position.set(Math.sin(a)*r*.41,r*.19,Math.cos(a)*r*.41);c.add(sp);\n            const b=new T.Mesh(new T.SphereGeometry(r*.035,10,8),gold);b.position.set(Math.sin(a)*r*.41,r*.3,Math.cos(a)*r*.41);c.add(b);}\n          const jewel=new T.Mesh(new T.SphereGeometry(r*.06,14,10),gem);jewel.position.set(0,0,r*.43);jewel.scale.z=.5;c.add(jewel);\n        }\n        g.traverse(o=>{if(o.isMesh)o.geometry.isShared=true;});\n        accTemplates[key]=g;\n      }\n      return accTemplates[key].clone();\n    }\n\n",
    "    function accessory(id,lite=false){\n      const key=lite?'crowd/'+id:id;\n      if(!accTemplates[key]){\n        const g=new T.Group(),mat=(o)=>new T.MeshStandardMaterial({roughness:.5,...o});\n        const add=(geo,m,pos,rot,scale)=>{const o=new T.Mesh(geo,m);if(pos)o.position.copy(pos);if(rot)o.rotation.set(...rot);if(scale)o.scale.set(...scale);o.castShadow=true;g.add(o);return o;};\n        if(id==='party'){\n          const stripes=canvas(64,128,(c,w,h)=>{for(let i=0;i<8;i++){c.fillStyle=i%2?'#fffaf2':'#e2603f';c.fillRect(0,i*h/8,w,h/8);}});\n          const hat=new T.Group();hat.position.set(r*.12,r*.92,r*.05);hat.rotation.set(-.15,0,-.32);g.add(hat);\n          const cone=new T.Mesh(new T.ConeGeometry(r*.3,r*.72,lite?12:28,1,true),mat({map:stripes,side:T.DoubleSide}));cone.position.y=r*.36;hat.add(cone);\n          const pom=new T.Mesh(new T.SphereGeometry(r*.09,lite?8:16,lite?6:12),mat({color:0xf2c14e,roughness:.8}));pom.position.y=r*.74;hat.add(pom);\n        }else if(id==='glasses'){\n          // Out in front of the 3D eyes, which stand a little proud of the face.\n          const frame=mat({color:0x2c2d3d,roughness:.35}),lens=new T.MeshPhysicalMaterial({color:0x1b2233,roughness:.08,metalness:.2,clearcoat:1,envMap:env,envMapIntensity:.8,transparent:!lite,opacity:lite?1:.86});\n          for(const sd of [-1,1]){\n            const a=sd*.32,out=V(Math.sin(a),0,Math.cos(a)),p=out.clone().multiplyScalar(r*1.17).setY(r*.1);\n            add(new T.TorusGeometry(r*.21,r*.035,lite?6:10,lite?12:28),frame,p,[0,a,0],[1,.8,1]);\n            add(new T.CircleGeometry(r*.2,lite?12:28),lens,p.clone().addScaledVector(out,-r*.005),[0,a,0],[1,.8,1]);\n            // The arms run back from the lenses along the side of the head.\n            const arm=add(new T.BoxGeometry(r*.035,r*.035,r*1.05),frame,V(sd*r*.74,r*.13,r*.66),[0,-sd*.56,0]);arm.castShadow=false;\n          }\n          add(new T.TorusGeometry(r*.08,r*.026,lite?6:8,lite?8:16,Math.PI),frame,V(0,r*.15,r*1.2),[0,0,0]);\n        }else if(id==='cap'){\n          const red=mat({color:0xc8442f,roughness:.7}),white=mat({color:0xfffaf2,roughness:.7});\n          add(new T.SphereGeometry(r*1.05,lite?16:36,lite?8:16,0,Math.PI*2,0,Math.PI*.36),red,V(0,r*.02,0));\n          // The peak sticks out over the eyes, tipped down so it shows from the front.\n          add(new T.CylinderGeometry(r*.68,r*.68,r*.04,lite?16:32,1,false,-Math.PI/2,Math.PI),red,V(0,r*.5,r*.55),[.42,0,0],[1,1,.9]);\n          add(new T.SphereGeometry(r*.07,lite?8:12,lite?6:10),white,V(0,r*1.06,0));\n        }else if(id==='flower'){\n          const petal=mat({color:0xff7f9a,roughness:.6}),mid=mat({color:0xf2c14e,roughness:.6});\n          const f=new T.Group();f.position.set(r*.55,r*.72,r*.42);f.lookAt(V(r*1.1,r*1.44,r*.84));g.add(f);\n          for(let i=0;i<5;i++){const a=i/5*Math.PI*2,m=new T.Mesh(new T.SphereGeometry(r*.14,lite?8:14,lite?6:10),petal);m.position.set(Math.cos(a)*r*.17,Math.sin(a)*r*.17,0);m.scale.set(1,1,.45);f.add(m);}\n          const c=new T.Mesh(new T.SphereGeometry(r*.08,lite?8:14,lite?6:10),mid);c.position.z=r*.03;f.add(c);\n        }else if(id==='crown'){\n          const gold=new T.MeshPhysicalMaterial({color:0xf2c14e,roughness:.25,metalness:.85,clearcoat:.6,envMap:env,envMapIntensity:1.2}),gem=mat({color:0xc8442f,roughness:.15});\n          const c=new T.Group();c.position.set(0,r*.86,0);c.rotation.x=-.12;g.add(c);\n          const band=new T.Mesh(new T.CylinderGeometry(r*.4,r*.44,r*.2,lite?16:28,1,true),gold);band.material.side=T.DoubleSide;c.add(band);\n          for(let i=0;i<7;i++){const a=i/7*Math.PI*2,sp=new T.Mesh(new T.ConeGeometry(r*.07,r*.2,lite?6:10),gold);sp.position.set(Math.sin(a)*r*.41,r*.19,Math.cos(a)*r*.41);c.add(sp);\n            const b=new T.Mesh(new T.SphereGeometry(r*.035,lite?6:10,lite?4:8),gold);b.position.set(Math.sin(a)*r*.41,r*.3,Math.cos(a)*r*.41);c.add(b);}\n          const jewel=new T.Mesh(new T.SphereGeometry(r*.06,lite?8:14,lite?6:10),gem);jewel.position.set(0,0,r*.43);jewel.scale.z=.5;c.add(jewel);\n        }\n        g.traverse(o=>{if(o.isMesh)o.geometry.isShared=true;});\n        accTemplates[key]=g;\n      }\n      return accTemplates[key].clone();\n    }\n\n"
  ],
  [
    "src/reference/character.js",
    "function crowd(max){",
    "function crowd(max,withAccessories=false){"
  ],
  [
    "src/reference/character.js",
    "const M=new T.Matrix4(),S=new T.Matrix4(),R=new T.Matrix4(),tmp=new T.Matrix4(),q=new T.Quaternion(),up=V(0,1,0),look=new T.Matrix4();",
    "const accessories={};\n      if(withAccessories)for(const id of ['party','glasses','cap','flower','crown']){\n        const merged=batchReferenceMeshes(accessory(id,true));\n        accessories[id]=merged.children.map((part,i)=>{const m=mk(part.geometry,part.material,max);m.name='xr-rain-accessory-'+id+'-'+i;return m;});\n      }\n      const accessoryScale=new T.Matrix4().makeScale(1.08,1.08,1.08);\n      const M=new T.Matrix4(),S=new T.Matrix4(),R=new T.Matrix4(),tmp=new T.Matrix4(),q=new T.Quaternion(),up=V(0,1,0),look=new T.Matrix4();"
  ],
  [
    "src/reference/character.js",
    "add(style,pos,radius,toward,squash,eyes){",
    "add(style,pos,radius,toward,squash,eyes,accessoryId=''){"
  ],
  [
    "src/reference/character.js",
    "if(style==='fur'){for(const l of bowLocal.loops)",
    "if(accessories[accessoryId]){const matrix=style==='fur'?tmp.multiplyMatrices(M,accessoryScale):M;for(const m of accessories[accessoryId])put(m,matrix);}\n          if(style==='fur'&&!HEADWEAR.has(accessoryId)){for(const l of bowLocal.loops)"
  ]
];
export function rainScoreOverrides(file,source){for(const [path,before,after] of replacements){if(path!==file)continue;if(!source.includes(before))throw new Error("Missing Rain/score override: "+file+" "+before.slice(0,70));source=source.replaceAll(before,after);}return source;}
