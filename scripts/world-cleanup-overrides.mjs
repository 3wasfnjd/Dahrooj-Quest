// Keep the reviewed night and physical cleanup changes on reference regeneration.
const replacements=[
  [
    "src/reference/nature.js",
    "night:{lightColor:C('#c4d6ff'),lightIntensity:.9,shadowColor:C('#525f7a'),fogColorA:C('#384a69'),fogColorB:C('#172b4a')",
    "night:{lightColor:C('#b6caff'),lightIntensity:.45,shadowColor:C('#263447'),fogColorA:C('#152740'),fogColorB:C('#050e23')"
  ],
  [
    "src/reference/nature.js",
    "uStars:{value:0},",
    "uStars:{value:0},uNight:{value:0},"
  ],
  [
    "src/reference/nature.js",
    "uniform float uStars;varying vec3 vDir;",
    "uniform float uStars,uNight;varying vec3 vDir;"
  ],
  [
    "src/reference/nature.js",
    "'float s=max(dot(d,uSunDir),0.);col+=uLightColor*(pow(s,600.)*1.5+pow(s,10.)*.25);'",
    "'float s=max(dot(d,uSunDir),0.);col+=uLightColor*(pow(s,mix(600.,1800.,uNight))*mix(1.5,.65,uNight)+pow(s,10.)*mix(.25,.018,uNight));'"
  ],
  [
    "src/reference/nature.js",
    "sky.renderOrder=-10;",
    "sky.name='xr-sky';sky.renderOrder=-10;"
  ],
  [
    "src/reference/nature.js",
    "const cloud=clamp(w.rain*1.2,0,1),grey=C('#9aa0b0');",
    "const night=clamp(Math.min((dayP-.22)/.08,(.75-dayP)/.08),0,1),cloud=clamp(w.rain*1.2,0,1),grey=C('#9aa0b0').lerp(C('#142036'),night);\n        U.uNight.value=night;"
  ],
  [
    "src/reference/nature.js",
    ".lerp(C('#ffffff'),.35).lerp(grey,cloud*.5)",
    ".lerp(C('#ffffff'),.35*(1-night)+.012*night).lerp(grey,cloud*.5)"
  ],
  [
    "src/reference/nature.js",
    "const k=d.lightIntensity>2?1/3:1,night=clamp(Math.min((dayP-.22)/.08,(.75-dayP)/.08),0,1);",
    "const k=d.lightIntensity>2?1/3:1;"
  ],
  [
    "src/reference/nature.js",
    "d.lightIntensity*(1-night*.35)+night*.6",
    "d.lightIntensity*(1-night*.35)+night*.18"
  ],
  [
    "src/reference/nature.js",
    "function explode(c){\n        if(c.exploded)return;c.exploded=true;c.fuse=.4;",
    "function explode(c,byPlayer=true){\n        if(c.exploded)return;c.exploded=true;c.byPlayer=byPlayer;c.fuse=.4;"
  ],
  [
    "src/reference/nature.js",
    "out.collide=(p,v,r)=>{",
    "out.collide=(p,v,r,byPlayer=true)=>{"
  ],
  [
    "src/reference/nature.js",
    "          explode(c);",
    "          explode(c,byPlayer);"
  ],
  [
    "src/reference/nature.js",
    "out.onExplode?.(at,3.5);",
    "out.onExplode?.(at,3.5,c.byPlayer!==false);"
  ],
  [
    "src/reference/nature.js",
    "<1.8)explode(o);",
    "<1.8)explode(o,c.byPlayer!==false);"
  ],
  [
    "src/reference/xr-runtime.js",
    "import {createScorePopup}",
    "import {ballImpactSpeed} from './ball-impact';\nimport {createScorePopup}"
  ],
  [
    "src/reference/xr-runtime.js",
    "function popBall(b){\n      const I=intro;skyPop(roomPoint(b.p));I.balls.splice(I.balls.indexOf(b),1);I.popped++;",
    "function popBall(b,byPlayer=true){\n      const I=intro;if(!I||b.popped)return;const index=I.balls.indexOf(b);if(index<0)return;\n      b.popped=true;if(byPlayer){skyPop(roomPoint(b.p));I.popped++;}I.balls.splice(index,1);"
  ],
  [
    "src/reference/xr-runtime.js",
    "k<10&&I.sparks.length<80",
    "k<(byPlayer?10:4)&&I.sparks.length<80"
  ],
  [
    "src/reference/xr-runtime.js",
    "at(roomPoint(b.p),()=>g.popSound?.());buzz(hands.find(x=>x.lastShot&&clock-x.lastShot<3),.35,40);g.chAdd?.('pop20');\n      // In the rain another one is already on its way.\n      if(I.rain)dropBall(.3+Math.random()*1.5);",
    "if(byPlayer||clock>=nextAmbientPop){at(roomPoint(b.p),()=>g.popSound?.());nextAmbientPop=clock+.12;}\n      if(byPlayer){buzz(hands.find(x=>x.lastShot&&clock-x.lastShot<3),.35,40);g.chAdd?.('pop20');}\n      // Environmental impacts leave a visible gap instead of immediately filling the crowd again.\n      if(I.rain)dropBall(byPlayer?.3+Math.random()*1.5:4+Math.random()*4);"
  ],
  [
    "src/reference/xr-runtime.js",
    "const SPARK=new T.SphereGeometry(1,8,6);let ballIds=0;",
    "const SPARK=new T.SphereGeometry(1,8,6);let ballIds=0,nextAmbientPop=0;\n    const rainPropP=V(0,0,0),rainPropV=V(0,0,0),rainRotation=new T.Quaternion(),rainInverse=new T.Quaternion();"
  ],
  [
    "src/reference/xr-runtime.js",
    "b.hit=Math.max(0,b.hit-dt);b.next-=dt;if(b.next<=0){b.blink=.14;b.next=2+Math.random()*3;}b.blink=Math.max(0,b.blink-dt);\n      }",
    "b.hit=Math.max(0,b.hit-dt);b.next-=dt;if(b.next<=0){b.blink=.14;b.next=2+Math.random()*3;}b.blink=Math.max(0,b.blink-dt);\n        if(I.rain&&natureOn()&&nature.props){\n          // Rain is simulated in room metres; props use world coordinates.\n          const scale=scaleNow();rig.getWorldQuaternion(rainRotation);rainInverse.copy(rainRotation).invert();\n          rig.localToWorld(rainPropP.copy(b.p));rainPropV.copy(b.v).applyQuaternion(rainRotation).multiplyScalar(scale);\n          nature.props.collide(rainPropP,rainPropV,b.R*scale,false);\n          b.p.copy(rig.worldToLocal(rainPropP));b.v.copy(rainPropV).applyQuaternion(rainInverse).divideScalar(scale);\n        }\n      }"
  ],
  [
    "src/reference/xr-runtime.js",
    "for(const b of l){if(b===a||a.id>b.id)continue;\n            n.copy(b.p).sub(a.p);",
    "for(const b of l){if(b===a||a.id>b.id||a.popped||b.popped)continue;\n            if(I.rain&&ballImpactSpeed(a.p,a.v,b.p,b.v,a.R+b.R,dt)>=2.4){popBall(a,false);popBall(b,false);continue;}\n            n.copy(b.p).sub(a.p);"
  ],
  [
    "src/reference/xr-runtime.js",
    "function burst(p,style){\n      skyPop(p);",
    "function burst(p,style,byPlayer=true){\n      if(byPlayer)skyPop(p);"
  ],
  [
    "src/reference/xr-runtime.js",
    "i<14&&blast.sparks.length<128",
    "i<(byPlayer?6:14)&&blast.sparks.length<128"
  ],
  [
    "src/reference/xr-runtime.js",
    "blast.popped++;at(p,()=>g.popSound?.());buzz(leftHand(),.35,40);g.chAdd?.('pop20');",
    "blast.popped++;if(byPlayer||clock>=nextAmbientPop){at(p,()=>g.popSound?.());nextAmbientPop=clock+.12;}if(byPlayer){buzz(leftHand(),.35,40);g.chAdd?.('pop20');}"
  ],
  [
    "src/reference/xr-runtime.js",
    "      // A crate going up throws every Dahrooj nearby into the air.\n      if(nature?.props&&!nature.props.onExplode)nature.props.onExplode=(boomAt,R)=>{\n        at(boomAt,()=>g.boom?.());for(const h of hands)buzz(h,.9,180);g.chAdd?.('crates5');\n        const blast=(p,v)=>{const d=V(p.x-boomAt.x,0,p.z-boomAt.z),l=d.length();if(l>R)return;const k=1-l/R;\n          if(l>.01)v.addScaledVector(d.divideScalar(l),9*k);v.y+=6*k;p.y=Math.max(p.y,BR+.01);};\n        for(const r of rests)blast(r.p,r.v);\n        for(const b of g.volley())blast(b.pos,b.vel);\n        if(S.shot&&!S.held)blast(S.pos,S.vel);\n      };\n",
    "      // Crate blasts clear nearby characters in a 3D radius, never the ball held by the player.\n      if(nature?.props&&!nature.props.onExplode)nature.props.onExplode=(boomAt,R,byPlayer=true)=>{\n        at(boomAt,()=>g.boom?.());for(const h of hands)buzz(h,.9,180);if(byPlayer)g.chAdd?.('crates5');\n        const reach=(R+BR)*(R+BR);\n        for(let i=rests.length-1;i>=0;i--)if(rests[i].p.distanceToSquared(boomAt)<=reach)popRest(i);\n        const flying=g.volley();for(let i=flying.length-1;i>=0;i--)if(flying[i].pos.distanceToSquared(boomAt)<=reach){burst(flying[i].pos,g.style(),false);flying.splice(i,1);}\n        if(S.shot&&!S.held&&S.pos.distanceToSquared(boomAt)<=reach){burst(S.pos,g.style(),false);holder=null;g.recall();}\n        const scale=scaleNow();\n        if(intro?.rain)for(let i=intro.balls.length-1;i>=0;i--){const b=intro.balls[i];if(intro.t<b.born)continue;rig.localToWorld(rainPropP.copy(b.p));if(rainPropP.distanceToSquared(boomAt)<=(R+b.R*scale)**2)popBall(b,false);}\n        for(let i=blast.shots.length-1;i>=0;i--){const shot=blast.shots[i];if(shot.kind==='mini'&&shot.p.distanceToSquared(boomAt)<=(R+shot.r)**2){burst(shot.p,shot.look,false);if(shot.m)scene.remove(shot.m);blast.shots.splice(i,1);}}\n      };\n"
  ],
  [
    "src/reference/xr-runtime.js",
    "      for(let i=0;i<rests.length;i++)for(let j=i+1;j<rests.length;j++){\n        const a=rests[i],b=rests[j],n=b.p.clone().sub(a.p),l=n.length();\n        if(l>0&&l<BR*2){n.divideScalar(l);const push=(BR*2-l)/2;a.p.addScaledVector(n,-push);b.p.addScaledVector(n,push);\n          const rel=b.v.clone().sub(a.v).dot(n);if(rel<0){a.v.addScaledVector(n,rel*.9);b.v.addScaledVector(n,-rel*.9);}}\n      }\n    }\n",
    "    }\n    function popRest(index){const r=rests[index];burst(r.p,r.style,false);if(r.m){scene.remove(r.m.group);r.m.dispose();}rests.splice(index,1);}\n    const contactBodies=[],contactDead=new Uint8Array(12),contactNormal=V(0,0,0);\n    function stepWorldContacts(dt){\n      // Eight leftovers, three previous throws and the current throw: at most 66 pairs.\n      const flying=g.volley(),restCount=rests.length,flyingCount=flying.length;\n      contactBodies.length=0;contactDead.fill(0);\n      for(const r of rests)contactBodies.push(r);for(const b of flying)contactBodies.push(b);\n      if(S.shot&&!S.held)contactBodies.push(S);\n      const threshold=2.4*scaleNow()/timeK(); // metres per real second, also at AR scale\n      for(let i=0;i<contactBodies.length;i++)for(let j=i+1;j<contactBodies.length;j++){\n        if(contactDead[i]||contactDead[j])continue;\n        const a=contactBodies[i],b=contactBodies[j],ap=a.p||a.pos,av=a.v||a.vel,bp=b.p||b.pos,bv=b.v||b.vel;\n        if(ballImpactSpeed(ap,av,bp,bv,BR*2,dt)>=threshold){contactDead[i]=contactDead[j]=1;continue;}\n        contactNormal.copy(bp).sub(ap);const length=contactNormal.length();\n        if(length>0&&length<BR*2){\n          contactNormal.divideScalar(length);const push=(BR*2-length)/2;ap.addScaledVector(contactNormal,-push);bp.addScaledVector(contactNormal,push);\n          const rel=(bv.x-av.x)*contactNormal.x+(bv.y-av.y)*contactNormal.y+(bv.z-av.z)*contactNormal.z;\n          if(rel<0){av.addScaledVector(contactNormal,rel*.9);bv.addScaledVector(contactNormal,-rel*.9);}\n        }\n      }\n      // Remove after detection, in reverse order, so a character can pop only once this frame.\n      for(let i=contactBodies.length-1;i>=0;i--)if(contactDead[i]){\n        const b=contactBodies[i];\n        if(i<restCount)popRest(i);\n        else{burst(b.pos,g.style(),false);if(i<restCount+flyingCount)flying.splice(i-restCount,1);else{holder=null;g.recall();}}\n      }\n      contactBodies.length=0;\n    }\n"
  ],
  [
    "src/reference/xr-runtime.js",
    "stepRests(dt*timeK());feelHands(dt);",
    "stepRests(dt*timeK());stepWorldContacts(dt*timeK());feelHands(dt);"
  ],
  [
    "src/reference/xr-runtime.js",
    "i<(byPlayer?6:14)&&blast.sparks.length<128",
    "i<(byPlayer?14:6)&&blast.sparks.length<128"
  ],
  [
    "src/reference/xr-runtime.js",
    "const {R:ROOM}=crowdSize(),live=I.balls.filter(b=>I.t>=b.born),{pos:head}=headLocal(),c=I.centre;",
    "const {R:ROOM}=crowdSize(),live=I.balls.filter(b=>I.t>=b.born),{pos:head}=headLocal(),c=I.centre;\n      const rainProps=I.rain&&natureOn()?nature.props:null,propScale=scaleNow();\n      if(rainProps){rig.getWorldQuaternion(rainRotation);rainInverse.copy(rainRotation).invert();}"
  ],
  [
    "src/reference/xr-runtime.js",
    "if(I.rain&&natureOn()&&nature.props){\n          // Rain is simulated in room metres; props use world coordinates.\n          const scale=scaleNow();rig.getWorldQuaternion(rainRotation);rainInverse.copy(rainRotation).invert();\n          rig.localToWorld(rainPropP.copy(b.p));rainPropV.copy(b.v).applyQuaternion(rainRotation).multiplyScalar(scale);\n          nature.props.collide(rainPropP,rainPropV,b.R*scale,false);\n          b.p.copy(rig.worldToLocal(rainPropP));b.v.copy(rainPropV).applyQuaternion(rainInverse).divideScalar(scale);",
    "if(rainProps){\n          // Only six crate colliders, with broad-phase rejection; no full prop scan for the crowd.\n          rig.localToWorld(rainPropP.copy(b.p));rainPropV.copy(b.v).applyQuaternion(rainRotation).multiplyScalar(propScale);\n          rainProps.collideCrates(rainPropP,rainPropV,b.R*propScale,false);\n          b.p.copy(rig.worldToLocal(rainPropP));b.v.copy(rainPropV).applyQuaternion(rainInverse).divideScalar(propScale);"
  ],
  [
    "src/reference/nature.js",
    "        // Crates are solid boxes: Dahrooj bounces off their sides and can land on top.",
    "        return out.collideCrates(p,v,r,byPlayer)||hit;\n      };\n      out.collideCrates=(p,v,r,byPlayer=true)=>{\n        let hit=false;\n        // Crates are solid boxes: Dahrooj bounces off their sides and can land on top."
  ],
  [
    "src/reference/nature.js",
    "if(c.exploded&&!(c.fuse>0))continue;const half=.53*CRATE*(c.k??1);",
    "if(c.exploded&&!(c.fuse>0))continue;const half=.53*CRATE*(c.k??1),bound=half*Math.SQRT2+r;\n          if(Math.abs(p.x-c.x)>bound||Math.abs(p.z-c.z)>bound||p.y+r<c.y||p.y-r>c.y+half*2)continue;"
  ]
];
export function worldCleanupOverrides(file,source){for(const [path,before,after] of replacements){if(path!==file)continue;if(!source.includes(before))throw new Error("Missing world cleanup override: "+file+" "+before.slice(0,80));source=source.replaceAll(before,after);}return source;}
