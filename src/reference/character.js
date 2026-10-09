import {referenceShader} from './render-color.js';
import {DAHROOJ_COLORS} from './palette.js';
/* Aboden Games. Ported with owner authorization 2026-10-08 from quest@c7925b7cd7371b6bb87c44a0743721ad55f177dd. See docs/REFERENCE-REUSE-AR.md. */
import {batchReferenceMeshes} from './mesh-batch';
export function createReferenceCharacter(T,{radius,drawFace,renderer}){
    const r=radius,V=(x,y,z)=>new T.Vector3(x,y,z);
    const canvas=(w,h,draw)=>{const c=document.createElement('canvas');c.width=w;c.height=h;draw(c.getContext('2d'),w,h);const t=new T.CanvasTexture(c);t.anisotropy=4;t.colorSpace=T.SRGBColorSpace;return t;};
    /* ---------- a soft room to reflect: bright window, warm walls, darker floor ---------- */
    let env=null;
    if(renderer&&T.PMREMGenerator){
      const room=canvas(512,256,(c,w,h)=>{
        const gr=c.createLinearGradient(0,0,0,h);gr.addColorStop(0,'#fffaf0');gr.addColorStop(.45,'#e9dfcf');gr.addColorStop(.55,'#9d8f7c');gr.addColorStop(1,'#4c4338');
        c.fillStyle=gr;c.fillRect(0,0,w,h);
        c.fillStyle='#ffffff';c.fillRect(w*.18,h*.16,w*.14,h*.22);c.fillRect(w*.62,h*.2,w*.08,h*.12);
      });
      try{const pm=new T.PMREMGenerator(renderer);env=pm.fromEquirectangular(room).texture;pm.dispose();room.dispose();}catch(e){env=null;}
    }

    /* ---------- shared surfaces ---------- */
    const sphere=new T.SphereGeometry(r,32,20),liteSphere=new T.SphereGeometry(r,24,16);
    // The fur ball's coat: two colours, soft white with big tan patches. Seen from the front, one patch
    // wraps the right eye and that side, a smaller one sits on the left side; the top stays white for the bow.
    const furMap=canvas(512,256,(c,w,h)=>{c.fillStyle='#f1eeea';c.fillRect(0,0,w,h);
      const patch=(x,y,rx,ry,a)=>{for(const dx of [-w,0,w]){c.save();c.translate(x*w+dx,y*h);c.rotate(a);c.beginPath();
        for(let k=0;k<=32;k++){const t=k/32*Math.PI*2,q=1+.08*Math.sin(t*3+x*9)+.05*Math.sin(t*7+y*7);c.lineTo(Math.cos(t)*rx*w*q,Math.sin(t)*ry*h*q);}
        c.fill();c.restore();}};
      c.fillStyle='#9c7352';c.filter='blur(4px)';
      for(const [x,y,rx,ry,a] of [[.35,.46,.125,.28,.1],[.075,.56,.06,.2,0],[.72,.5,.09,.22,-.2],[.88,.72,.06,.12,.3]])patch(x,y,rx,ry,a);
      c.filter='none';});
    /* ---------- jelly: light refracted through the ball ---------- */
    // A soft sky (no capture of the world, which cost a render of the scene) is looked up along the path
    // light takes through a sphere of index 1.35: in through the near side, out through the far side, a
    // little apart per colour. The jelly absorbs more the longer that path (Beer-Lambert), takes a Fresnel
    // reflection of the same sky and a glossy highlight from the sun.
        const jellyU={uIor:{value:1.35},uRadius:{value:r},
      uAbsorb:{value:new T.Vector3(.08,1.15,.3)},uTint:{value:new T.Color(DAHROOJ_COLORS.jelly)},
      uLightDir:{value:V(.4,.8,.45).normalize()},uLightColor:{value:new T.Color(1,1,1)},
      uSky:{value:new T.Color(0xcfe3ff)},uGround:{value:new T.Color(0x8a7d6c)}};
    const jellyMaterial=referenceShader(T,{uniforms:jellyU,
      vertexShader:`varying vec3 vW,vN,vC;varying float vS;
        void main(){vec4 w=modelMatrix*vec4(position,1.);vW=w.xyz;vN=normalize(mat3(modelMatrix)*normal);
          vC=(modelMatrix*vec4(0.,0.,0.,1.)).xyz;vS=length(modelMatrix[0].xyz);gl_Position=projectionMatrix*viewMatrix*w;}`,
      fragmentShader:`uniform float uIor,uRadius;uniform vec3 uAbsorb,uTint,uLightDir,uLightColor,uSky,uGround;
        varying vec3 vW,vN,vC;varying float vS;
        vec3 world(vec3 d){
          return mix(uGround,uSky,smoothstep(-.25,.35,d.y));}
        // The direction light leaves the sphere after entering at p along t, for index n.
        vec3 through(vec3 p,vec3 v,vec3 nrm,float n,float R,out float len){
          vec3 t=refract(v,nrm,1./n);
          vec3 oc=p-vC;float b=dot(oc,t);len=max(0.,-2.*b);
          vec3 q=p+t*len,nx=normalize(q-vC);
          vec3 o=refract(t,-nx,n);
          if(dot(o,o)<.01)o=reflect(t,-nx); // total internal reflection
          return o;}
        void main(){
          vec3 N=normalize(vN),V=normalize(cameraPosition-vW),I=-V;float R=uRadius*vS,len;
          vec3 oR=through(vW,I,N,uIor-.012,R,len),oG=through(vW,I,N,uIor,R,len),oB=through(vW,I,N,uIor+.014,R,len);
          vec3 seen=vec3(world(oR).r,world(oG).g,world(oB).b);
          // Beer-Lambert: the thicker the path, the deeper the colour.
          vec3 trans=seen*exp(-uAbsorb*(len/(2.*R)))*mix(vec3(1.),uTint*2.4,.5)*1.05;
          float f=.022+(1.-.022)*pow(1.-max(dot(N,V),0.),5.);
          vec3 refl=world(reflect(I,N));
          vec3 H=normalize(uLightDir+V);float nh=max(dot(N,H),0.);
          vec3 spec=uLightColor*(pow(nh,260.)*2.2+pow(nh,40.)*.12);
          // A soft glow where light passes near the rim, as in a gummy sweet.
          float rim=pow(1.-max(dot(N,V),0.),2.)*max(dot(N,uLightDir)*.5+.5,0.);
          vec3 col=mix(trans,refl,f)+spec+uTint*rim*.35;
          gl_FragColor=vec4(col,1.);}`});
    // Called from the headset loop: the jelly's highlight follows the sun.
    const probeAt=V(0,0,0);
    function updateProbe(renderer,scene,pos,{sun}={}){
      if(!sun)return;
      sun.getWorldPosition(probeAt);const tgt=sun.target?sun.target.getWorldPosition(V(0,0,0)):V(0,0,0);jellyU.uLightDir.value.copy(probeAt).sub(tgt).normalize();
      jellyU.uLightColor.value.copy(sun.color).multiplyScalar(Math.min(1.4,.6+sun.intensity));
    }
    const jellyModels=new Set();
    // The bubble's film swirls; all bubbles share one clock.
    const bubbleTime={value:0};
    const MATERIALS={
      // Jelly: see jellyMaterial below. All jelly balls share it.
      jelly:()=>jellyMaterial,
      fabric:()=>new T.MeshStandardMaterial({color:DAHROOJ_COLORS.fabric,roughness:.82,envMap:env,envMapIntensity:.35}),
      clay:()=>new T.MeshStandardMaterial({color:DAHROOJ_COLORS.clay,roughness:.72,envMap:env,envMapIntensity:.5}),
      // The skin is the colour of the hair roots and lit like them, so gaps between hairs read as deeper fur.
      fur:()=>new T.MeshStandardMaterial({map:furMap,roughness:.95,envMap:env,envMapIntensity:.35}),
      bubble:()=>referenceShader(T,{transparent:true,depthWrite:false,uniforms:{uTime:bubbleTime},
        vertexShader:'varying vec3 vN;varying vec3 vV;varying vec3 vP;void main(){vec4 mv=modelViewMatrix*vec4(position,1.);vN=normalize(normalMatrix*normal);vV=normalize(-mv.xyz);vP=position;gl_Position=projectionMatrix*mv;}',
        fragmentShader:[
          'uniform float uTime;varying vec3 vN;varying vec3 vV;varying vec3 vP;',
          'void main(){vec3 n=normalize(vN),v=normalize(vV);float c=abs(dot(n,v)),f=1.-c;',
          // Film thickness drifts and swirls, thinner at the top like a real bubble.
          'vec3 p=normalize(vP);float th=.55+.25*sin(p.x*5.+uTime*.7+sin(p.y*4.-uTime*.5)*1.6)+.2*sin(p.z*7.-uTime*.4)-.25*p.y;',
          'vec3 film=.5+.5*cos(6.2831*(th*2.2/(.4+c)+vec3(0.,.33,.67)));',
          'vec3 r=reflect(-v,n);float win=smoothstep(.93,.97,dot(r,normalize(vec3(-.45,.6,.65))))+.6*smoothstep(.96,.985,dot(r,normalize(vec3(.6,.3,.75))));',
          'float rim=pow(f,1.8);vec3 col=mix(vec3(.96,.98,1.),film,.75);',
          'gl_FragColor=vec4(col*(.35+rim)+win,.05+rim*.7+win*.8);}'].join('\n')})
    };

    const sharedMaterials=Object.fromEntries(Object.entries(MATERIALS).map(([id,make])=>[id,make()]));
    const decorations={};
    function decoration(id){ if(!decorations[id])decorations[id]=batchReferenceMeshes(({bandaid,bow})[id]()); return decorations[id].clone(true); }
    // Place a part on the surface at a direction, facing outward.
    function onSurface(obj,dir,lift=0){const n=dir.clone().normalize();obj.position.copy(n).multiplyScalar(r+lift);obj.lookAt(n.multiplyScalar(r*3));return obj;}
    function bandaid(){
      const g=new T.Group(),skin=new T.MeshStandardMaterial({color:0xe8c29d,roughness:.6,envMap:env,envMapIntensity:.4});
      const pad=new T.Mesh(new T.BoxGeometry(r*.66,r*.24,r*.03),skin);
      const gauze=new T.Mesh(new T.BoxGeometry(r*.22,r*.17,r*.04),new T.MeshStandardMaterial({color:0xf4ddc3,roughness:.95}));
      for(let i=0;i<6;i++){const hole=new T.Mesh(new T.CircleGeometry(r*.012,8),new T.MeshBasicMaterial({color:0xc9a07c}));hole.position.set((i%3-1)*r*.07+(i<3?-r*.23:r*.23),(i<3?1:-1)*r*.03,r*.016);g.add(hole);}
      g.add(pad,gauze);onSurface(g,V(.4,.62,.6),r*.005);g.rotateZ(-.55);return g;
    }
    // The ribbon sits on top, a little to the left and forward, as in Aboden Games' drawing.
    // It stands up facing forward (tipped back a little and leaning), not flat on the curve.
    const BOW_AT=V(-.1,.86,.5).normalize();
    const placeBow=o=>{o.position.copy(BOW_AT).multiplyScalar(r*1.06);o.rotation.set(-.15,-.1,.15);return o;};
    function bow(){
      const g=new T.Group(),red=new T.MeshPhysicalMaterial({color:0xd8452f,roughness:.45,sheen:.5,sheenColor:new T.Color(0xff9a80),envMap:env,envMapIntensity:.5}),dark=new T.MeshStandardMaterial({color:0xb8432a,roughness:.6});
      for(const s of [-1,1]){
        const loop=new T.Mesh(new T.SphereGeometry(r*.17,20,14),red);loop.scale.set(1.2,.9,.6);loop.position.set(s*r*.2,0,0);loop.rotation.z=s*.35;g.add(loop);
        const tail=new T.Mesh(new T.ConeGeometry(r*.06,r*.3,10),dark);tail.position.set(s*r*.09,-r*.19,r*.12);tail.rotation.x=.35;tail.rotation.z=s*.35;g.add(tail);
      }
      g.add(new T.Mesh(new T.SphereGeometry(r*.07,12,10),dark));
      return placeBow(g);
    }
    /* ---------- accessories: rewards for challenges (party hat, sunglasses, cap, flower, crown) ---------- */
    // Built from simple shapes in Dahrooj's colours, around a ball of radius r with the face toward +z.
    // One template per accessory; each ball wears a clone that shares its geometry and materials.
    const accTemplates={};
    const HEADWEAR=new Set(['party','cap','crown']);
    function accessory(id,lite=false){
      const key=lite?'crowd/'+id:id;
      if(!accTemplates[key]){
        const g=new T.Group(),mat=(o)=>new T.MeshStandardMaterial({roughness:.5,...o});
        const add=(geo,m,pos,rot,scale)=>{const o=new T.Mesh(geo,m);if(pos)o.position.copy(pos);if(rot)o.rotation.set(...rot);if(scale)o.scale.set(...scale);o.castShadow=true;g.add(o);return o;};
        if(id==='party'){
          const stripes=canvas(64,128,(c,w,h)=>{for(let i=0;i<8;i++){c.fillStyle=i%2?'#fffaf2':'#e2603f';c.fillRect(0,i*h/8,w,h/8);}});
          const hat=new T.Group();hat.position.set(r*.12,r*.92,r*.05);hat.rotation.set(-.15,0,-.32);g.add(hat);
          const cone=new T.Mesh(new T.ConeGeometry(r*.3,r*.72,lite?12:28,1,true),mat({map:stripes,side:T.DoubleSide}));cone.position.y=r*.36;hat.add(cone);
          const pom=new T.Mesh(new T.SphereGeometry(r*.09,lite?8:16,lite?6:12),mat({color:0xf2c14e,roughness:.8}));pom.position.y=r*.74;hat.add(pom);
        }else if(id==='glasses'){
          // Out in front of the 3D eyes, which stand a little proud of the face.
          const frame=mat({color:0x2c2d3d,roughness:.35}),lens=new T.MeshPhysicalMaterial({color:0x1b2233,roughness:.08,metalness:.2,clearcoat:1,envMap:env,envMapIntensity:.8,transparent:!lite,opacity:lite?1:.86});
          for(const sd of [-1,1]){
            const a=sd*.32,out=V(Math.sin(a),0,Math.cos(a)),p=out.clone().multiplyScalar(r*1.17).setY(r*.1);
            add(new T.TorusGeometry(r*.21,r*.035,lite?6:10,lite?12:28),frame,p,[0,a,0],[1,.8,1]);
            add(new T.CircleGeometry(r*.2,lite?12:28),lens,p.clone().addScaledVector(out,-r*.005),[0,a,0],[1,.8,1]);
            // The arms run back from the lenses along the side of the head.
            const arm=add(new T.BoxGeometry(r*.035,r*.035,r*1.05),frame,V(sd*r*.74,r*.13,r*.66),[0,-sd*.56,0]);arm.castShadow=false;
          }
          add(new T.TorusGeometry(r*.08,r*.026,lite?6:8,lite?8:16,Math.PI),frame,V(0,r*.15,r*1.2),[0,0,0]);
        }else if(id==='cap'){
          const red=mat({color:0xc8442f,roughness:.7}),white=mat({color:0xfffaf2,roughness:.7});
          add(new T.SphereGeometry(r*1.05,lite?16:36,lite?8:16,0,Math.PI*2,0,Math.PI*.36),red,V(0,r*.02,0));
          // The peak sticks out over the eyes, tipped down so it shows from the front.
          add(new T.CylinderGeometry(r*.68,r*.68,r*.04,lite?16:32,1,false,-Math.PI/2,Math.PI),red,V(0,r*.5,r*.55),[.42,0,0],[1,1,.9]);
          add(new T.SphereGeometry(r*.07,lite?8:12,lite?6:10),white,V(0,r*1.06,0));
        }else if(id==='flower'){
          const petal=mat({color:0xff7f9a,roughness:.6}),mid=mat({color:0xf2c14e,roughness:.6});
          const f=new T.Group();f.position.set(r*.55,r*.72,r*.42);f.lookAt(V(r*1.1,r*1.44,r*.84));g.add(f);
          for(let i=0;i<5;i++){const a=i/5*Math.PI*2,m=new T.Mesh(new T.SphereGeometry(r*.14,lite?8:14,lite?6:10),petal);m.position.set(Math.cos(a)*r*.17,Math.sin(a)*r*.17,0);m.scale.set(1,1,.45);f.add(m);}
          const c=new T.Mesh(new T.SphereGeometry(r*.08,lite?8:14,lite?6:10),mid);c.position.z=r*.03;f.add(c);
        }else if(id==='crown'){
          const gold=new T.MeshPhysicalMaterial({color:0xf2c14e,roughness:.25,metalness:.85,clearcoat:.6,envMap:env,envMapIntensity:1.2}),gem=mat({color:0xc8442f,roughness:.15});
          const c=new T.Group();c.position.set(0,r*.86,0);c.rotation.x=-.12;g.add(c);
          const band=new T.Mesh(new T.CylinderGeometry(r*.4,r*.44,r*.2,lite?16:28,1,true),gold);band.material.side=T.DoubleSide;c.add(band);
          for(let i=0;i<7;i++){const a=i/7*Math.PI*2,sp=new T.Mesh(new T.ConeGeometry(r*.07,r*.2,lite?6:10),gold);sp.position.set(Math.sin(a)*r*.41,r*.19,Math.cos(a)*r*.41);c.add(sp);
            const b=new T.Mesh(new T.SphereGeometry(r*.035,lite?6:10,lite?4:8),gold);b.position.set(Math.sin(a)*r*.41,r*.3,Math.cos(a)*r*.41);c.add(b);}
          const jewel=new T.Mesh(new T.SphereGeometry(r*.06,lite?8:14,lite?6:10),gem);jewel.position.set(0,0,r*.43);jewel.scale.z=.5;c.add(jewel);
        }
        g.traverse(o=>{if(o.isMesh)o.geometry.isShared=true;});
        accTemplates[key]=g;
      }
      return accTemplates[key].clone();
    }

    /* ---------- the face: the game's own drawing, cached per expression ---------- */
    const faces=new Map(),FACE_SPAN=Math.PI*.62;
    // A cap on the front of the sphere: angle maps linearly to the face canvas.
    const capGeo=k=>new T.SphereGeometry(r*k,32,24,Math.PI/2-FACE_SPAN/2,FACE_SPAN,Math.PI/2-FACE_SPAN/2,FACE_SPAN);
    const faceGeo=capGeo(1.006);
    function faceTexture(style,face,lx,ly,blink,noEyes){
      const qx=0,qy=0,key=[style,face,noEyes?1:0].join('/');
      if(!faces.has(key)){
        const size=256,R=size/2/(FACE_SPAN/2)*.97;
        faces.set(key,canvas(size,size,(c)=>{c.translate(size/2,size/2);drawFace(c,R,face,qx,qy,.25,false,style,noEyes);}));
        
      }
      return faces.get(key);
    }

    /* ---------- 3D eyes: glossy eyeballs with a pupil and a glint, where the drawing put them ---------- */
    // Open, focused, wide and happy eyes are real; the closed, squinting, laughing and dizzy ones stay drawn.
    const EYE_FACES=new Set(['open','focus','wide','joy']),ER=r*.19;
    const eyeGeo=new T.SphereGeometry(1,24,16),eyeGeoLite=new T.SphereGeometry(1,12,8);
    const sclera=new T.MeshPhysicalMaterial({color:0xfffaf2,roughness:.2,clearcoat:1,clearcoatRoughness:.04,envMap:env,envMapIntensity:.7});
    const scleraFelt=new T.MeshPhysicalMaterial({color:0xf2ebdd,roughness:.85,envMap:env,envMapIntensity:.3});
    if(scleraFelt.sheen!==undefined){scleraFelt.sheen=.35;scleraFelt.sheenColor=new T.Color(0x8a8070);};
    const pupilMat=new T.MeshPhysicalMaterial({color:0x2c2d3d,roughness:.06,clearcoat:1,clearcoatRoughness:.02,envMap:env,envMapIntensity:1.1});
    const glintMat=new T.MeshBasicMaterial({color:0xffffff});
    function eyes(style,lite){
      const g=new T.Group(),geo=lite?eyeGeoLite:eyeGeo,parts=[];
      for(const s of [-1,1]){
        const pivot=new T.Group();pivot.rotation.order='YXZ';g.add(pivot);
        const ball=new T.Group();ball.position.z=r-ER*.22;pivot.add(ball);
        const white=new T.Mesh(geo,style==='fabric'?scleraFelt:sclera);white.scale.set(ER,ER*1.12,ER*.55);ball.add(white);
        const pupil=new T.Group();pupil.position.z=ER*.42;ball.add(pupil);
        const dot=new T.Mesh(geo,pupilMat);dot.scale.set(ER*.55,ER*.55,ER*.22);pupil.add(dot);
        const glint=new T.Mesh(geo,glintMat);glint.scale.setScalar(ER*.15);glint.position.set(-ER*.2,ER*.22,ER*.2);pupil.add(glint);
        parts.push({s,pivot,ball,pupil});
      }
      return {g,set(face,lx,ly,blink){
        const on=EYE_FACES.has(face);g.visible=on;if(!on)return;
        const open=blink?.12:face==='focus'?.6:1,pr=(face==='wide'?.42:face==='joy'?.66:.55)/.55;
        for(const e of parts){
          // Same places as the drawing: a little above the middle, apart, and shifting with the look.
          e.pivot.rotation.set(-(.08-ly*.06),e.s*.31+lx*.08,0);
          e.ball.scale.set(1,open,1);
          e.pupil.position.x=lx*ER*.42;e.pupil.position.y=-ly*ER*.48;e.pupil.scale.set(pr,pr,1);
        }
      }};
    }


    // lite: for crowds (the opening balls and shots), fewer triangles and fur layers.
    function make(style,{face=true,lite=false}={}){
      const outer=new T.Group(),inner=new T.Group();outer.add(inner);outer.userData.referenceCharacter=true;
      const body=new T.Mesh(lite?liteSphere:sphere,sharedMaterials[style]||sharedMaterials.jelly);
      body.castShadow=style!=='bubble';inner.add(body);
      if(style==='jelly'){inner.add(decoration('bandaid'));jellyModels.add(outer);}

      let bowMesh=null,acc=null,accId='';
      if(style==='fur'){body.name='dahrooj-fur';bowMesh=decoration('bow');inner.add(bowMesh);}
      let cap=null,eye=null;
      if(face){
        eye=eyes(style,lite);inner.add(eye.g);
        cap=new T.Mesh(faceGeo,new T.MeshBasicMaterial({transparent:true,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-2}));
        cap.renderOrder=1;inner.add(cap);
      }
      return {
        group:outer,style,
        // A reward to wear ('' for none). A hat takes the place of the fur ball's ribbon.
        setAccessory(id){
          id=id||'';if(id===accId)return;accId=id;
          if(acc){inner.remove(acc);acc=null;}
          if(id){acc=accessory(id);acc.name='dahrooj-accessory-'+id;if(style==='fur')acc.scale.setScalar(1.08);inner.add(acc);}
        },
        get accessory(){return accId;},
        // pos: centre; look: where the eyes point (-1..1); squash: [sx, sy]; toward: who it faces.
        update({pos,toward,faceName='open',look=[0,0],blink=false,squash=[1,1]}){
          bubbleTime.value=performance.now()/1000;
          {const hat=HEADWEAR.has(accId);if(bowMesh)bowMesh.visible=!hat;}
          outer.position.copy(pos);outer.scale.set(squash[0],squash[1],squash[0]);
          if(toward)inner.lookAt(toward);
          eye?.set(faceName,look[0],look[1],blink);
          if(cap){
            if(faceName==='none')cap.visible=false;
            else{const map=faceTexture(style,faceName,look[0],look[1],blink,!!eye&&EYE_FACES.has(faceName));if(cap.material.map!==map){cap.material.map=map;cap.material.needsUpdate=true;}cap.visible=true;}
          }
        },
        dispose(){if(cap)cap.material.dispose();jellyModels.delete(outer);outer.removeFromParent();}
      };
    }
    /* ---------- crowds: hundreds of little Dahroojs in a handful of draws ---------- */
    // The opening rain and its shots. Each style's bodies are one instanced mesh, every eye part another, and
    // the fur balls get their ribbon; the jelly and the bubble shaders
    // learn the instance matrix. Positions and sizes are in the crowd group's units (metres in the rig).
    const instanced=(src,from,to)=>{const m=src.clone();m.uniforms=src.uniforms;m.vertexShader=src.vertexShader.split(from).join(to);return m;};
    const crowdMats={
      jelly:instanced(jellyMaterial,'modelMatrix','(modelMatrix*instanceMatrix)'),
      fabric:MATERIALS.fabric(),clay:MATERIALS.clay(),
      fur:MATERIALS.fur(),
      bubble:(()=>{const b=MATERIALS.bubble();return instanced(instanced(b,'modelViewMatrix*vec4(position,1.)','modelViewMatrix*instanceMatrix*vec4(position,1.)'),'normalMatrix*normal','normalMatrix*mat3(instanceMatrix)*normal');})()
    };
    crowdMats.bubble.transparent=true;crowdMats.bubble.depthWrite=false;
    // The eye parts in a ball's own frame for each look: open, wide and shut. [white, pupil, glint] per side.
    const EYE_LOOKS={open:[1,1],wide:[1,.42/.55],shut:[.12,1]};
    const eyeLocal={};
    for(const [name,[open,pr]] of Object.entries(EYE_LOOKS)){
      eyeLocal[name]=[];
      for(const s of [-1,1]){
        const pivot=new T.Object3D();pivot.rotation.order='YXZ';pivot.rotation.set(-.08,s*.31,0);
        const ball=new T.Object3D();ball.position.z=r-ER*.22;ball.scale.set(1,open,1);pivot.add(ball);
        const white=new T.Object3D();white.scale.set(ER,ER*1.12,ER*.55);ball.add(white);
        const pupil=new T.Object3D();pupil.position.z=ER*.42;pupil.scale.set(pr,pr,1);ball.add(pupil);
        const dot=new T.Object3D();dot.scale.set(ER*.55,ER*.55,ER*.22);pupil.add(dot);
        const glint=new T.Object3D();glint.scale.setScalar(ER*.15);glint.position.set(-ER*.2,ER*.22,ER*.2);pupil.add(glint);
        pivot.updateMatrixWorld(true);
        eyeLocal[name].push([white.matrixWorld.clone(),dot.matrixWorld.clone(),glint.matrixWorld.clone()]);
      }
    }
    // The fur ball's ribbon: two loops and a knot where bow() puts them.
    const bowLocal=(()=>{const g=new T.Object3D();placeBow(g);g.updateMatrix();const out={loops:[],knot:g.matrix.clone()};
      for(const s of [-1,1]){const o=new T.Object3D();o.scale.set(1.2,.9,.6);o.position.set(s*r*.2,0,0);o.rotation.z=s*.35;o.updateMatrix();out.loops.push(g.matrix.clone().multiply(o.matrix));}
      return out;})();
    const bowRed=new T.MeshStandardMaterial({color:0xd8452f,roughness:.5}),bowDark=new T.MeshStandardMaterial({color:0xb8432a,roughness:.6});
    const loopGeo=new T.SphereGeometry(r*.17,10,8),knotGeo=new T.SphereGeometry(r*.07,8,6);
    // Small balls need fewer facets: about 600 triangles a ball with its eyes.
    const crowdBody=new T.SphereGeometry(r,16,12),crowdEye=new T.SphereGeometry(1,10,6),crowdGlint=new T.SphereGeometry(1,6,4);
    function crowd(max,withAccessories=false){
      const group=new T.Group(),mk=(geo,mat,n,order=0)=>{const m=new T.InstancedMesh(geo,mat,n);m.count=0;m.frustumCulled=true;m.renderOrder=order;group.add(m);return m;};
      const bodies={};for(const s of Object.keys(crowdMats))bodies[s]=mk(crowdBody,crowdMats[s],max,s==='bubble'?3:0);
      const whites=mk(crowdEye,sclera,max*2),pupils=mk(crowdEye,pupilMat,max*2),glints=mk(crowdGlint,glintMat,max*2);
      const loops=mk(loopGeo,bowRed,max*2),knots=mk(knotGeo,bowDark,max);
      const accessories={};
      if(withAccessories)for(const id of ['party','glasses','cap','flower','crown']){
        const merged=batchReferenceMeshes(accessory(id,true));
        accessories[id]=merged.children.map((part,i)=>{const m=mk(part.geometry,part.material,max);m.name='xr-rain-accessory-'+id+'-'+i;return m;});
      }
      const accessoryScale=new T.Matrix4().makeScale(1.08,1.08,1.08);
      const M=new T.Matrix4(),S=new T.Matrix4(),R=new T.Matrix4(),tmp=new T.Matrix4(),q=new T.Quaternion(),up=V(0,1,0),look=new T.Matrix4();
      const put=(mesh,m)=>{mesh.setMatrixAt(mesh.count++,m);};
      return {
        group,
        begin(){for(const m of group.children)m.count=0;},
        // One ball: style, centre, radius, the point it faces (or null), squash [sx, sy], eyes 'open' | 'wide' | 'shut' | null.
        add(style,pos,radius,toward,squash,eyes,accessoryId=''){
          const body=bodies[style]||bodies.jelly;if(body.count>=max)return;
          const k=radius/r;
          if(toward){look.lookAt(toward,pos,up);q.setFromRotationMatrix(look);}else q.identity();
          R.makeRotationFromQuaternion(q);S.makeScale(k*squash[0],k*squash[1],k*squash[0]);
          M.makeTranslation(pos.x,pos.y,pos.z).multiply(S).multiply(R);
          put(body,M);
          if(accessories[accessoryId]){const matrix=style==='fur'?tmp.multiplyMatrices(M,accessoryScale):M;for(const m of accessories[accessoryId])put(m,matrix);}
          if(style==='fur'&&!HEADWEAR.has(accessoryId)){for(const l of bowLocal.loops)put(loops,tmp.multiplyMatrices(M,l));put(knots,tmp.multiplyMatrices(M,bowLocal.knot));}
          if(eyes){const base=M;
            for(const [w,p,gl] of eyeLocal[eyes]||eyeLocal.open){put(whites,tmp.multiplyMatrices(base,w));put(pupils,tmp.multiplyMatrices(base,p));put(glints,tmp.multiplyMatrices(base,gl));}}
        },
        end(){for(const m of group.children){m.instanceMatrix.needsUpdate=true;m.computeBoundingSphere();}bubbleTime.value=performance.now()/1000;},
        get count(){return Object.values(bodies).reduce((n,m)=>n+m.count,0);}
      };
    }
    for(const style of Object.keys(MATERIALS))for(const name of ['open','focus','wide','joy','closed','squint','laugh','dizzy','hurt'])faceTexture(style,name,0,0,false,EYE_FACES.has(name));
    return {make,crowd,updateProbe,mats:sharedMaterials,time:bubbleTime,forget(group){jellyModels.delete(group);}};
}
