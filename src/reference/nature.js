import {referenceShader} from './render-color.js';
/* Aboden Games reference implementation, owner-authorized complete port 2026-10-08. See COMPLETE-REFERENCE-PORT-AR.md. */
import * as Core from '@iwsdk/core';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
const THREE={...Core,GLTFLoader};
/* Motri's world around Dahrooj in the headset (VR). Aboden Games.
   A port of Motri / Folio 2025 by Bruno Simon (MIT) from Three.js r183 TSL to r128 GLSL, with Motri's
   own models and values: grass (Grass.js), oak, birch and cherry trees with their foliage (Trees.js,
   Foliage.js, foliageSDF.png and the tree models, Draco removed), bushes (Bushes.js), wind (Wind.js),
   rain lines and falling snow (RainLines.js), snow on the ground (Snow.js), day cycles and their
   presets (DayCycles.js), seasons (YearCycles.js), weather (Weather.js), lighting
   (Ligthing.js, MeshDefaultMaterial.js), the fog and background gradient (Fog.js), the stone floor
   (Floor.js), pole lights with fireflies, lanterns, benches, explosive crates and fireballs (PoleLights.js,
   Lanterns.js, Benches.js, ExplosiveCrates.js, Fireballs.js), flowers (Flowers.js), fallen leaves (Leaves.js),
   a pond in Motri's water colours (Terrain.js, WaterSurface.js) and drop shadows drawn once into a texture.
   Distances are in game metres (the headset shows them at a half). */
