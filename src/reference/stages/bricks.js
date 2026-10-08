/* Aboden Games reference implementation, owner-authorized complete port 2026-10-08. See COMPLETE-REFERENCE-PORT-AR.md. */
export default function create(ctx){const {T,scene,groundLine,rbox,V,audio,sfxOut,thump,addCount,chProgress,chState,S,success,confetti,chime,toast,xrOnNow,BR,hit}=ctx;let {xrLang}=ctx;
function buildBricks(){
    const grp=new T.Group(); scene.add(grp);
    // Big, so the bricks read clearly, and Dahrooj comes back to you off the wall. In the headset it stands
    // about as far off as the goal and the cans (reachZ), a little nearer.
    const BZ=-10, WW=8.6, WH=4.1, FACE=BZ+0.1, BW=0.98, BH=0.48, BD=0.34, GAP=0.07;
    groundLine(grp,-14,BZ,14,BZ);
    // Stone bricks in the colours of the headset's slab floor (between its low and high tones), each a
    // slightly different shade like the slabs, matte with a soft sheen.
    // Each level takes another stone, always a natural one: the slab floor's sandstone, grey granite, red brick,
    // dark basalt and pale limestone (low and high tones; the bricks are shades between them).
    const PALETTES=[['#a87762','#ffcf8b'],['#8f8274','#dccdb9'],['#844331','#c47452'],['#6f6257','#b3a492'],['#b8946a','#f0dcb8']];
    const SHADES=[.38,.5,.6,.7,.8,.9], matCache=[];
    const matsFor=pi=>matCache[pi]||(matCache[pi]=SHADES.map(k=>new T.MeshStandardMaterial({color:new T.Color(PALETTES[pi][0]).lerp(new T.Color(PALETTES[pi][1]),k),roughness:0.72})));
    let brickMats=matsFor(0);
    const brickGeo=rbox(BW,BH,BD,0.07,brickMats[0]).geometry;
    const starMat=new T.MeshStandardMaterial({color:0xf2c14e,emissive:0xf2c14e,emissiveIntensity:0.5,roughness:0.3});
    const starGeo=new T.OctahedronGeometry(0.11);
    // Levels: rows of columns that hold a brick (8 columns, offset every other row like real masonry).
    const LEVELS=[
      ['11111111','11111111','11111111','11111111','11111111','11111111'],
      ['10101010','01010101','10101010','01010101','10101010','01010101'],
      ['00011000','00111100','01111110','11111111','11111111','11111111'],
      ['11100111','11111111','11111111','01111110','00111100','00011000'],
      ['11111111','11000011','10111101','10111101','11000011','11111111'],
    ];
    const B={bricks:[],level:0,cleared:false,brokeShot:false,fx:[],stone:null,make:null};const stoneCache=[];
    const stoneFor=pi=>stoneCache[pi]||(stoneCache[pi]=matsFor(pi).map(m=>B.make(m.color)));
    function layout(){
      for(const b of B.bricks) grp.remove(b.mesh); B.bricks.length=0;
      const pi=B.level%PALETTES.length;brickMats=matsFor(pi);B.stone=B.make?stoneFor(pi):null;
      const rows=LEVELS[B.level%LEVELS.length].slice().reverse(); // patterns read top to bottom; row 0 sits on the ground
      rows.forEach((row,r)=>{ for(let c=0;c<8;c++){ if(row[c]!=='1') continue;
        // Every other row sits a little over, like laid bricks.
        const x=(c-3.5)*(BW+GAP)+(r%2?0.25:-0.12), y=0.01+r*(BH+GAP*0.6)+BH/2;
        const mi=(r*5+c*3+B.level)%brickMats.length, m=new T.Mesh(brickGeo,(B.stone||brickMats)[mi]); m.position.set(x,y,FACE+BD/2+0.01);
        m.castShadow=true; m.receiveShadow=true; m.scale.setScalar(0.001); grp.add(m);
        B.bricks.push({mesh:m,mi,alive:true,grow:-(r*8+c)*0.025,half:V(BW/2,BH/2,BD/2)});
      }});
      B.cleared=false;
      buildTowers(B.level);
    }
    /* The castle front: a tower each side of the wall, of the same bricks, in a new design every level (a square
       keep, round towers with a roof, tall towers with a jutting crown, stepped towers, round towers with
       battlements). They rise out of the ground like the bricks grow in. They don't break; Dahrooj bounces off
       them. Each tower's bricks are merged into one mesh per shade, so a tower costs a handful of draws. */
    const TX=4*(BW+GAP)+(2*BW+GAP)/2+0.25, rowY=r=>0.01+r*(BH+GAP*0.6)+BH/2, ZC=FACE+BD/2+0.01-0.75+BD/2;
    let decor=[], towers=[], towerBoxes=[];
    const roofMats=[];
    const roofFor=pi=>roofMats[pi]||(roofMats[pi]=new T.MeshStandardMaterial({color:new T.Color(PALETTES[pi][0]).multiplyScalar(0.72),roughness:0.8,flatShading:true}));
    function mergeParts(parts,mats,into){
      const src=brickGeo, pos=src.attributes.position, nor=src.attributes.normal, uv=src.attributes.uv, nm=new T.Matrix3(), pv=V(0,0,0);
      parts.forEach((list,mi)=>{
        if(!list.length) return;
        const n=pos.count, P=new Float32Array(n*3*list.length), N=new Float32Array(n*3*list.length), U=uv?new Float32Array(n*2*list.length):null;
        list.forEach((mat,k)=>{ nm.getNormalMatrix(mat);
          for(let i=0;i<n;i++){ pv.fromBufferAttribute(pos,i).applyMatrix4(mat); P.set([pv.x,pv.y,pv.z],(k*n+i)*3);
            pv.fromBufferAttribute(nor,i).applyMatrix3(nm).normalize(); N.set([pv.x,pv.y,pv.z],(k*n+i)*3);
            if(U){ U[(k*n+i)*2]=uv.getX(i); U[(k*n+i)*2+1]=uv.getY(i); } } });
        const g=new T.BufferGeometry(); g.setAttribute('position',new T.BufferAttribute(P,3)); g.setAttribute('normal',new T.BufferAttribute(N,3)); if(U) g.setAttribute('uv',new T.BufferAttribute(U,2));
        const m=new T.Mesh(g,mats[mi]); m.castShadow=true; m.receiveShadow=true; into.add(m); decor.push({mesh:m,mi});
      });
    }
    // One tower at x = cx in design v; returns its group, its collision box and the height of its top.
    function tower(cx,side,v,mats,pi){
      const parts=SHADES.map(()=>[]), q=new T.Quaternion(), up=V(0,1,0), sc=V(1,1,1), grp2=new T.Group();
      const put=(mi,x,y,z,ry=0,sx=1,sy=1,sz=1)=>{ q.setFromAxisAngle(up,ry); parts[((mi%6)+6)%6].push(new T.Matrix4().compose(V(x,y,z),q,sc.clone().set(sx,sy,sz))); };
      // A square shaft w bricks wide and d deep, rows r0..r1, with its core.
      const square=(w,d,r0,r1,dx=0)=>{
        const W=w*(BW+GAP)-GAP, D=d;
        for(let r=r0;r<r1;r++){ const y=rowY(r), off=(r%2)?BW*0.25:-BW*0.25;
          for(const fz of [ZC+D/2-BD/2, ZC-D/2+BD/2]) for(let c=0;c<w;c++) put(r*3+c*2+(side>0?1:0),cx+dx+(c-(w-1)/2)*(BW+GAP)+off*0.4,y,fz);
          for(const sx of [-1,1]) put(r*5+(sx>0?1:4),cx+dx+sx*(W/2-BD/2),y,ZC,Math.PI/2,(D-2*BD)/BW*0.98,1,1); }
        put(2,cx+dx,(rowY(r0)-BH/2+rowY(r1-1)+BH/2)/2,ZC,0,(W-0.08)/BW,(rowY(r1-1)-rowY(r0)+BH)/BH*0.98,(D-0.08)/BD);
        return {W,D};
      };
      // Merlons round the top of a square shaft.
      const merlons=(W,D,r,dx=0,size=0.42)=>{ const y=rowY(r)-BH*0.15;
        for(const k of [-1,0,1]){ put(k+3,cx+dx+k*(W/2-size/2),y,ZC+D/2-BD/2,0,size/BW,1.1,1); put(k+4,cx+dx+k*(W/2-size/2),y,ZC-D/2+BD/2,0,size/BW,1.1,1); }
        for(const sx of [-1,1]) put(sx+3,cx+dx+sx*(W/2-BD/2),y,ZC,Math.PI/2,size/BW,1.1,1); };
      // A round shaft: n bricks round a ring of radius rad, turned to face out.
      const round=(rad,n,r0,r1)=>{ for(let r=r0;r<r1;r++){ const y=rowY(r), a0=(r%2)*Math.PI/n;
          for(let k=0;k<n;k++){ const a=a0+k/n*Math.PI*2; put(r+k*2,cx+Math.sin(a)*rad,y,ZC+Math.cos(a)*rad,a,(2*Math.PI*rad/n)/BW*0.98,1,1); } }
        put(2,cx,(rowY(r0)-BH/2+rowY(r1-1)+BH/2)/2,ZC,0,(rad*1.7)/BW,(rowY(r1-1)-rowY(r0)+BH)/BH*0.98,(rad*1.7)/BD); };
      const roundMerlons=(rad,n,r)=>{ const y=rowY(r)-BH*0.15; for(let k=0;k<n;k+=2){ const a=k/n*Math.PI*2; put(k,cx+Math.sin(a)*rad,y,ZC+Math.cos(a)*rad,a,(2*Math.PI*rad/n)/BW*0.98,1.1,1); } };
      let top, half;
      if(v===0){ const {W,D}=square(2,1.5,0,9); merlons(W,D,9); top=rowY(9)+BH*0.4; half=V(W/2,top/2,D/2); }
      else if(v===1){ const rad=0.82; round(rad,10,0,10); top=rowY(10)-BH/2;
        const cone=new T.Mesh(new T.ConeGeometry(rad*1.25,1.5,10),roofFor(pi)); cone.position.set(cx,top+0.75,ZC); cone.castShadow=true; grp2.add(cone); decor.push({mesh:cone,roof:true});
        top+=1.5; half=V(rad,top/2,rad); }
      else if(v===2){ square(2,1.4,0,11); // a jutting crown: a wider ring of bricks on top
        const c=square(3,2.0,11,13); merlons(c.W,c.D,13,0,0.4); top=rowY(13)+BH*0.4; half=V(c.W/2,top/2,c.D/2); }
      else if(v===3){ square(3,2.0,0,4); square(2,1.5,4,8); const c=square(1,1.0,8,11); merlons(c.W+0.3,c.D,11,0,0.3); top=rowY(11)+BH*0.4; half=V((3*(BW+GAP)-GAP)/2,top/2,1); }
      else { const rad=0.95; round(rad,12,0,8); roundMerlons(rad,12,8); top=rowY(8)+BH*0.4; half=V(rad,top/2,rad); }
      mergeParts(parts,mats,grp2);
      return {grp:grp2,box:{c:V(cx,top/2,ZC),h:half},top};
    }
    // Flags: a wooden pole and a coral pennant on each tower top, waving.
    const flags=[];
    const poleMat=new T.MeshStandardMaterial({color:0x8a5a34,roughness:0.6}), clothMat=new T.MeshStandardMaterial({color:0xe2603f,roughness:0.7,side:T.DoubleSide});
    function buildTowers(level){
      for(const t of towers) grp.remove(t.grp); towers=[]; decor=[]; towerBoxes=[]; flags.length=0;
      const v=level%5, pi=level%PALETTES.length, mats=B.stone||matsFor(pi);
      for(const side of [-1,1]){
        const t=tower(side*TX,side,v,mats,pi);
        const pole=new T.Mesh(new T.CylinderGeometry(0.035,0.04,1.3,10),poleMat); pole.position.set(side*TX,t.top+0.6,ZC); pole.castShadow=true; t.grp.add(pole);
        const g=new T.PlaneGeometry(0.8,0.45,8,1); g.translate(0.4,0,0);
        const cloth=new T.Mesh(g,clothMat); cloth.position.set(side*TX,t.top+1.05,ZC); cloth.castShadow=true; t.grp.add(cloth);
        flags.push({cloth,base:g.attributes.position.array.slice(),phase:side});
        // Rising out of the ground, the far side a moment after the near.
        t.grp.scale.y=0.001; t.rise=-(side>0?0.25:0)-0.15; grp.add(t.grp); towers.push(t); towerBoxes.push(t.box);
      }
    }
    layout();
    function tink(k){
      if(!audio) return; const t=audio.currentTime, o=audio.createOscillator(), g=audio.createGain(), out=sfxOut();
      o.type='triangle'; o.frequency.setValueAtTime(880+k*420,t); o.frequency.exponentialRampToValueAtTime(1320+k*520,t+0.06);
      g.gain.setValueAtTime(0.0001,t); g.gain.exponentialRampToValueAtTime(0.12,t+0.008); g.gain.exponentialRampToValueAtTime(0.0001,t+0.28);
      o.connect(g).connect(out); o.start(t); o.stop(t+0.3);
    }
    function breakBrick(b,n,speed){
      b.alive=false; B.brokeShot=true; tink(Math.random()); thump(Math.min(1,speed/14)*0.6);
      const star=new T.Mesh(starGeo,starMat); star.position.copy(b.mesh.position).add(V(0,0,BD)); grp.add(star);
      B.fx.push({brick:b.mesh,star,t:0,dir:V((Math.random()-.5)*1.2,1.4,1.2)});
      addCount('bricks'); chProgress('bricks20',(chState.bricks20||0)+1);
      // Smashed by a throw: Dahrooj cheers. Smashed by shots while he's in your hand: the wall celebrates on its own
      // (a scored state on a Dahrooj who isn't flying would never run out and he couldn't be thrown again).
      if(B.bricks.every(x=>!x.alive)){ B.cleared=true; chProgress('wall1',1);
        if(S.shot){ S.scoredT=0; S.missT=0; success(); } else { confetti.celebrate(V(0,1.6,FACE+0.4)); chime(); }
        toast(xrOnNow()&&xrLang==='en'?'You smashed the wall!':'حطّمت الحائط!'); }
    }
    const cp=V(0,0,0), n=V(0,0,0);
    // Sphere against an axis-aligned box: push out, bounce, break.
    function hitBrick(b){
      const p=b.mesh.position, P=S.pos;
      cp.set(Math.max(p.x-b.half.x,Math.min(P.x,p.x+b.half.x)),Math.max(p.y-b.half.y,Math.min(P.y,p.y+b.half.y)),Math.max(p.z-b.half.z,Math.min(P.z,p.z+b.half.z)));
      n.copy(P).sub(cp); const d=n.length();
      if(d<=0||d>=BR) return false;
      n.divideScalar(d); P.copy(cp).addScaledVector(n,BR);
      const vn=S.vel.dot(n); if(vn<0){ hit(n,-vn,cp.clone()); S.vel.addScaledVector(n,-(1.8)*vn); S.side.set(0,0,0); breakBrick(b,n,-vn); } // e = 0.8: he comes back to you
      return true;
    }
    // The towers: solid, Dahrooj bounces off them.
    function hitTower(t){
      const P=S.pos,c=t.c,h=t.h;
      cp.set(Math.max(c.x-h.x,Math.min(P.x,c.x+h.x)),Math.max(c.y-h.y,Math.min(P.y,c.y+h.y)),Math.max(c.z-h.z,Math.min(P.z,c.z+h.z)));
      n.copy(P).sub(cp); const d=n.length(); if(d<=0||d>=BR) return;
      n.divideScalar(d); P.copy(cp).addScaledVector(n,BR);
      const vn=S.vel.dot(n); if(vn<0){ hit(n,-vn,cp.clone()); S.vel.addScaledVector(n,-1.7*vn); S.side.set(0,0,0); }
    }
    return {
      grp, aimZ:FACE+BD, farZ:BZ-0.5, reachZ:-18.5,
      shoot(obj,point,dir){ const b=B.bricks.find(x=>x.alive&&x.mesh===obj); if(!b) return false; breakBrick(b,dir.clone().negate(),12); return true; },
      ft:sp=>Math.max(0.5,Math.min(1.25,1.35-sp/2600)),
      behind:P=>P.z<BZ-0.05,
      shotTime:7,
      touched:()=>B.brokeShot,
      onRespawn(){ B.brokeShot=false; if(B.cleared){ B.level++; layout(); } },
      collide(){
        const P=S.pos;
        for(const b of B.bricks) if(b.alive&&b.grow>=1) hitBrick(b);
        for(const t of towerBoxes) hitTower(t);
      },
      update(dt){
        for(const t of towers){ if(t.rise<1){ t.rise=Math.min(1,t.rise+dt*1.6); const k=Math.max(0,t.rise); t.grp.scale.y=Math.max(0.001,k<1?1-Math.pow(1-k,3)*(1-Math.sin(k*Math.PI)*0.12):1); } }
        // Cleared with the headset's blaster while Dahrooj is still in hand: a moment later, the next wall.
        if(B.cleared&&!S.shot){ B.autoT=(B.autoT||0)+dt; if(B.autoT>1.6){ B.autoT=0; B.level++; layout(); } } else B.autoT=0;
        for(const f of flags){ const a=f.cloth.geometry.attributes.position; f.t=(f.t||0)+dt;
          for(let i=0;i<a.count;i++){ const x=f.base[i*3]; a.setZ(i,Math.sin(x*5-f.t*6+f.phase)*0.08*x); } a.needsUpdate=true; f.cloth.geometry.computeVertexNormals(); }
        for(const b of B.bricks){ if(b.grow<1){ b.grow=Math.min(1,b.grow+dt*3.2); if(b.alive){ const k=Math.max(0,b.grow), s=1+Math.sin(k*Math.PI)*0.18*(1-k); b.mesh.scale.setScalar(Math.max(0.001,k*s)); } } }
        for(let i=B.fx.length-1;i>=0;i--){ const f=B.fx[i]; f.t+=dt;
          const k=Math.min(1,f.t/0.35); f.brick.scale.setScalar(Math.max(0.001,1-k)); f.brick.rotation.z+=dt*6;
          f.star.position.addScaledVector(f.dir,dt); f.dir.y-=dt*2.5; f.star.rotation.y+=dt*8; f.star.scale.setScalar(Math.max(0.001,1-f.t/0.9));
          if(f.t>0.9){ grp.remove(f.star); f.brick.visible=false; B.fx.splice(i,1); } }
      },
      // The headset's VR world lends its slab-floor shading so the bricks match the floor at every time of day.
      useStone(make){ B.make=make||null; const pi=B.level%PALETTES.length; B.stone=make?stoneFor(pi):null; for(const b of [...B.bricks,...decor]) if(!b.roof) b.mesh.material=(B.stone||brickMats)[b.mi]; },
      get bricksLeft(){ return B.bricks.filter(b=>b.alive).length; },
      get level(){ return B.level; },
      get towers(){ return towers.map(t=>({top:+t.top.toFixed(2),rise:+Math.min(1,t.rise).toFixed(2)})); },
      nextLevel(){ B.level++; layout(); },
      // Tests: break every brick left as shots would.
      smashAll(){ for(const b of B.bricks) if(b.alive) breakBrick(b,V(0,0,1),12); },
    };
  }
const stage=buildBricks(),update=stage.update;stage.update=function(dt){xrLang=ctx.xrLang;update.call(stage,dt);};return stage;}