export const createReferenceNature=(() => {
  'use strict';
  const T=THREE,C=h=>new T.Color(h),V=(x,y,z)=>new T.Vector3(x,y,z);
  const clamp=(v,a,b)=>Math.max(a,Math.min(b,v)),lerp=(a,b,t)=>a+(b-a)*t;
  const remapClamp=(v,a,b,c,d)=>{const t=clamp((v-a)/(b-a),0,1);return c+(d-c)*t;};
  const BASE='/assets/';

  /* ---------- DayCycles.js presets and keyframes (4 minutes per day, on the real clock) ---------- */
  const DAY={
    day:{lightColor:C('#fff1dd'),lightIntensity:1.35,shadowColor:C('#8b9cae'),fogColorA:C('#dcebf4'),fogColorB:C('#83b7e0'),fogNearRatio:.5,fogFarRatio:2,temperature:5},
    dusk:{lightColor:C('#ffd5b2'),lightIntensity:1.05,shadowColor:C('#7c7694'),fogColorA:C('#e1b8ad'),fogColorB:C('#7a8dab'),fogNearRatio:.5,fogFarRatio:2,temperature:0},
    night:{lightColor:C('#c4d6ff'),lightIntensity:.9,shadowColor:C('#525f7a'),fogColorA:C('#384a69'),fogColorB:C('#172b4a'),fogNearRatio:.65,fogFarRatio:2.4,temperature:-7.5},
    dawn:{lightColor:C('#ffe0c2'),lightIntensity:1.15,shadowColor:C('#8891a8'),fogColorA:C('#f2d4bd'),fogColorB:C('#9dbbda'),fogNearRatio:.5,fogFarRatio:2,temperature:0}
  };
  const DAY_KEYS=[[DAY.day,0],[DAY.day,.15],[DAY.dusk,.25],[DAY.night,.35],[DAY.night,.6],[DAY.dawn,.8],[DAY.day,.9]];
  const DAY_SECONDS=4*60;
  // Auto weather takes its turn like the day does: clear, rain, clear, snow, every six minutes.
  const WEATHER_SECONDS=6*60;
  // YearCycles.js: seasons on the real date.
  const YEAR={winter:{temperature:5,humidity:.8,clouds:.65,wind:.3},spring:{temperature:15,humidity:.65,clouds:.45,wind:.2},
    summer:{temperature:25,humidity:.5,clouds:.3,wind:.1},fall:{temperature:15,humidity:.65,clouds:.65,wind:.25}};
  const YEAR_KEYS=[[YEAR.winter,.125],[YEAR.spring,.375],[YEAR.summer,.625],[YEAR.fall,.875]];
  // Cycles.js blends neighbouring keyframes, wrapping around the end of the cycle.
  function blend(keys,p,out){
    const n=keys.length;let ia=n-1;
    for(let i=0;i<n;i++)if(keys[i][1]<=p)ia=i;
    const a=keys[ia],b=keys[(ia+1)%n],pa=a[1],pb=b[1]<=pa?b[1]+1:b[1],pp=p<pa?p+1:p,t=pb>pa?(pp-pa)/(pb-pa):0;
    for(const k in a[0]){const va=a[0][k],vb=b[0][k];if(va&&va.isColor)(out[k]||(out[k]=C(0))).copy(va).lerp(vb,t);else out[k]=lerp(va,vb,t);}
    return out;
  }

  /* ---------- Noises.js perlin (6 cells, period 6, remapped 0.1–0.9 to 0–1) ---------- */
  function perlinTexture(size=128){
    const rand=(x,y)=>{const a=Math.sin(x*127.1+y*311.7)*43758.5453123,b=Math.sin(x*269.5+y*183.3)*43758.5453123;return [-1+2*(a-Math.floor(a)),-1+2*(b-Math.floor(b))];};
    const mod=(a,b)=>((a%b)+b)%b,sm=t=>t*t*(3-2*t),data=new Uint8Array(size*size*4);
    for(let j=0;j<size;j++)for(let i=0;i<size;i++){
      const u=i/size*6,v=j/size*6,x0=Math.floor(u),y0=Math.floor(v),fx=u-x0,fy=v-y0;
      const lx=mod(x0,6),ly=mod(y0,6),hx=mod(x0+1,6),hy=mod(y0+1,6);
      const d=(c,ox,oy)=>c[0]*(fx-ox)+c[1]*(fy-oy);
      const n=lerp(lerp(d(rand(lx,ly),0,0),d(rand(hx,ly),1,0),sm(fx)),lerp(d(rand(lx,hy),0,1),d(rand(hx,hy),1,1),sm(fx)),sm(fy))*.8+.5;
      const k=(j*size+i)*4,val=clamp((n-.1)/.8,0,1)*255;data[k]=data[k+1]=data[k+2]=val;data[k+3]=255;
    }
    const t=new T.DataTexture(data,size,size,T.RGBAFormat);t.wrapS=t.wrapT=T.RepeatWrapping;t.magFilter=t.minFilter=T.LinearFilter;t.needsUpdate=true;return t;
  }

  return (_T,{scene,hemi,sun,lineMat,court={x:0,z:-10}})=>{
    const root=new T.Group();root.name='xr-nature';root.visible=false;scene.add(root);
    let seed=7;const rng=()=>(seed=(seed*16807)%2147483647)/2147483647;
    const perlin=perlinTexture();
    // The same noise on the CPU (bilinear, wrapping), so the game's physics sees the pond's real shore.
    const perlinAt=(u,v)=>{const N=128,d=perlin.image.data,x=((u%1+1)%1)*N-.5,y=((v%1+1)%1)*N-.5,x0=Math.floor(x),y0=Math.floor(y),fx=x-x0,fy=y-y0;
      const at=(i,j)=>d[((((j%N)+N)%N)*N+(((i%N)+N)%N))*4]/255;
      return lerp(lerp(at(x0,y0),at(x0+1,y0),fx),lerp(at(x0,y0+1),at(x0+1,y0+1),fx),fy);};

    /* ---------- Ligthing.js + MeshDefaultMaterial.js + Fog.js, shared by every Motri piece ---------- */
    const phi=.63,theta=.72;
    const U={
      uLightColor:{value:C('#ffffff')},uLightIntensity:{value:1},uShadowColor:{value:C('#6d3fff')},
      uLightDir:{value:V(Math.sin(phi)*Math.sin(theta),Math.cos(phi),Math.sin(phi)*Math.cos(theta)).normalize()},
      uFogA:{value:C('#00ffff')},uFogB:{value:C('#9b89ff')},uFogNear:{value:20},uFogFar:{value:50},
      uHorizon:{value:C('#9ff')},uZenith:{value:C('#9b89ff')},uSunDir:{value:V(.3,.5,-.8).normalize()},uStars:{value:0},
      uPerlin:{value:perlin},uTime:{value:0},
      uWindDir:{value:new T.Vector2(Math.sin(Math.PI*.6),Math.cos(Math.PI*.6))},uWindStrength:{value:.5},uWindTime:{value:0},uCam:{value:V(0,0,0)}
    };
    const SHADE=`
      uniform vec3 uLightColor,uShadowColor,uLightDir,uFogA,uFogB,uHorizon;uniform float uLightIntensity,uFogNear,uFogFar;
      varying vec4 vClip;varying float vDist;
      vec3 motriShade(vec3 base,vec3 n,float extraShadow){
        vec3 col=base*uLightColor*uLightIntensity;
        float core=smoothstep(1.,-.25,dot(n,uLightDir));
        col=mix(col,base*uShadowColor,clamp(max(core,extraShadow),0.,1.));
        // Range fog into the horizon colour of the sky (Motri's fog colours), so the land melts into it.
        return mix(col,uHorizon,smoothstep(uFogNear,uFogFar,vDist));
      }`;
    const WIND=`
      uniform sampler2D uPerlin;uniform vec2 uWindDir;uniform float uWindStrength,uWindTime;
      vec2 windOffset(vec2 p){p*=.5;
        float n1=texture2D(uPerlin,p*.2+uWindDir*uWindTime).r-.5;float n2=texture2D(uPerlin,p*.1+uWindDir*uWindTime*.2).r-.5;
        return uWindDir*(n1+n2)*uWindStrength;}`;
    const OUT='vec4 mv=modelViewMatrix*vec4(p,1.);vDist=-mv.z;gl_Position=projectionMatrix*mv;vClip=gl_Position;';

    /* ---------- sky: Motri's day colours as a dome, light at the horizon and rich overhead ---------- */
    // It follows the eyes and stays inside the camera's far plane (the game camera sees 120 m).
    const sky=new T.Mesh(new T.SphereGeometry(100,32,16),referenceShader(T,{uniforms:U,side:T.BackSide,depthWrite:false,fog:false,
      vertexShader:'varying vec3 vDir;void main(){vDir=normalize(position);gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}',
      fragmentShader:[
        'uniform vec3 uHorizon,uZenith,uFogA,uSunDir,uLightColor;uniform float uStars;varying vec3 vDir;',
        'float hash(vec3 p){p=fract(p*.3183099+.1);p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}',
        'void main(){vec3 d=normalize(vDir);float h=clamp(d.y,0.,1.);',
        'vec3 col=mix(uHorizon,uZenith,pow(h,.6));',
        'col=mix(col,uFogA,.18*(1.-h)*(.5+.5*d.x));',
        'float s=max(dot(d,uSunDir),0.);col+=uLightColor*(pow(s,600.)*1.5+pow(s,10.)*.25);',
        // Stars at night (DayCycles.js night interval).
        'col+=step(.9965,hash(floor(d*220.)))*smoothstep(.05,.3,d.y)*uStars;',
        'col=mix(col,uHorizon,step(d.y,.0));gl_FragColor=vec4(col,1.);}'].join('\n')}));
    sky.renderOrder=-10;sky.frustumCulled=false;root.add(sky);

    /* ---------- tracks: where Dahrooj rolls and lands, as Motri's Tracks.js does for the wheels ---------- */
    // A black canvas over the field; white where a ball pressed the grass, dug the snow or marked the ground.
    // It fades back slowly, so old tracks heal.
    const TRACK_PX=512,TRACK_SIZE=64,trackCanvas=document.createElement('canvas');trackCanvas.width=trackCanvas.height=TRACK_PX;
    const tctx=trackCanvas.getContext('2d');tctx.fillStyle='#000';tctx.fillRect(0,0,TRACK_PX,TRACK_PX);
    const trackTex=new T.CanvasTexture(trackCanvas);trackTex.minFilter=trackTex.magFilter=T.LinearFilter;trackTex.generateMipmaps=false;
    U.uTracks={value:trackTex};U.uTrackArea={value:V(court.x,court.z,TRACK_SIZE)};
    /* Floor.js: Motri's stone slabs under the play area, fading into grass at a noisy edge.
       uSlab: centre x, centre z, half width, half length (set per mode so the target stands on it). */
    const slabsTexture=new T.TextureLoader().load(BASE+'textures/slabs.png');slabsTexture.wrapS=slabsTexture.wrapT=T.RepeatWrapping;
    U.uSlabs={value:slabsTexture};U.uSlab={value:new T.Vector4(court.x,-2.5,9,9)};
    U.uSlabHigh={value:C('#ffcf8b')};U.uSlabLow={value:C('#a87762')};
    const SLAB=`
      uniform sampler2D uSlabs;uniform vec4 uSlab;uniform vec3 uSlabHigh,uSlabLow;
      float slabAt(vec2 p){vec2 q=abs(p-uSlab.xy)-uSlab.zw;float edge=max(q.x,q.y);
        float n=texture2D(uPerlin,p*.03).r;return 1.-smoothstep(-1.2,.8,edge+(n-.5)*2.2);}
      vec3 slabColor(vec2 p){return mix(uSlabLow,uSlabHigh,texture2D(uSlabs,p*.175).r);}`;
    let tracksDirty=false,tracksFade=0,tracksUpload=0;
    const TRACK=`
      uniform sampler2D uTracks;uniform vec3 uTrackArea;
      float trackAt(vec2 p){vec2 uv=(p-uTrackArea.xy)/uTrackArea.z+.5;
        if(uv.x<0.||uv.y<0.||uv.x>1.||uv.y>1.)return 0.;return texture2D(uTracks,vec2(uv.x,1.-uv.y)).r;}`;
    const dirtColor=C('#7a4a22');

    /* ---------- a pond to the left of the stone: Motri's water colours (Terrain.js gradient, WaterSurface.js
       ripples and shore line) painted on the ground by depth. uPond: centre x, centre z, radius x, radius z. ---------- */
    const POND={x:court.x-22,z:court.z+5,rx:7,rz:10};
    U.uPond={value:new T.Vector4(POND.x,POND.z,POND.rx,POND.rz)};
    U.uSand={value:C('#ffa94e')};U.uShallow={value:C('#5bc2b9')};U.uDeep={value:C('#13375f')};
    const POND_GLSL=`
      uniform vec4 uPond;
      // Above 0 inside the water (about 1 at the middle), below 0 on the land, with a noisy shore.
      float pondAt(vec2 p){vec2 d=(p-uPond.xy)/uPond.zw;return 1.-length(d)+(texture2D(uPerlin,p*.045).r-.5)*.35;}`;
    // The same shape on the CPU, for keeping trees, flowers and pebbles out of the water (without the noisy shore),
    // and with it (waterAt) for what floats and sinks.
    const pondAt=(x,z)=>1-Math.hypot((x-POND.x)/POND.rx,(z-POND.z)/POND.rz);
    const waterAt=(x,z)=>{const pd=pondAt(x,z)+(perlinAt(x*.045,z*.045)-.5)*.35;return pd>.005?pd:0;};

    /* ---------- drop shadows: the trees, poles, benches, lanterns and crates cast Motri's purple shadow on
       the ground and the grass. Nothing here moves on its own, so the shadows are drawn once into a
       texture (redrawn only when Dahrooj shoves a prop), which costs the headset almost nothing. ---------- */
    const SH_PX=1024,SH_SIZE=112;
    const shadowCanvas=document.createElement('canvas');shadowCanvas.width=shadowCanvas.height=SH_PX;
    const sctx=shadowCanvas.getContext('2d');
    const staticCanvas=document.createElement('canvas');staticCanvas.width=staticCanvas.height=SH_PX;
    const stctx=staticCanvas.getContext('2d');
    const shadowTex=new T.CanvasTexture(shadowCanvas);shadowTex.minFilter=shadowTex.magFilter=T.LinearFilter;shadowTex.generateMipmaps=false;
    U.uShadow={value:shadowTex};U.uShadowArea={value:V(court.x,court.z,SH_SIZE)};
    const SHADOW=`
      uniform sampler2D uShadow;uniform vec3 uShadowArea;
      float shadowAt(vec2 p){vec2 uv=(p-uShadowArea.xy)/uShadowArea.z+.5;
        if(uv.x<0.||uv.y<0.||uv.x>1.||uv.y>1.)return 0.;return texture2D(uShadow,vec2(uv.x,1.-uv.y)).r;}`;
    // Where the shadow of a point h metres up lands, along Motri's light.
    const L=U.uLightDir.value,KX=-L.x/L.y,KZ=-L.z/L.y;
    const SX=x=>(x-court.x)/SH_SIZE*SH_PX+SH_PX/2,SZ=z=>(z-court.z)/SH_SIZE*SH_PX+SH_PX/2,SM=m=>m/SH_SIZE*SH_PX;
    const blob=(c,x,z,h,r,a)=>{c.globalAlpha=a;c.beginPath();c.arc(SX(x+KX*h),SZ(z+KZ*h),Math.max(.6,SM(r)),0,7);c.fill();};
    const stick=(c,x,z,h0,h1,w,a)=>{c.globalAlpha=a;c.lineWidth=Math.max(.8,SM(w));c.lineCap='round';c.beginPath();c.moveTo(SX(x+KX*h0),SZ(z+KZ*h0));c.lineTo(SX(x+KX*h1),SZ(z+KZ*h1));c.stroke();};
    const box=(c,x,z,h,rot,hx,hz,a)=>{c.globalAlpha=a;c.save();c.translate(SX(x+KX*h),SZ(z+KZ*h));c.rotate(-rot);c.fillRect(-SM(hx),-SM(hz),SM(hx*2),SM(hz*2));c.restore();};
    const shadowCasters=[];let staticDirty=true,shadowDirty=true,shadowWait=0;
    function bakeShadows(dynamic){
      if(staticDirty){staticDirty=false;stctx.clearRect(0,0,SH_PX,SH_PX);stctx.fillStyle=stctx.strokeStyle='#fff';for(const f of shadowCasters)f(stctx);}
      sctx.globalAlpha=1;sctx.fillStyle='#000';sctx.fillRect(0,0,SH_PX,SH_PX);
      // Soft edges like Motri's filtered shadow map.
      sctx.filter='blur(2px)';sctx.drawImage(staticCanvas,0,0);sctx.filter='none';
      sctx.fillStyle=sctx.strokeStyle='#fff';dynamic(sctx);sctx.globalAlpha=1;
      shadowTex.needsUpdate=true;
    }

    /* ---------- ground: Terrain.js grass colour, lit like everything else ---------- */
    const grassColor=C('#b8b62e');
    const groundMat=referenceShader(T,{uniforms:{...U,uColor:{value:grassColor},uDirt:{value:dirtColor}},
      vertexShader:'varying vec4 vClip;varying float vDist;varying vec2 vWorld;void main(){vec3 p=position;vWorld=(modelMatrix*vec4(p,1.)).xz;'+OUT+'}',
      // Marks: the ground shows dirt where balls rolled. Then the pond, then the drop shadows.
      fragmentShader:SHADE+TRACK+'uniform sampler2D uPerlin;'+SLAB+POND_GLSL+SHADOW+`
        uniform vec3 uColor,uDirt,uSand,uShallow,uDeep;uniform float uTime;varying vec2 vWorld;
        void main(){
          float slab=slabAt(vWorld);
          vec3 c=mix(uColor*(.93+.14*texture2D(uPerlin,vWorld*.012).r),slabColor(vWorld),slab);
          c=mix(c,uDirt,clamp(trackAt(vWorld)*1.4,0.,.9)*(1.-slab*.6));
          float pd=pondAt(vWorld),wet=0.;
          if(pd>-.14){
            // A sandy shore, then water from light to deep.
            c=mix(c,uSand,smoothstep(-.14,-.05,pd));
            wet=smoothstep(-.005,.025,pd);
            c=mix(c,mix(uShallow,uDeep,smoothstep(0.,.6,pd)),wet);
            // Ripple lines that run in to the shore, broken up by noise, and a white line at the water's edge.
            float n=texture2D(uPerlin,vWorld*.1+floor(pd*9.+uTime*.22)*.345).r;
            float ripple=step(.93-n*.22,fract(pd*9.+uTime*.22))*(1.-smoothstep(.12,.5,pd))*wet;
            float shore=smoothstep(-.02,0.,pd)*(1.-smoothstep(.012,.03,pd));
            c=mix(c,vec3(1.),clamp(ripple*.85+shore,0.,1.));
          }
          gl_FragColor=vec4(motriShade(c,vec3(0.,1.,0.),shadowAt(vWorld)*.85*(1.-wet*.4)),1.);}`});
    const ground=new T.Mesh(new T.CircleGeometry(300,64).rotateX(-Math.PI/2),groundMat);ground.position.y=-.02;root.add(ground);

    /* ---------- Grass.js: three vertices per blade, turned to the camera, bent by the wind ---------- */
    {
      // 250 x 250 blades (62,500 triangles) keeps the headset's frame budget; the blades are a little wider to match.
      const subdivisions=250,size=60,count=subdivisions*subdivisions,fragment=size/subdivisions;
      const position=new Float32Array(count*9),heightRandomness=new Float32Array(count*3),corner=new Float32Array(count*3);
      for(let iX=0;iX<subdivisions;iX++)for(let iZ=0;iZ<subdivisions;iZ++){
        const i=iX*subdivisions+iZ,fx=(iX/subdivisions-.5)*size+fragment*.5+court.x,fz=(iZ/subdivisions-.5)*size+fragment*.5+court.z;
        const x=fx+(rng()-.5)*fragment,z=fz+(rng()-.5)*fragment,r=rng();
        for(let v=0;v<3;v++){position.set([x,0,z],i*9+v*3);heightRandomness[i*3+v]=r;corner[i*3+v]=v;}
      }
      const geo=new T.BufferGeometry();
      geo.setAttribute('position',new T.BufferAttribute(position,3));geo.setAttribute('heightRandomness',new T.BufferAttribute(heightRandomness,1));geo.setAttribute('corner',new T.BufferAttribute(corner,1));
      const mat=referenceShader(T,{uniforms:{...U,uColor:{value:grassColor},uDirt:{value:dirtColor},uPitch:{value:new T.Vector4(court.x,court.z+1,11,17)},bladeWidth:{value:.13},bladeHeight:{value:.6},bladeHeightRandomness:{value:.6}},side:T.DoubleSide,
        vertexShader:WIND+`
          attribute float heightRandomness,corner;uniform float bladeWidth,bladeHeight,bladeHeightRandomness;uniform vec3 uCam;uniform vec4 uPitch;
          varying vec4 vClip;varying float vDist;varying float vTip;varying float vTrack;varying float vShadow;varying float vVar;`+TRACK+SLAB+POND_GLSL+SHADOW+`
          void main(){
            vec3 p=position;float tip=corner<.5?1.:0.;vTip=tip;
            float heightVariation=texture2D(uPerlin,p.xz*.0321).r+.5;
            float h=bladeHeight*(bladeHeightRandomness*heightRandomness+(1.-bladeHeightRandomness))*heightVariation;
            // On the pitch the grass is mown short so Dahrooj and the lines stay visible; Motri's height around it.
            vec2 q=abs(p.xz-uPitch.xy)-uPitch.zw;h*=mix(.28,1.,smoothstep(0.,3.,max(q.x,q.y)));
            // Pressed flat where a ball rolled.
            vTrack=trackAt(p.xz);h*=1.-vTrack*.85;
            // No grass on the stone (Grass.js hides blades where the terrain has none).
            float slab=slabAt(p.xz);h*=1.-smoothstep(.35,.7,slab);if(slab>.7)p.y-=100.;
            // None in the pond or on its sand.
            float pd=pondAt(p.xz);h*=1.-smoothstep(-.16,-.08,pd);if(pd>-.08)p.y-=100.;
            // The drop shadow at the root, and a gentle patchiness in the colour.
            vShadow=shadowAt(p.xz);vVar=texture2D(uPerlin,p.xz*.012).r;
            vec2 shape=corner<.5?vec2(0.,1.):corner<1.5?vec2(1.,0.):vec2(-1.,0.);
            vec3 offset=vec3(shape.x*bladeWidth,shape.y*h,0.);
            float a=atan(p.z-uCam.z,p.x-uCam.x)-1.5707963;
            offset.xz=vec2(offset.x*cos(a)-offset.z*sin(a),offset.x*sin(a)+offset.z*cos(a));
            vec2 w=windOffset(p.xz)*tip*h*2.;p+=offset;p.xz+=w;
            ${OUT}
          }`,
        fragmentShader:SHADE+'uniform vec3 uColor,uDirt;varying float vTip;varying float vTrack;varying float vShadow;varying float vVar;void main(){vec3 c=mix(uColor*(.93+.14*vVar),uDirt,clamp(vTrack*1.2,0.,.8));gl_FragColor=vec4(motriShade(c,vec3(0.,1.,0.),max(1.-vTip,vShadow*.85)),1.);}'});
      const grass=new T.Mesh(geo,mat);grass.frustumCulled=false;grass.name='xr-grass';root.add(grass);
    }

    /* ---------- Foliage.js: 80 leaf planes per clump, cut out by the foliage SDF that the wind turns ---------- */
    const foliageTexture=new T.TextureLoader().load(BASE+'textures/foliageSDF.png');
    const foliageGeometry=(()=>{
      const planes=[];let s=11;const r=()=>(s=(s*16807)%2147483647)/2147483647;
      for(let i=0;i<80;i++){
        const plane=new T.PlaneGeometry(.8,.8);
        const position=V(0,0,0).setFromSpherical(new T.Spherical(1-Math.pow(r(),3),Math.PI*2*r(),Math.PI*r()));
        plane.rotateZ(r()*9999);plane.translate(position.x,position.y,position.z);
        const normal=position.clone().normalize(),n=plane.attributes.normal,pa=plane.attributes.position;
        for(let k=0;k<4;k++){const m=V(pa.getX(k),pa.getY(k),pa.getZ(k)).lerp(normal,.85);n.setXYZ(k,m.x,m.y,m.z);}
        planes.push(plane);
      }
      // Merge (BufferGeometryUtils is not part of the r128 core build).
      let vc=0,ic=0;for(const p of planes){vc+=p.attributes.position.count;ic+=p.index.count;}
      const pos=new Float32Array(vc*3),nor=new Float32Array(vc*3),uv=new Float32Array(vc*2),idx=new Uint16Array(ic);let vo=0,io=0;
      for(const p of planes){pos.set(p.attributes.position.array,vo*3);nor.set(p.attributes.normal.array,vo*3);uv.set(p.attributes.uv.array,vo*2);
        for(let k=0;k<p.index.count;k++)idx[io+k]=p.index.array[k]+vo;vo+=p.attributes.position.count;io+=p.index.count;}
      const g=new T.BufferGeometry();g.setAttribute('position',new T.BufferAttribute(pos,3));g.setAttribute('normal',new T.BufferAttribute(nor,3));g.setAttribute('uv',new T.BufferAttribute(uv,2));g.setIndex(new T.BufferAttribute(idx,1));
      return g;
    })();
    function foliage(matrices,colorA,colorB){
      const mat=referenceShader(T,{uniforms:{...U,uFoliage:{value:foliageTexture},uColorA:{value:C(colorA)},uColorB:{value:C(colorB)},threshold:{value:.3}},side:T.DoubleSide,
        vertexShader:WIND+`
          varying vec4 vClip;varying float vDist;varying vec2 vUv;varying vec3 vNormal;varying float vTurn;
          void main(){vUv=uv;
            vNormal=normalize(mat3(modelMatrix*instanceMatrix)*normal);
            vTurn=length(windOffset(position.xz))*2.2;
            vec4 mv=viewMatrix*modelMatrix*instanceMatrix*vec4(position,1.);vDist=-mv.z;gl_Position=projectionMatrix*mv;vClip=gl_Position;}`,
        fragmentShader:SHADE+`
          uniform sampler2D uFoliage;uniform vec3 uColorA,uColorB;uniform float threshold;varying vec2 vUv;varying vec3 vNormal;varying float vTurn;
          void main(){
            vec2 c=vUv-.5;float s=sin(vTurn),k=cos(vTurn);vec2 ruv=vec2(c.x*k-c.y*s,c.x*s+c.y*k)+.5;
            float alpha=texture2D(uFoliage,ruv).r-threshold;if(alpha<.1)discard;
            vec3 n=normalize(vNormal);if(!gl_FrontFacing)n=-n;
            vec3 base=mix(uColorA,uColorB,smoothstep(0.,1.,dot(n,uLightDir)));
            gl_FragColor=vec4(motriShade(base,n,0.),1.);}`});
      const mesh=new T.InstancedMesh(foliageGeometry,mat,matrices.length);
      matrices.forEach((m,i)=>mesh.setMatrixAt(i,m));mesh.frustumCulled=false;root.add(mesh);return mesh;
    }
    // Clumps face the player's usual view at a random roll, as Foliage.js faces the default camera.
    const toward=V(0,6,8);
    function clump(pos,size){
      const o=new T.Object3D(),angle=Math.PI*2*rng();o.up.set(Math.sin(angle),Math.cos(angle),0);
      o.position.copy(pos);o.lookAt(toward);o.scale.setScalar(size);o.updateMatrix();return o.matrix.clone();
    }

    /* ---------- Trees.js with Motri's oak, birch and cherry models ---------- */
    // Spots around the court, clear of the pitch, which in the headset reaches back past the player (z up to ~20).
    const spots=[];
    for(let i=0;i<90&&spots.length<42;i++){
      const a=rng()*Math.PI*2,r=20+rng()*30,x=court.x+Math.cos(a)*r,z=court.z+Math.sin(a)*r;
      if(Math.abs(x-court.x)<14&&z>-30&&z<26)continue;
      if(pondAt(x,z)>-.45)continue;
      spots.push({x,z,rot:rng()*Math.PI*2,scale:.85+rng()*.4});
    }
    // A wood behind the target, beyond the stone.
    for(let i=0;i<24;i++)spots.push({x:court.x+(rng()-.5)*40,z:-28-rng()*18,rot:rng()*Math.PI*2,scale:.8+rng()*.5});
    const bodyMat=map=>referenceShader(T,{uniforms:{...U,uMap:{value:map}},
      vertexShader:'varying vec4 vClip;varying float vDist;varying vec2 vUv;varying vec3 vNormal;void main(){vUv=uv;vNormal=normalize(mat3(modelMatrix*instanceMatrix)*normal);vec4 mv=viewMatrix*modelMatrix*instanceMatrix*vec4(position,1.);vDist=-mv.z;gl_Position=projectionMatrix*mv;vClip=gl_Position;}',
      fragmentShader:SHADE+'uniform sampler2D uMap;varying vec2 vUv;varying vec3 vNormal;void main(){vec3 base=texture2D(uMap,vUv).rgb;gl_FragColor=vec4(motriShade(base,normalize(vNormal),0.),1.);}'});
    const TREES=[['oakTreesVisual.glb','#b4b536','#d8cf3b'],['birchTreesVisual.glb','#ff4f2b','#ff903f'],['cherryTreesVisual.glb','#ff6d6d','#ff9990']];
    let treesLoaded=0;
    if(T.GLTFLoader){
      const loader=new T.GLTFLoader();
      TREES.forEach(([file,colorA,colorB],kind)=>loader.load(BASE+'models/'+file,gltf=>{
        const mine=spots.filter((_,i)=>i%3===kind);let body=null;const leaves=[];
        gltf.scene.updateMatrixWorld(true);
        gltf.scene.traverse(o=>{if(!o.isMesh)return;const name=o.name+' '+(o.parent?o.parent.name:'');
          if(name.includes('treeBody'))body=o;else if(name.includes('treeLeaves'))leaves.push(o);});
        if(!body)return;
        const bodies=new T.InstancedMesh(body.geometry,bodyMat(body.material.map),mine.length);
        const refs=mine.map(s=>new T.Matrix4().compose(V(s.x,0,s.z),new T.Quaternion().setFromAxisAngle(V(0,1,0),s.rot),V(s.scale,s.scale,s.scale)));
        refs.forEach((m,i)=>bodies.setMatrixAt(i,m.clone().multiply(body.matrixWorld)));bodies.frustumCulled=false;bodies.name='xr-trees';root.add(bodies);
        const mats=[];
        refs.forEach((ref,i)=>{
          const s=mine[i],crown=[];
          for(const leaf of leaves){
            const pos=V(0,0,0),q=new T.Quaternion(),sc=V(1,1,1);ref.clone().multiply(leaf.matrixWorld).decompose(pos,q,sc);mats.push(clump(pos,sc.x));crown.push([pos.x,pos.y,pos.z,sc.x]);
          }
          // Its shadow: the trunk up to the lowest leaves, then a soft blob for each clump of leaves.
          const low=crown.reduce((m,c)=>Math.min(m,c[1]),9);
          shadowCasters.push(c=>{stick(c,s.x,s.z,0,low,.32*s.scale,.8);for(const [x,y,z,r] of crown)blob(c,x,z,y,r*1.2,.85);});
        });
        foliage(mats,colorA,colorB);treesLoaded++;staticDirty=shadowDirty=true;
      }));
    }
    /* ---------- Bushes.js: foliage clumps on their own, in the oak colours ---------- */
    {
      const mats=[];
      for(let i=0;i<60&&mats.length<46;i++){
        const a=rng()*Math.PI*2,r=15+rng()*24,x=court.x+Math.cos(a)*r,z=court.z+Math.sin(a)*r;
        if(Math.abs(x-court.x)<12&&z>-29&&z<25)continue;
        if(pondAt(x,z)>-.3)continue;
        const y=.6+rng()*.7,size=.9+rng()*.3;mats.push(clump(V(x,y,z),size));
        shadowCasters.push(c=>blob(c,x,z,y*.6,size,.8));
      }
      foliage(mats,'#b4b536','#d8cf3b');
    }

    /* ---------- Flowers.js: little white flowers in the grass, eight to a patch, swaying with the blades ---------- */
    // Planes a little larger than Motri's (the headset sees the world at half size). They hide on the stone,
    // on the mown pitch and by the pond, as the grass does.
    {
      const planes=[];let s=5;const r=()=>(s=(s*16807)%2147483647)/2147483647;
      for(let i=0;i<8;i++){
        const dir=V(0,0,0).setFromSpherical(new T.Spherical(1,Math.PI*.2*r(),Math.PI*2*r()));
        const pos=dir.clone().setLength(1+(r()-.5)*.5);pos.y-=.75;
        const plane=new T.PlaneGeometry(.12,.12),m=new T.Matrix4().lookAt(dir,V(0,0,0),V(0,1,0));m.setPosition(pos);
        m.scale(V(1,1,1).setScalar(1+(r()-.5)));plane.applyMatrix4(m);planes.push(plane);
      }
      const geo=new T.BufferGeometry(),n=planes.length,pos=new Float32Array(n*12),nor=new Float32Array(n*12),idx=[];
      planes.forEach((p,i)=>{pos.set(p.attributes.position.array,i*12);nor.set(p.attributes.normal.array,i*12);for(const k of p.index.array)idx.push(k+i*4);});
      geo.setAttribute('position',new T.BufferAttribute(pos,3));geo.setAttribute('normal',new T.BufferAttribute(nor,3));geo.setIndex(idx);
      const mats=[],tints=[];
      for(let c=0;c<200&&mats.length<420;c++){
        const cx=court.x+(rng()-.5)*56,cz=court.z+(rng()-.5)*56;
        if(Math.abs(cx-court.x)<9.5||pondAt(cx,cz)>-.3)continue;
        const k=3+Math.floor(rng()*8),tint=rng()<.8?C('#ffffff'):rng()<.5?C('#c9d4ff'):C('#ffd6e8');
        for(let j=0;j<k;j++){
          const o=new T.Object3D();o.rotation.y=Math.PI*2*rng();o.position.set(cx+(rng()-.5)*3,0,cz+(rng()-.5)*3);
          o.scale.setScalar(.6+rng()*.4);o.updateMatrix();mats.push(o.matrix.clone());tints.push(tint.r,tint.g,tint.b);
        }
      }
      geo.setAttribute('tint',new T.InstancedBufferAttribute(new Float32Array(tints),3));
      const mat=referenceShader(T,{uniforms:{...U,uPitch:{value:new T.Vector4(court.x,court.z+1,11,17)}},side:T.DoubleSide,
        vertexShader:WIND+SLAB+POND_GLSL+SHADOW+`
          attribute vec3 tint;uniform vec4 uPitch;varying vec4 vClip;varying float vDist;varying vec3 vNormal;varying vec3 vTint;varying float vShadow;
          void main(){vTint=tint;
            vec2 root=(modelMatrix*instanceMatrix*vec4(0.,0.,0.,1.)).xz;
            vec3 p=(modelMatrix*instanceMatrix*vec4(position,1.)).xyz;
            p.xz+=windOffset(root)*clamp(position.y+.3,0.,1.);
            vec2 q=abs(root-uPitch.xy)-uPitch.zw;
            if(slabAt(root)>.3||pondAt(root)>-.14||max(q.x,q.y)<1.5)p.y-=100.;
            vNormal=normalize(mat3(modelMatrix*instanceMatrix)*normal);vShadow=shadowAt(root);
            vec4 mv=viewMatrix*vec4(p,1.);vDist=-mv.z;gl_Position=projectionMatrix*mv;vClip=gl_Position;}`,
        fragmentShader:SHADE+`varying vec3 vNormal;varying vec3 vTint;varying float vShadow;
          void main(){vec3 n=normalize(vNormal);if(!gl_FrontFacing)n=-n;gl_FragColor=vec4(motriShade(vTint,n,vShadow*.8),1.);}`});
      const mesh=new T.InstancedMesh(geo,mat,mats.length);mats.forEach((m,i)=>mesh.setMatrixAt(i,m));mesh.frustumCulled=false;mesh.name='xr-flowers';root.add(mesh);
    }

    /* ---------- Leaves.js: fallen leaves in Motri's two reds, most of them under the trees ---------- */
    {
      const geo=new T.PlaneGeometry(1,1),pa=geo.attributes.position.array;pa[0]+=.15;pa[3]+=.15;pa[6]-=.15;pa[9]-=.15;geo.rotateX(-Math.PI/2);
      const mats=[],cols=[],nors=[],a=C('#95513a'),b=C('#f56a3a');
      for(let i=0;i<700&&mats.length<520;i++){
        let x,z;
        if(i%5<3&&spots.length){const t=spots[Math.floor(rng()*spots.length)],ang=rng()*Math.PI*2,d=Math.sqrt(rng())*3.5;x=t.x+Math.cos(ang)*d+KX*2;z=t.z+Math.sin(ang)*d+KZ*2;}
        else{x=court.x+(rng()-.5)*60;z=court.z+(rng()-.5)*60;}
        if(pondAt(x,z)>-.12)continue;
        const o=new T.Object3D();o.position.set(x,.025+rng()*.01,z);o.rotation.y=rng()*Math.PI*2;o.scale.setScalar(.25*(.5+rng()*.5));o.updateMatrix();mats.push(o.matrix.clone());
        const c=a.clone().lerp(b,rng());cols.push(c.r,c.g,c.b);
        const nn=V(0,1,0).applyAxisAngle(V(1,0,0),(rng()-.5)*1.2).applyAxisAngle(V(0,0,1),(rng()-.5)*1.2);nors.push(nn.x,nn.y,nn.z);
      }
      geo.setAttribute('tint',new T.InstancedBufferAttribute(new Float32Array(cols),3));geo.setAttribute('tilt',new T.InstancedBufferAttribute(new Float32Array(nors),3));
      const mat=referenceShader(T,{uniforms:U,side:T.DoubleSide,
        vertexShader:SHADOW+`attribute vec3 tint,tilt;varying vec4 vClip;varying float vDist;varying vec3 vTint,vNormal;varying float vShadow;
          void main(){vTint=tint;vNormal=tilt;vec4 w=modelMatrix*instanceMatrix*vec4(position,1.);vShadow=shadowAt(w.xz);
            vec4 mv=viewMatrix*w;vDist=-mv.z;gl_Position=projectionMatrix*mv;vClip=gl_Position;}`,
        fragmentShader:SHADE+'varying vec3 vTint,vNormal;varying float vShadow;void main(){gl_FragColor=vec4(motriShade(vTint,normalize(vNormal),vShadow*.85),1.);}'});
      const mesh=new T.InstancedMesh(geo,mat,mats.length);mats.forEach((m,i)=>mesh.setMatrixAt(i,m));mesh.frustumCulled=false;mesh.name='xr-leaves';root.add(mesh);
    }

    /* ---------- pebbles: pale faceted stones in the grass beside the stone and around the pond ---------- */
    {
      const geo=new T.IcosahedronGeometry(1,0),mats=[];
      const put=(x,z,s)=>{const o=new T.Object3D();o.position.set(x,s*.25,z);o.rotation.set(rng()*.6,rng()*Math.PI*2,rng()*.6);
        o.scale.set(s*(.8+rng()*.5),s*(.45+rng()*.3),s*(.8+rng()*.5));o.updateMatrix();mats.push(o.matrix.clone());};
      // Around the pond's sand.
      for(let i=0;i<18;i++){const a=rng()*Math.PI*2,k=1.06+rng()*.12;put(POND.x+Math.cos(a)*POND.rx*k,POND.z+Math.sin(a)*POND.rz*k,.12+rng()*.22);}
      // Beside the stone, in twos and threes.
      for(let i=0;i<16;i++){const sd=rng()<.5?-1:1,x=court.x+sd*(10.2+rng()*6),z=court.z+(rng()-.5)*44;
        for(let j=0,n=1+Math.floor(rng()*3);j<n;j++)put(x+(rng()-.5)*.8,z+(rng()-.5)*.8,.08+rng()*.16);}
      const mat=referenceShader(T,{uniforms:{...U,uColor:{value:C('#f3eeff')}},
        vertexShader:SHADOW+'varying vec4 vClip;varying float vDist;varying vec3 vNormal;varying float vShadow;void main(){vNormal=normalize(mat3(modelMatrix*instanceMatrix)*normal);vec4 w=modelMatrix*instanceMatrix*vec4(position,1.);vShadow=shadowAt(w.xz);vec4 mv=viewMatrix*w;vDist=-mv.z;gl_Position=projectionMatrix*mv;vClip=gl_Position;}',
        fragmentShader:SHADE+'uniform vec3 uColor;varying vec3 vNormal;varying float vShadow;void main(){gl_FragColor=vec4(motriShade(uColor,normalize(vNormal),vShadow*.7),1.);}'});
      const mesh=new T.InstancedMesh(geo,mat,mats.length);mats.forEach((m,i)=>mesh.setMatrixAt(i,m));mesh.frustumCulled=false;mesh.name='xr-pebbles';root.add(mesh);
      for(const m of mats){const p=V(0,0,0).setFromMatrixPosition(m),sc=V(0,0,0).setFromMatrixScale(m);shadowCasters.push(c=>blob(c,p.x,p.z,sc.y*.8,(sc.x+sc.z)*.45,.6));}
    }

    /* ---------- PoleLights.js, Lanterns.js, Benches.js and ExplosiveCrates.js: Motri's props around the stone ---------- */
    // Same models and materials: the palette for bodies, emissiveOrangeRadialGradient for the glass
    // (#ff8641 to #ff3e00, normalised, 1.7). Pole glass and fireflies come on at night, as in Motri.
    // Lanterns and benches are knocked about by Dahrooj; crates blow up when he touches one.
    const props=(()=>{
      const out={obstacles:[],crates:[],loaded:0,onExplode:null};
      const glowU={uColorA:{value:C('#ff8641')},uColorB:{value:C('#ff3e00')},uIntensity:{value:1.7},uOn:{value:1}};
      const glowMat=referenceShader(T,{uniforms:glowU,
        vertexShader:'varying vec2 vUv;void main(){vUv=uv;gl_Position=projectionMatrix*viewMatrix*modelMatrix*instanceMatrix*vec4(position,1.);}',
        fragmentShader:'uniform vec3 uColorA,uColorB;uniform float uIntensity,uOn;varying vec2 vUv;void main(){vec3 c=mix(uColorA,uColorB,length(vUv-.5)*2.);c/=dot(c,vec3(.2126,.7152,.0722));gl_FragColor=vec4(c*uIntensity*uOn,1.);}'});
      const poleGlowU={...glowU,uOn:{value:0}};
      const poleGlowMat=glowMat.clone();poleGlowMat.uniforms=poleGlowU;
      const cx=court.x,cz=court.z;
      // Pole lights line the stone, benches with a lantern at each end sit beyond them, crates wait at the sides.
      const poles=[],benches=[],lanterns=[];
      for(const s of[-1,1]){
        for(const z of[4,-7,-18])poles.push({x:cx+s*10.3,z,rot:0});
        for(const z of[-1.5,-12.5]){benches.push({x:cx+s*11.9,z,rot:-s*Math.PI/2});lanterns.push({x:cx+s*11.9,z:z+1.75,rot:.4*s},{x:cx+s*11.9,z:z-1.75,rot:-.3*s});}
      }
      const crateSpots=[];
      for(const [x,z] of[[-7.4,-4],[7.4,-14]]){const s=Math.sign(x);
        crateSpots.push({x:cx+x,z:cz+z+10-.45,y:0,rot:.2},{x:cx+x+s*.15,z:cz+z+10+.45,y:0,rot:-.15},{x:cx+x+s*.05,z:cz+z+10,y:1,rot:.5});}
      const CRATE=.7,LANTERN=.6,BENCH=.75;
      const m4=new T.Matrix4(),q=new T.Quaternion(),Y=V(0,1,0);
      // One instanced mesh per model part; parts keep their offset inside the model.
      function build(file,list,scale,lift,glow,done){
        new T.GLTFLoader().load(BASE+'models/'+file,gltf=>{
          gltf.scene.updateMatrixWorld(true);const parts=[];
          gltf.scene.traverse(o=>{if(!o.isMesh)return;
            const em=/emissive/i.test(o.material.name);
            const mesh=new T.InstancedMesh(o.geometry,em?glow:bodyMat(o.material.map),list.length);
            mesh.frustumCulled=false;root.add(mesh);parts.push({mesh,local:o.matrixWorld.clone()});});
          const item={parts,list,scale,lift,sync(i){const it=list[i];q.setFromAxisAngle(Y,it.rot);if(it.tilt)q.multiply(new T.Quaternion().setFromAxisAngle(V(1,0,0),it.tilt));
            m4.compose(V(it.x,(it.y||0)+lift*scale*(it.k??1),it.z),q,V(1,1,1).multiplyScalar(scale*(it.k??1)));
            for(const p of parts){p.mesh.setMatrixAt(i,m4.clone().multiply(p.local));p.mesh.instanceMatrix.needsUpdate=true;}shadowDirty=true;}};
          list.forEach((_,i)=>item.sync(i));out.loaded++;done?.(item);
        });
      }
      let poleItem=null,lanternItem=null,benchItem=null,crateItem=null;
      if(T.GLTFLoader){
        build('poleLight.glb',poles,1,1.78,poleGlowMat,it=>poleItem=it);
        build('lantern.glb',lanterns,LANTERN,.51,glowMat,it=>lanternItem=it);
        build('bench.glb',benches,BENCH,.71,null,it=>benchItem=it);
        build('explosiveCrate.glb',crateSpots,CRATE,.53,null,it=>crateItem=it);
      }
      // Colliders: boxes standing on the ground (half sizes in metres).
      for(const p of poles)out.obstacles.push({it:p,hx:.2,hz:.2,h:3.5});
      for(const b of benches)out.obstacles.push({it:b,hx:1.09*BENCH,hz:.63*BENCH,h:1.4*BENCH,mass:.25,vx:0,vz:0,spin:0});
      for(const l of lanterns)out.obstacles.push({it:l,hx:.35*LANTERN,hz:.35*LANTERN,h:1.1*LANTERN,mass:.6,vx:0,vz:0,spin:0});
      for(const c of crateSpots){c.home={...c};out.crates.push(c);}
      // Shadows: the poles never move; benches, lanterns and crates are drawn where they are now.
      for(const p of poles)shadowCasters.push(c=>{stick(c,p.x,p.z,0,3.3,.28,.85);blob(c,p.x,p.z,3.45,.34,.85);});
      out.castShadows=c=>{
        for(const b of benches)box(c,b.x,b.z,.45,b.rot,1.05*BENCH,.42*BENCH,.75);
        for(const l of lanterns){stick(c,l.x,l.z,0,1*LANTERN,.32*LANTERN,.7);blob(c,l.x,l.z,1.05*LANTERN,.2*LANTERN,.7);}
        for(const k of crateSpots){const sc=k.k??1;if(k.exploded&&!(k.fuse>0)||sc<.05)continue;const half=.53*CRATE*sc;
          box(c,k.x,k.z,k.y+half,k.rot,half,half,.8);box(c,k.x,k.z,k.y+.05,k.rot,half,half,.8);}
      };

      // Fireflies around each pole light at night (5 per light).
      const flies=(()=>{
        const n=poles.length*5,pos=new Float32Array(n*3),seed=new Float32Array(n);
        poles.forEach((p,i)=>{for(let j=0;j<5;j++){const k=i*5+j,a=Math.random()*Math.PI*2;pos.set([p.x+Math.cos(a),2.8,p.z+Math.sin(a)],k*3);seed[k]=Math.random()*999;}});
        const geo=new T.BufferGeometry();geo.setAttribute('position',new T.BufferAttribute(pos,3));geo.setAttribute('seed',new T.BufferAttribute(seed,1));
        const mat=referenceShader(T,{uniforms:{...glowU,uTime:U.uTime,uScale:{value:0}},transparent:true,depthWrite:false,blending:T.AdditiveBlending,
          vertexShader:'attribute float seed;uniform float uTime,uScale;void main(){float t=uTime+seed;vec3 p=position+vec3(sin(t*.4)*.5,sin(t)*.2,sin(t*.3)*.5);vec4 mv=modelViewMatrix*vec4(p,1.);gl_PointSize=clamp(90.*uScale/-mv.z,0.,14.);gl_Position=projectionMatrix*mv;}',
          fragmentShader:'uniform vec3 uColorA,uColorB;void main(){float d=length(gl_PointCoord-.5)*2.;if(d>1.)discard;vec3 c=mix(uColorA,uColorB,d);gl_FragColor=vec4(c*(1.-d*d),1.);}'});
        const pts=new T.Points(geo,mat);pts.frustumCulled=false;root.add(pts);return mat.uniforms.uScale;
      })();
      // A warm pool of light on the ground under each pole at night.
      const poolMat=new T.MeshBasicMaterial({color:0xff8641,transparent:true,opacity:0,depthWrite:false,blending:T.AdditiveBlending,fog:false,
        map:(()=>{const c=document.createElement('canvas');c.width=c.height=64;const x=c.getContext('2d'),gr=x.createRadialGradient(32,32,0,32,32,32);gr.addColorStop(0,'#fff');gr.addColorStop(1,'rgba(255,255,255,0)');x.fillStyle=gr;x.fillRect(0,0,64,64);return new T.CanvasTexture(c);})()});
      for(const p of poles){const pool=new T.Mesh(new T.PlaneGeometry(6,6),poolMat);pool.rotation.x=-Math.PI/2;pool.position.set(p.x,.03,p.z);root.add(pool);}

      /* Fireballs.js: a noisy ball of fire that swells and burns away into goo. */
      const fireGeo=new T.SphereGeometry(.5,12,6),fires=[];
      const fireMat=()=>referenceShader(T,{uniforms:{uPerlin:U.uPerlin,uHorizon:U.uHorizon,uFogNear:U.uFogNear,uFogFar:U.uFogFar,progress:{value:.15},colorA:{value:C('red')},colorB:{value:C('orange')},strength:{value:1.7}},
        vertexShader:'varying vec3 vPos,vNormal;varying float vY,vDist;void main(){vPos=position;vNormal=normal;vec4 w=modelMatrix*vec4(position,1.);vY=w.y;vec4 mv=viewMatrix*w;vDist=-mv.z;gl_Position=projectionMatrix*mv;}',
        fragmentShader:`uniform sampler2D uPerlin;uniform vec3 colorA,colorB,uHorizon;uniform float progress,strength,uFogNear,uFogFar;varying vec3 vPos,vNormal;varying float vY,vDist;
          void main(){
            float nx=texture2D(uPerlin,vPos.yz*.8).r,ny=texture2D(uPerlin,vPos.xz*.8+.8).r,nz=texture2D(uPerlin,vPos.xy*.8+1.6).r;
            vec3 b=abs(normalize(vNormal));b/=b.x+b.y+b.z;
            float n=(nx*b.x+ny*b.y+nz*b.z-.15)/.75;
            n*=clamp(vY*2.,0.,1.);n-=progress;
            if(n<0.)discard;
            vec3 fire=mix(colorA,colorB,n)*strength;
            vec3 goo=mix(vec3(0.),uHorizon,smoothstep(uFogNear,uFogFar,vDist));
            gl_FragColor=vec4(mix(fire,goo,step(n,.1)),1.);}`});
      // Motri's strength is 8 under tone mapping; r128 here has none, so a lower one keeps the reds.
      function fireball(p,radius){
        const mat=fireMat(),mesh=new T.Mesh(fireGeo,mat);mesh.position.copy(p);mesh.rotation.order='XYZ';
        mesh.rotation.x=Math.random()*Math.PI*2;mesh.rotation.y=Math.random()*Math.PI*2;root.add(mesh);
        fires.push({mesh,mat,t:0,radius});
      }
      function explode(c){
        if(c.exploded)return;c.exploded=true;c.fuse=.4;
      }
      // Ball against prop: push it out, bounce it, shove light props and light the fuse on crates.
      out.collide=(p,v,r)=>{
        let hit=false;
        for(const o of out.obstacles){
          const it=o.it;if(p.y-r>o.h)continue;
          const dx=p.x-it.x,dz=p.z-it.z,c=Math.cos(it.rot),s=Math.sin(it.rot);
          const lx=dx*c-dz*s,lz=dx*s+dz*c,qx=clamp(lx,-o.hx,o.hx),qz=clamp(lz,-o.hz,o.hz);
          let ex=lx-qx,ez=lz-qz,d=Math.hypot(ex,ez);if(d>=r)continue;
          if(d<1e-4){if(o.hx-Math.abs(lx)<o.hz-Math.abs(lz)){ex=Math.sign(lx)||1;ez=0;}else{ex=0;ez=Math.sign(lz)||1;}d=0;}else{ex/=d;ez/=d;}
          const nx=ex*c+ez*s,nz=-ex*s+ez*c,push=r-d;p.x+=nx*push;p.z+=nz*push;
          const vn=v.x*nx+v.z*nz;
          if(vn<0){
            if(o.mass){const k=-vn*o.mass;o.vx-=nx*k;o.vz-=nz*k;o.spin+=(Math.random()-.5)*k*.6;o.tip=Math.min(1,(o.tip||0)+k*.08);}
            v.x-=nx*vn*1.5;v.z-=nz*vn*1.5;hit=true;
          }
        }
        // Crates are solid boxes: Dahrooj bounces off their sides and can land on top. Until the
        // fuse burns down they stay where they are; then they're gone.
        for(const c of out.crates){
          if(c.exploded&&!(c.fuse>0))continue;const half=.53*CRATE*(c.k??1);
          const cs=Math.cos(c.rot),sn=Math.sin(c.rot),dx=p.x-c.x,dy=p.y-(c.y+half),dz=p.z-c.z;
          const lx=dx*cs-dz*sn,lz=dx*sn+dz*cs;
          const qx=clamp(lx,-half,half),qy=clamp(dy,-half,half),qz=clamp(lz,-half,half);
          let ex=lx-qx,ey=dy-qy,ez=lz-qz,d=Math.hypot(ex,ey,ez);if(d>=r)continue;
          if(d<1e-4){
            // Centre inside the box: out through the nearest face.
            const fx=half-Math.abs(lx),fy=half-Math.abs(dy),fz=half-Math.abs(lz),m=Math.min(fx,fy,fz);
            ex=m===fx?Math.sign(lx)||1:0;ey=m===fy?Math.sign(dy)||1:0;ez=m===fz&&m!==fx&&m!==fy?Math.sign(lz)||1:0;d=-m;
          }else{ex/=d;ey/=d;ez/=d;}
          const nx=ex*cs+ez*sn,nz=-ex*sn+ez*cs,ny=ey,push=r-d;
          p.x+=nx*push;p.y+=ny*push;p.z+=nz*push;
          const vn=v.x*nx+v.y*ny+v.z*nz;
          if(vn<0){const k=ny>.7&&vn>-1.4?1:1.4;v.x-=nx*vn*k;v.y-=ny*vn*k;v.z-=nz*vn*k;hit=true;}
          explode(c);
        }
        return hit;
      };
      out.update=(dt,night)=>{
        poleGlowU.uOn.value=night>.5?1:0;
        flies.value+=((night>.5?1:0)-flies.value)*Math.min(1,dt/1.5);
        poolMat.opacity=night*.35;
        // Shoved props slide to a stop on the stone and settle back upright.
        for(const o of out.obstacles){if(!o.mass)continue;const it=o.it;
          if(Math.abs(o.vx)+Math.abs(o.vz)+Math.abs(o.spin)+(o.tip||0)<.002)continue;
          it.x+=o.vx*dt;it.z+=o.vz*dt;it.rot+=o.spin*dt;const f=Math.pow(.04,dt);o.vx*=f;o.vz*=f;o.spin*=f;
          o.tip=Math.max(0,(o.tip||0)-dt*1.5);it.tilt=Math.sin((o.tip||0)*Math.PI)*.35;
          const item=o.mass>.5?lanternItem:benchItem,list=o.mass>.5?lanterns:benches;item?.sync(list.indexOf(it));
        }
        // Shoved into the pond: it settles half under the water, with Motri's white line round it.
        for(const o of out.obstacles){if(!o.mass)continue;const it=o.it,wd=waterAt(it.x,it.z),want=wd>0?-Math.min(.45,.1+wd)*o.h:0;
          if(Math.abs((it.y||0)-want)>.002){it.y=(it.y||0)+(want-(it.y||0))*Math.min(1,dt*2.5);const item=o.mass>.5?lanternItem:benchItem,list=o.mass>.5?lanterns:benches;item?.sync(list.indexOf(it));
            if(wd>0&&Math.random()<dt*1.5)water.ripple(it.x,it.z,o.hx,o.hx*2.4,1.6);}
          if(wd>0)water.line(it.x,0,it.z,Math.max(o.hx,o.hz)*1.05);}
        for(const c of out.crates){
          // A crate left in the air drops onto the one below or the ground.
          if(!c.exploded){
            const below=out.crates.filter(o=>o!==c&&!o.exploded&&Math.abs(o.x-c.x)<.6&&Math.abs(o.z-c.z)<.6&&o.y<c.y).reduce((m,o)=>Math.max(m,o.y+1.06*CRATE),0);
            if(c.y>below+.001){c.vy=(c.vy||0)-9.8*dt;c.y=Math.max(below,c.y+c.vy*dt);if(c.y===below)c.vy=0;crateItem?.sync(crateSpots.indexOf(c));}
          }
          if(c.fuse>0){c.fuse-=dt;if(c.fuse<=0){
            const at=V(c.x,c.y+.53*CRATE,c.z);fireball(at,3.5);c.k=0;crateItem?.sync(crateSpots.indexOf(c));c.back=25;
            api.mark(c.x,c.z,1.6,.9);out.onExplode?.(at,3.5);
            // Crates next to it go up too, one after the other.
            for(const o of out.crates)if(!o.exploded&&Math.hypot(o.x-c.x,o.z-c.z,o.y-c.y)<1.8)explode(o);}}
          // Back after a while, popping in.
          if(c.exploded&&c.fuse<=0){c.back-=dt;if(c.back<=0){Object.assign(c,c.home,{exploded:false,k:.01,vy:0});}}
          if(!c.exploded&&c.k!=null&&c.k<1){c.k=Math.min(1,c.k+dt*3);crateItem?.sync(crateSpots.indexOf(c));}
        }
        for(let i=fires.length-1;i>=0;i--){const f=fires[i];f.t+=dt;
          const e=Math.min(1,f.t/.6);f.mesh.scale.setScalar(.5+(f.radius-.5)*(1-Math.pow(1-e,3)));
          f.mesh.rotation.z=-Math.min(1,f.t/2.25);f.mat.uniforms.progress.value=.15+.85*clamp((f.t-.25)/2,0,1);
          if(f.t>2.25){root.remove(f.mesh);f.mat.dispose();fires.splice(i,1);}}
      };
      // Every crate back in place (for tests and a fresh round).
      out.reset=()=>{for(const c of out.crates){Object.assign(c,c.home,{exploded:false,fuse:0,k:1,vy:0});crateItem?.sync(crateSpots.indexOf(c));}};
      out.explode=i=>explode(out.crates[i]);
      return out;
    })();

    /* ---------- the pond's surface effects, as Motri's water: a white line where anything meets the water
       (MeshDefaultMaterial's hasWater band), and rings that spread from a splash or from something bobbing ---------- */
    const water=(()=>{
      const MAX=48,ring=new T.RingGeometry(.86,1,40).rotateX(-Math.PI/2);
      const mat=new T.MeshBasicMaterial({color:0xffffff,transparent:true,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-2});
      const lines=new T.InstancedMesh(ring,mat,MAX);lines.count=0;lines.frustumCulled=false;lines.renderOrder=2;root.add(lines);
      // Ripples fade, so each gets its own opacity through a per-instance colour (white to the water's colour).
      const rmat=new T.MeshBasicMaterial({color:0xffffff,transparent:true,opacity:.85,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-2,vertexColors:false});
      const rip=new T.InstancedMesh(new T.RingGeometry(.92,1,48).rotateX(-Math.PI/2),rmat,MAX);rip.count=0;rip.frustumCulled=false;rip.renderOrder=2;
      root.add(rip);
      const ripples=[],queue=[],m4=new T.Matrix4(),col=new T.Color(),shallow=U.uShallow.value;
      return {
        line(x,y,z,r){queue.push([x,y,z,r]);},
        ripple(x,z,r0,r1,life){if(ripples.length>=MAX)ripples.shift();ripples.push({x,z,r0,r1,life,t:0});},
        update(dt){
          let n=0;
          for(const [x,y,z,r] of queue){if(n>=MAX)break;const h=Math.abs(y);if(h>=r)continue;const rr=Math.sqrt(r*r-h*h)*1.06+.02;
            m4.makeScale(rr,1,rr).setPosition(x,.004,z);lines.setMatrixAt(n++,m4);}
          lines.count=n;lines.instanceMatrix.needsUpdate=true;queue.length=0;
          let k=0;
          for(let i=ripples.length-1;i>=0;i--){const p=ripples[i];p.t+=dt;if(p.t>=p.life){ripples.splice(i,1);continue;}
            const e=p.t/p.life,rr=p.r0+(p.r1-p.r0)*(1-Math.pow(1-e,2));m4.makeScale(rr,1,rr).setPosition(p.x,.003,p.z);rip.setMatrixAt(k,m4);
            // Fading: blend from white into the shallow water's colour.
            col.copy(shallow).lerp(C('#ffffff'),1-e);rip.setColorAt(k,col);k++;}
          rip.count=k;rip.instanceMatrix.needsUpdate=true;if(rip.instanceColor)rip.instanceColor.needsUpdate=true;
        }
      };
    })();

    /* ---------- RainLines.js: quads falling from 20 m, wrapped around the view; short and slow for snow ---------- */
    const rainU={...U,thickness:{value:.015},elevation:{value:20},incline:{value:.2},size:{value:40},center:{value:new T.Vector2()},len:{value:2},localTime:{value:0},visibleRatio:{value:0}};
    let rainSpeed=.25;
    const rain=(()=>{
      const count=Math.pow(2,11),position=new Float32Array(count*12),offset=new Float32Array(count*8),random=new Float32Array(count*4),index=new Uint16Array(count*6);
      for(let l=0;l<count;l++){
        const x=Math.random(),z=Math.random(),r=Math.random();
        for(let v=0;v<4;v++){position.set([x,0,z],(l*4+v)*3);offset.set([v===0||v===1?1:0,v===0||v===3?1:0],(l*4+v)*2);random[l*4+v]=r;}
        index.set([l*4,l*4+3,l*4+2,l*4+2,l*4+1,l*4],l*6);
      }
      const geo=new T.BufferGeometry();geo.setAttribute('position',new T.BufferAttribute(position,3));geo.setAttribute('offset',new T.BufferAttribute(offset,2));geo.setAttribute('random',new T.BufferAttribute(random,1));geo.setIndex(new T.BufferAttribute(index,1));
      const mat=referenceShader(T,{uniforms:rainU,transparent:true,side:T.DoubleSide,
        vertexShader:`
          attribute vec2 offset;attribute float random;uniform float thickness,elevation,incline,size,len,localTime,visibleRatio;uniform vec2 center;
          varying vec4 vClip;varying float vDist;
          void main(){vec3 p=position;vec2 tangent=vec2(.707,-.707);
            p.xz*=size;p.xz-=center;float halfSize=size*.5;p.x=mod(p.x+halfSize,size)-halfSize;p.z=mod(p.z+halfSize,size)-halfSize;p.xz+=center;
            p.xz+=tangent*offset.x*thickness;
            float progress=mod(localTime+random,1.);
            p.y=elevation+len;p.y-=len*(1.-offset.y);p.y-=progress*(elevation+len);p.y=clamp(p.y,0.,elevation);
            p.y+=step(visibleRatio,fract(random*99.))*99.;
            p.xz+=tangent*p.y*incline*-1.;p.y-=.3;
            ${OUT}}`,
        fragmentShader:SHADE+'void main(){gl_FragColor=vec4(motriShade(vec3(1.),vec3(0.,1.,0.),0.),1.);}'});
      const m=new T.Mesh(geo,mat);m.frustumCulled=false;m.renderOrder=1;root.add(m);return m;
    })();

    /* ---------- Snow.js: snow that builds up on the ground in noisy drifts, with glitter ---------- */
    const snowU={...U,snowElevation:{value:-1},center:{value:new T.Vector2()}};
    const snowGround=(()=>{
      const geo=new T.PlaneGeometry(60,60,160,160).rotateX(-Math.PI/2);
      const mat=referenceShader(T,{uniforms:snowU,transparent:true,
        vertexShader:`
          uniform sampler2D uPerlin;uniform float snowElevation;uniform vec2 center;varying vec4 vClip;varying float vDist;varying float vDelta;varying vec2 vWorld;
          float elev(vec2 p){return snowElevation+smoothstep(0.,1.,texture2D(uPerlin,p*.1).r*texture2D(uPerlin,p*.07).r);}
          void main(){vec3 p=position;p.xz+=center;float e=elev(p.xz);vDelta=e;vWorld=p.xz;
            // Drifts stay low so Dahrooj can still roll: a quarter of Motri's height.
            p.y=max(e,0.)*.25+.01;${OUT}}`,
        fragmentShader:SHADE+`
          uniform sampler2D uPerlin;uniform float uTime;varying float vDelta;varying vec2 vWorld;`+TRACK+`
          float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
          // Dug out where balls rolled through.
          void main(){float alpha=smoothstep(.022,.5,vDelta)*(1.-trackAt(vWorld)*.9);if(alpha<.1)discard;
            vec3 col=motriShade(vec3(1.),vec3(0.,1.,0.),0.);
            float glitter=abs(mod(hash(floor(vWorld*.2*64.))*2.+uTime*.024,2.)-1.)*clamp(texture2D(uPerlin,vWorld*.05).r*2.,0.,1.);
            col+=pow(glitter,1000.)*2.;gl_FragColor=vec4(col,alpha);}`});
      const m=new T.Mesh(geo,mat);m.frustumCulled=false;m.visible=false;root.add(m);return m;
    })();

    /* ---------- Weather.js on Cycles: temperature, humidity, clouds, wind, rain and snow ---------- */
    const noise=x=>Math.sin(x)*Math.sin(x*1.678)*Math.sin(x*2.345);
    const state={time:'auto',weather:'auto',day:{},year:{},w:{}};
    const FIXED={day:.08,dusk:.25,night:.47,dawn:.8};
    let saved=null,lastDay=Date.now()/1000/DAY_SECONDS;
    // Night lights: moonlight from above and a soft warm lantern that follows the player.
    const moon=new T.DirectionalLight(0xc9d4ff,0);moon.position.set(-6,14,6);root.add(moon,moon.target);
    const lantern=new T.PointLight(0xffd9a0,0,16,1.6);root.add(lantern);
    const api={
      root,
      // The stone reaches from behind the player to just past the target at farZ.
      setPitch(farZ,nearZ=5){const z0=farZ-1.5,z1=Math.max(5,nearZ);U.uSlab.value.set(court.x,(z0+z1)/2,9,(z1-z0)/2);},
      // Press a track at (x, z): radius in metres, strength 0–1.
      mark(x,z,radius,strength){
        const u=(x-court.x)/TRACK_SIZE+.5,v=(z-court.z)/TRACK_SIZE+.5;if(u<0||v<0||u>1||v>1)return;
        const px=u*TRACK_PX,py=v*TRACK_PX,r=Math.max(1.5,radius/TRACK_SIZE*TRACK_PX);
        const gr=tctx.createRadialGradient(px,py,0,px,py,r);gr.addColorStop(0,`rgba(255,255,255,${clamp(strength,0,1)})`);gr.addColorStop(1,'rgba(255,255,255,0)');
        tctx.fillStyle=gr;tctx.fillRect(px-r,py-r,r*2,r*2);tracksDirty=true;
      },
      // How pressed the ground is at (x, z), 0–1 (for tests).
      trackAt(x,z){const u=(x-court.x)/TRACK_SIZE+.5,v=(z-court.z)/TRACK_SIZE+.5;if(u<0||v<0||u>1||v>1)return 0;return tctx.getImageData(u*TRACK_PX|0,v*TRACK_PX|0,1,1).data[0]/255;},
      // A stone material lit like the slab floor (time of day, fog), with the slabs' own grain: for the brick wall.
      // It takes half of Motri's purple core shadow, so every stone keeps its own colour (grey stays grey).
      stoneMaterial(color){
        return referenceShader(T,{uniforms:{...U,uColor:{value:color.clone()}},
          vertexShader:'varying vec4 vClip;varying float vDist;varying vec3 vNormal;varying vec3 vWorld;void main(){vNormal=normalize(mat3(modelMatrix)*normal);vec4 w=modelMatrix*vec4(position,1.);vWorld=w.xyz;vec4 mv=viewMatrix*w;vDist=-mv.z;gl_Position=projectionMatrix*mv;vClip=gl_Position;}',
          fragmentShader:SHADE+'uniform sampler2D uSlabs;uniform vec3 uColor;varying vec3 vNormal;varying vec3 vWorld;void main(){float g=texture2D(uSlabs,(vWorld.xy+vWorld.zz)*.35).r;vec3 c=uColor*(.86+.28*g);gl_FragColor=vec4(mix(motriShade(c,normalize(vNormal),0.),motriShade(c,uLightDir,0.),.5),1.);}'});
      },
      get settings(){return {time:state.time,weather:state.weather};},
      get weather(){return state.w;},
      get treesLoaded(){return treesLoaded;},
      // The pond for the game's physics: how far inside the water (x, z) is (0 on land); a white line where a
      // ball of radius r centred y above the surface meets the water; rings from a splash (strength 0-1).
      waterAt,
      waterline(x,y,z,r){if(waterAt(x,z)>0)water.line(x,y,z,r);},
      splash(x,z,k){const s=clamp(k,.15,1);water.ripple(x,z,.2,1+2.2*s,1.1+s);water.ripple(x,z,.1,.6+1.4*s,.8+s*.6);if(s>.5)water.ripple(x,z,.05,.4+s,.7);},
      bob(x,z,r){water.ripple(x,z,r*.9,r*2.6,1.8);},
      // For the nature sounds: the pond, where the trees stand, and how dark it is (0 day, 1 night).
      pond:POND,treeSpots:spots,get night(){return state.night||0;},
      // Motri's props: collide(pos, vel, radius) for each ball, onExplode(pos, radius) when a crate goes up.
      props,
      // time: auto | day | dusk | night | dawn; weather: auto | clear | rain | snow
      set({time,weather}={}){if(time)state.time=time;if(weather)state.weather=weather;},
      enable(on){
        if(on===root.visible)return;
        root.visible=on;
        if(on){saved={fog:scene.fog,bg:scene.background,line:lineMat&&[lineMat.color.getHex(),lineMat.opacity],hemi:hemi&&[hemi.color.getHex(),hemi.groundColor.getHex(),hemi.intensity],sun:sun&&[sun.color.getHex(),sun.intensity]};
          scene.fog=new T.Fog(0x9b89ff,20,50);scene.background=null;if(lineMat){lineMat.color.set(0xffffff);lineMat.opacity=.5;}}
        else if(saved){scene.fog=saved.fog;scene.background=saved.bg;
          if(lineMat){lineMat.color.setHex(saved.line[0]);lineMat.opacity=saved.line[1];}
          if(hemi){hemi.color.setHex(saved.hemi[0]);hemi.groundColor.setHex(saved.hemi[1]);hemi.intensity=saved.hemi[2];}
          if(sun){sun.color.setHex(saved.sun[0]);sun.intensity=saved.sun[1];}saved=null;}
      },
      update(dt,eye){
        if(!root.visible)return;
        // Tracks heal over about a minute; upload the canvas a few times a second at most.
        tracksFade+=dt;if(tracksFade>.5){tracksFade=0;tctx.fillStyle='rgba(0,0,0,.02)';tctx.fillRect(0,0,TRACK_PX,TRACK_PX);tracksDirty=true;}
        tracksUpload+=dt;if(tracksDirty&&tracksUpload>.08){tracksUpload=0;tracksDirty=false;trackTex.needsUpdate=true;}
        const now=Date.now()/1000,dayAbs=now/DAY_SECONDS,progressDelta=Math.max(0,dayAbs-lastDay);lastDay=dayAbs;
        const dayP=state.time==='auto'?dayAbs%1:FIXED[state.time],yearP=(now/(60*60*24*365))%1;
        const d=blend(DAY_KEYS,dayP,state.day),y=blend(YEAR_KEYS,yearP,state.year),w=state.w;
        // Weather.js formulas.
        w.temperature=y.temperature+d.temperature+noise(dayAbs*.4)*7.5;
        w.humidity=y.humidity+noise(dayAbs*.36)*.2;
        w.clouds=noise(dayAbs*.44);
        w.wind=noise(dayAbs)*.5+.5;
        w.rain=remapClamp(w.humidity,.65,1,0,1)*remapClamp(w.clouds,0,1,0,1);
        w.snow=remapClamp(w.rain,.05,.3,0,1)*remapClamp(w.temperature,0,-5,0,1)+remapClamp(w.temperature,0,10,0,-1);
        // Auto: a cycle on the clock (Motri's own formulas left rain rare and snow to cold winters).
        if(state.weather==='auto'){
          const q=(now/WEATHER_SECONDS)%1,band=(a,b)=>clamp(Math.min((q-a)/.04,(b-q)/.04),0,1);
          const rainy=band(.22,.45),snowy=band(.68,.92);
          w.rain=Math.max(rainy*.85,snowy*.8);w.snow=snowy>0?snowy*2-1:-1;
          w.wind=Math.max(w.wind,rainy*.65);w.weatherPhase=q;
        }
        // The menu can force a spell, like Motri's weather override.
        if(state.weather==='clear'){w.rain=0;w.snow=-1;}
        else if(state.weather==='rain'){w.rain=.8;w.snow=-1;w.wind=Math.max(w.wind,.6);}
        else if(state.weather==='snow'){w.rain=.8;w.snow=1;}
        // Lighting and fog.
        U.uLightColor.value.copy(d.lightColor);U.uShadowColor.value.copy(d.shadowColor);
        U.uFogA.value.copy(d.fogColorA);U.uFogB.value.copy(d.fogColorB);
        // A gentler sky than the raw fog colours: a pale horizon and a deep top, greyer when it rains.
        const cloud=clamp(w.rain*1.2,0,1),grey=C('#9aa0b0');
        U.uHorizon.value.copy(d.fogColorA).lerp(C('#ffffff'),.35).lerp(grey,cloud*.5);
        U.uZenith.value.copy(d.fogColorB).lerp(d.fogColorA,.15).lerp(grey.clone().multiplyScalar(.7),cloud*.6);
        const sa=dayP*Math.PI*2;U.uSunDir.value.set(Math.cos(sa)*.6,.25+.5*Math.abs(Math.cos(sa*.5)),-.75).normalize();
        if(eye)sky.position.copy(eye);
        U.uStars.value=(1-cloud)*clamp(Math.min((dayP-.25)/.1,(.7-dayP)/.1),0,1);
        const near=20,amplitude=25;U.uFogNear.value=near+d.fogNearRatio*amplitude;U.uFogFar.value=near+d.fogFarRatio*amplitude;
        scene.fog.color.copy(U.uHorizon.value);scene.fog.near=Math.max(1,U.uFogNear.value);scene.fog.far=U.uFogFar.value+10;
        // The game's own objects take Motri's light too.
        // The game's own models (Dahrooj, the goal, the keeper) take Motri's light, but never go dark:
        // at night a pale moonlight and a warm lantern around the player keep them readable.
        const k=d.lightIntensity>2?1/3:1,night=clamp(Math.min((dayP-.22)/.08,(.75-dayP)/.08),0,1);
        if(hemi){hemi.color.copy(d.lightColor).lerp(C('#ffffff'),.35+night*.25);hemi.groundColor.copy(d.shadowColor).lerp(C('#c1c8d6'),.6);
          hemi.intensity=Math.max(1.65,1.4*d.lightIntensity*k);}
        if(sun){sun.color.copy(d.lightColor).lerp(C('#c9d4ff'),night*.6);sun.intensity=Math.max(1.15,1.6*d.lightIntensity*k);}
        state.night=night;moon.intensity=night*.45;lantern.intensity=night*1.1;if(eye)lantern.position.set(eye.x,eye.y+.5,eye.z-1.5);
        // Motri's own pieces are lit a little brighter at night too.
        U.uLightIntensity.value=d.lightIntensity*(1-night*.35)+night*.6;
        props.update(dt,night);water.update(dt);
        // Drop shadows: redrawn a few times a second at most, and only after something moved.
        shadowWait-=dt;if(shadowDirty&&shadowWait<=0){shadowDirty=false;shadowWait=.15;bakeShadows(props.castShadows||(()=>{}));}
        // Wind.js
        U.uWindStrength.value=remapClamp(w.wind,0,1,.1,1);U.uWindTime.value+=dt*.1*U.uWindStrength.value;
        U.uTime.value+=dt;
        if(eye)U.uCam.value.copy(eye);
        // RainLines.js
        const snowRatio=1-Math.pow(1-Math.max(w.snow,0),4);
        rainU.visibleRatio.value=Math.pow(w.rain,2);
        rainU.len.value=lerp(remapClamp(w.rain,0,1,1,3),.03,snowRatio);
        rainSpeed=lerp(remapClamp(w.rain,0,1,.2,.4),.05,snowRatio);
        rainU.incline.value=remapClamp(w.wind,0,1,.1,.4);
        rain.visible=rainU.visibleRatio.value>.00001;
        if(eye)rainU.center.value.set(eye.x,eye.z);
        rainU.localTime.value+=dt*rainSpeed;
        // Snow.js: the ground layer rises while it snows and melts away otherwise.
        const forced=state.weather==='snow'?dt*.045:state.weather==='clear'||state.weather==='rain'?-dt*.05:0;
        snowU.snowElevation.value=clamp(snowU.snowElevation.value+w.snow*progressDelta*10+forced,-1,.5);
        snowGround.visible=snowU.snowElevation.value>-.9;
        if(eye)snowU.center.value.set(Math.round(eye.x/.375)*.375,Math.round(eye.z/.375)*.375);
      }
    };
    return api;
  };
})();
