/* Aboden Games reference implementation, owner-authorized complete port 2026-10-08. See COMPLETE-REFERENCE-PORT-AR.md. */
export default function create(ctx){const {T,scene,groundLine,rbox,xrOnNow,COL,ar,audio,sfxOut,S,addCount,chProgress,toast,V,GRAV,thump,BR,hit,squeak,startPopSound,confetti,chState,counts,UP,chime}=ctx;let {xrLang,time}=ctx;
function buildFair(){
    const grp=new T.Group(); scene.add(grp);
    const FZ=-9.5, CY=1.05, ROUND=60;
    groundLine(grp,-14,FZ,14,FZ);
    const mat=(c,o={})=>new T.MeshStandardMaterial({color:c,roughness:0.55,...o});
    const wood=mat(0xc98f5c,{roughness:0.65}), woodDark=mat(0x9a6a43,{roughness:0.7}), cream=mat(0xfffaf2,{roughness:0.5}), coral=mat(0xe2603f,{roughness:0.55});
    const add=(m,x,y,z)=>{ m.position.set(x,y,z); m.castShadow=true; m.receiveShadow=true; grp.add(m); return m; };
    // The stall: back panel, counter, two posts and a striped awning.
    add(rbox(6.4,2.6,0.25,0.08,wood),0,1.3+CY*0.0,FZ-1.1);
    add(rbox(6.6,0.16,1.0,0.06,cream),0,CY,FZ+0.2);
    add(rbox(6.4,CY-0.08,0.9,0.08,woodDark),0,(CY-0.08)/2,FZ+0.2);
    for(const x of [-3.15,3.15]) add(new T.Mesh(new T.CylinderGeometry(0.09,0.1,3.2,16),cream),x,1.6,FZ+0.55);
    // The awning: rounded stripes running front to back, sloping down toward you, with a scalloped fringe.
    const awn=new T.Group(); awn.position.set(0,3.3,FZ+0.05); awn.rotation.x=0.28; grp.add(awn);
    const SR=6.8/24, stripe=new T.CylinderGeometry(SR,SR,1.9,16,1,true,Math.PI/2,Math.PI);
    const coralD=new T.MeshStandardMaterial({color:0xe2603f,roughness:0.6,side:T.DoubleSide}), creamD=new T.MeshStandardMaterial({color:0xfffaf2,roughness:0.6,side:T.DoubleSide});
    for(let i=0;i<12;i++){ const st=new T.Mesh(stripe,i%2?creamD:coralD); st.rotation.x=Math.PI/2; st.position.set(-3.4+SR+i*2*SR,0,0); st.scale.set(1,1,0.55); st.castShadow=true; awn.add(st); }
    // The fringe arches the same way as the stripes, a little taller than their rounded ends, in the other colour.
    const scallop=new T.CircleGeometry(SR,16,0,Math.PI);
    for(let i=0;i<12;i++){ const sc=new T.Mesh(scallop,i%2?coralD:creamD); sc.position.set(-3.4+SR+i*2*SR,-0.01,0.955); sc.scale.set(1,0.8,1); sc.castShadow=true; awn.add(sc); }
    // The sign: time left and points, drawn on a board under the awning.
    const signC=document.createElement('canvas'); signC.width=512; signC.height=128; const sg=signC.getContext('2d'), signT=new T.CanvasTexture(signC);
    // It stands on top of the awning, like a fairground crest.
    add(rbox(2.6,0.66,0.12,0.05,cream),0,4.05,FZ-0.35);
    const sign=new T.Mesh(new T.PlaneGeometry(2.4,0.6),new T.MeshBasicMaterial({map:signT,transparent:true})); sign.position.set(0,4.05,FZ-0.28); grp.add(sign);
    // Targets. Ducks run along a rail on the counter, balloons float above them, the bell hangs at the side.
    const duckMat=mat(0xf2c14e,{roughness:0.4}), beakMat=coral, eyeMat=mat(0x1b1c26,{roughness:0.2});
    function duck(){ const g=new T.Group(); const b=new T.Mesh(new T.SphereGeometry(0.2,22,16),duckMat); b.scale.set(1.25,0.9,1); g.add(b);
      const h=new T.Mesh(new T.SphereGeometry(0.13,18,14),duckMat); h.position.set(0.15,0.2,0); g.add(h);
      const bk=new T.Mesh(new T.ConeGeometry(0.05,0.12,10),beakMat); bk.rotation.z=-Math.PI/2; bk.position.set(0.3,0.19,0); g.add(bk);
      for(const z of [-0.07,0.07]){ const e=new T.Mesh(new T.SphereGeometry(0.025,8,6),eyeMat); e.position.set(0.22,0.25,z); g.add(e); }
      g.traverse(o=>{ if(o.isMesh) o.castShadow=true; }); return g; }
    add(new T.Mesh(new T.BoxGeometry(6.2,0.05,0.1),mat(0xb9ad9c,{metalness:0.4,roughness:0.4})),0,CY+0.1,FZ-0.05);
    const ducks=[]; for(let i=0;i<6;i++){ const g=duck(); g.position.set(0,CY+0.27,FZ-0.05); grp.add(g); ducks.push({g,u:i/6,down:0,downT:0,r:0.26}); }
    const BAL=[0x6fa8d6,0xe2603f,0x7bbf8a,0xc9a2e6,0xf2c14e];
    const balloons=[]; for(let i=0;i<5;i++){
      const m=new T.Mesh(new T.SphereGeometry(0.24,24,18),new T.MeshPhysicalMaterial({color:BAL[i],roughness:0.15,clearcoat:1})); m.scale.y=1.15; m.castShadow=true;
      const string=new T.Mesh(new T.CylinderGeometry(0.006,0.006,0.6,4),cream); string.position.y=-0.55; m.add(string);
      grp.add(m); balloons.push({m,x:-2.2+i*1.1,y:2.15+(i%2)*0.25,popT:0,r:0.27});
    }
    const bell=new T.Group(); bell.position.set(2.6,2.55,FZ-0.3); grp.add(bell);
    const bellM=new T.Mesh(new T.SphereGeometry(0.26,24,16,0,Math.PI*2,0,Math.PI*0.62),mat(0xe5ad2e,{metalness:0.75,roughness:0.25,side:T.DoubleSide}));
    bellM.position.y=-0.2; bellM.castShadow=true; bell.add(bellM);
    const clap=new T.Mesh(new T.SphereGeometry(0.06,12,10),woodDark); clap.position.y=-0.38; bell.add(clap);
    add(new T.Mesh(new T.CylinderGeometry(0.03,0.03,0.5,8),woodDark),2.6,2.8,FZ-0.3);
    const F={time:ROUND,on:false,score:0,best:0,swing:0,bellHits:0,shownKey:'',over:0};
    try{ F.best=+localStorage.getItem('dahrooj-fair-best')||0; }catch(_){}
    function drawSign(){
      const en=xrOnNow()&&xrLang==='en', key=[Math.ceil(F.time),F.score,F.best,F.on,en].join('|'); if(key===F.shownKey) return; F.shownKey=key;
      sg.clearRect(0,0,512,128); sg.fillStyle=COL.ink; sg.textAlign='center'; sg.font='800 64px "Dahrooj",Tahoma,sans-serif';
      const t=Math.ceil(F.time), left=F.on?(en?`${t}s`:`${ar(t)} ث`):(en?'Throw to start':'ارمِ وابدأ');
      sg.fillText(left,128,84); sg.fillStyle=COL.coral||'#e2603f'; sg.fillText(en?String(F.score):ar(F.score),384,84);
      sg.font='600 22px Tahoma,sans-serif'; sg.fillStyle='rgba(44,45,61,.6)'; sg.fillText(en?`best ${F.best}`:`أفضل ${ar(F.best)}`,384,118);
      signT.needsUpdate=true;
    }
    function ding(){
      if(!audio) return; const t=audio.currentTime, out=sfxOut();
      for(const [f,a] of [[1320,.12],[1980,.05],[2640,.03]]){ const o=audio.createOscillator(), g=audio.createGain();
        o.type='sine'; o.frequency.value=f; g.gain.setValueAtTime(.0001,t); g.gain.exponentialRampToValueAtTime(a,t+.01); g.gain.exponentialRampToValueAtTime(.0001,t+1.2);
        o.connect(g).connect(out); o.start(t); o.stop(t+1.25); }
    }
    function score(pts){
      const curved=S.side.lengthSq()>1;
      if(curved) pts*=2;
      F.score+=pts; for(let i=0;i<pts;i++) addCount('fair');
      chProgress('fair25',F.score);
      if(curved) toast(xrOnNow()&&xrLang==='en'?`Curved ×2: +${pts}`:`ملتفة ×٢: +${ar(pts)}`);
    }
    /* A hit duck flies off its rail, tumbling: it bounces off the stall (back board, counter, posts, awning), the
       balloons and the ground and rolls to a stop; then it vanishes and a new duck pops up on the rail. */
    const DUCK_R=0.22, stall=[
      {c:V(0,1.3,FZ-1.1),h:V(3.2,1.3,0.13)},{c:V(0,CY/2,FZ+0.2),h:V(3.3,CY/2+0.08,0.5)},
      {c:V(-3.15,1.6,FZ+0.55),h:V(0.1,1.6,0.1)},{c:V(3.15,1.6,FZ+0.55),h:V(0.1,1.6,0.1)},{c:V(0,3.3,FZ+0.05),h:V(3.4,0.2,1)}];
    function launchDuck(d,dir,speed){
      d.down=1; d.g.visible=true;
      const v=dir.clone(); v.y=Math.max(0.35,v.y); v.normalize().multiplyScalar(speed); v.y+=2.5; v.x+=(Math.random()-0.5)*2;
      d.fly={v,spin:V((Math.random()-0.5)*14,(Math.random()-0.5)*10,(Math.random()-0.5)*14),t:0,calm:0,home:null};
    }
    const dq=V(0,0,0);
    function stepDuck(d,dt,railX){
      const f=d.fly,p=d.g.position;
      if(f.gone!=null){
        // Done: it shrinks away where it lies, then a fresh duck pops up in its place on the rail.
        f.gone+=dt;
        if(f.gone<0.25){ d.g.scale.setScalar(Math.max(0.001,1-f.gone/0.25)); return; }
        if(!f.fresh){ f.fresh=true; p.set(railX,CY+0.27,FZ-0.05); d.g.rotation.set(0,0,0); }
        else p.x=railX;
        const k=Math.min(1,(f.gone-0.25)/0.35); d.g.scale.setScalar(Math.max(0.001,k*(1+Math.sin(k*Math.PI)*0.25))); d.g.visible=Math.abs(railX)<2.95;
        if(k>=1){ d.fly=null; d.down=0; d.g.scale.setScalar(1); }
        return;
      }
      f.t+=dt; f.v.y-=GRAV*dt; p.addScaledVector(f.v,dt);
      d.g.rotation.x+=f.spin.x*dt; d.g.rotation.y+=f.spin.y*dt; d.g.rotation.z+=f.spin.z*dt;
      let touched=false;
      for(const b of stall){
        const lx=p.x-b.c.x,ly=p.y-b.c.y,lz=p.z-b.c.z,ox=b.h.x+DUCK_R-Math.abs(lx),oy=b.h.y+DUCK_R-Math.abs(ly),oz=b.h.z+DUCK_R-Math.abs(lz);
        if(ox<=0||oy<=0||oz<=0) continue;
        touched=true;
        if(ox<oy&&ox<oz){ p.x+=Math.sign(lx)*ox; if(f.v.x*Math.sign(lx)<0) f.v.x*=-0.5; }
        else if(oy<oz){ p.y+=Math.sign(ly)*oy; if(f.v.y*Math.sign(ly)<0) f.v.y*=-0.45; f.v.x*=0.85; f.v.z*=0.85; }
        else{ p.z+=Math.sign(lz)*oz; if(f.v.z*Math.sign(lz)<0) f.v.z*=-0.5; }
      }
      for(const b of balloons){ if(b.popT>0) continue; dq.copy(p).sub(b.m.position); const l=dq.length(); if(l>0&&l<DUCK_R+b.r){ dq.divideScalar(l); p.copy(b.m.position).addScaledVector(dq,DUCK_R+b.r); const vn=f.v.dot(dq); if(vn<0) f.v.addScaledVector(dq,-1.6*vn); touched=true; } }
      if(p.y<DUCK_R){ p.y=DUCK_R; if(f.v.y<-1.2){ f.v.y*=-0.4; } else f.v.y=0; f.v.x*=Math.pow(0.15,dt); f.v.z*=Math.pow(0.15,dt); f.spin.multiplyScalar(Math.pow(0.1,dt)); touched=true; }
      if(touched&&f.v.length()>2&&f.t-(f.tap||0)>0.12){ f.tap=f.t; thump(Math.min(0.5,f.v.length()/20)); }
      f.calm=f.v.length()<0.6?f.calm+dt:0;
      // It flies and rolls until it settles (or a few seconds pass), then it's gone.
      if(f.t>4||f.calm>0.5||p.y<-2||Math.abs(p.x)>14) f.gone=0;
    }
    const tmp=V(0,0,0);
    function sphereHit(c,r,bounce){
      const P=S.pos; tmp.copy(P).sub(c); const d=tmp.length(); if(d<=0||d>=BR+r) return false;
      if(bounce){ tmp.divideScalar(d); P.copy(c).addScaledVector(tmp,BR+r); const vn=S.vel.dot(tmp); if(vn<0){ hit(tmp,-vn,c.clone().addScaledVector(tmp,r)); S.vel.addScaledVector(tmp,-1.5*vn); } }
      return true;
    }
    const wp=V(0,0,0);
    return {
      grp, aimZ:FZ, farZ:FZ-1.5, reachZ:-18.5,
      shoot(obj,point,dir){
        const owns=root=>{ for(let x=obj;x;x=x.parent) if(x===root) return true; return false; };
        for(const d of ducks) if(d.down<=0&&owns(d.g)){ launchDuck(d,dir||V(0,0,-1),6.5); squeak(1.35); score(1); return true; }
        for(const b of balloons) if(b.popT<=0&&owns(b.m)){ b.popT=2.2; startPopSound(); confetti.celebrate(b.m.position.clone()); score(2); return true; }
        if(owns(bell)&&F.swing<0.3){ F.swing=1; ding(); F.bellHits++; chProgress('bell3',(chState.bell3||0)+1); score(5); return true; }
        return false;
      },
      ft:sp=>Math.max(0.5,Math.min(1.25,1.35-sp/2600)),
      behind:P=>P.z<FZ-1.2,
      shotTime:4,
      touched:()=>F.touched,
      onRespawn(){ F.touched=false; },
      onThrow(){ if(!F.on&&F.over<=0){ F.on=true; F.time=ROUND; F.score=0; counts.fair=0; } },
      collide(){
        const P=S.pos;
        if(!S.shot) return;
        if(!F.on&&F.over<=0){ F.on=true; F.time=ROUND; F.score=0; counts.fair=0; }
        for(const d of ducks){ if(d.down>0) continue; d.g.getWorldPosition(wp); wp.y+=0.08;
          if(sphereHit(wp,d.r,true)){ launchDuck(d,S.vel.clone().normalize(),Math.min(9,S.vel.length()*.55)+3); F.touched=true; squeak(1.35); thump(0.4); score(1); } }
        for(const b of balloons){ if(b.popT>0) continue; if(sphereHit(b.m.position,b.r,false)){ b.popT=2.2; F.touched=true; startPopSound(); confetti.celebrate(b.m.position.clone()); score(2); } }
        bellM.getWorldPosition(wp); if(F.swing<0.3&&sphereHit(wp,0.3,true)){ F.swing=1; F.touched=true; ding(); F.bellHits++; chProgress('bell3',(chState.bell3||0)+1); score(5); }
        // The stall: the back panel and the counter bounce him back.
        if(P.z-BR<FZ-0.97&&P.z>FZ-1.6&&Math.abs(P.x)<3.2&&P.y<2.6){ P.z=FZ-0.97+BR; if(S.vel.z<0){ hit(V(0,0,1),-S.vel.z,V(P.x,P.y,FZ-0.97)); S.vel.z=-S.vel.z*0.5; S.side.set(0,0,0); } }
        if(Math.abs(P.x)<3.3&&P.z>FZ-0.3&&P.z<FZ+0.7&&P.y-BR<CY+0.08&&P.y>CY-0.3){ P.y=CY+0.08+BR; if(S.vel.y<0){ hit(UP,-S.vel.y,V(P.x,CY+0.08,P.z)); S.vel.y=-S.vel.y*0.45; } }
      },
      update(dt){
        // The round clock.
        if(F.on){ F.time-=dt; if(F.time<=0){ F.on=false; F.time=0; F.over=2.5;
          const best=F.score>F.best; if(best){ F.best=F.score; try{ localStorage.setItem('dahrooj-fair-best',String(F.best)); }catch(_){} }
          toast(xrOnNow()&&xrLang==='en'?`Time! ${F.score} points${best?' — best yet':''}`:`انتهى الوقت! ${ar(F.score)} نقطة${best?' · أفضل نتيجة':''}`); chime(); } }
        else if(F.over>0){ F.over-=dt; if(F.over<=0) F.time=ROUND; }
        // Ducks glide along the rail and wrap round; a hit one tips back, then pops up again.
        for(const d of ducks){ d.u=(d.u+dt*0.06)%1; const x=-3+d.u*6;
          if(d.fly){ stepDuck(d,dt,x); continue; }
          d.g.position.set(x,CY+0.27,FZ-0.05); d.g.visible=Math.abs(x)<2.95; }
        for(let i=0;i<balloons.length;i++){ const b=balloons[i]; b.m.position.set(b.x,b.y+Math.sin(time*1.4+i)*0.07,FZ-0.55);
          if(b.popT>0){ b.popT-=dt; b.m.scale.setScalar(b.popT>2?Math.max(0.001,(b.popT-2)*5):b.popT<0.4?Math.max(0.001,1-b.popT/0.4):0.001); if(b.popT<=0) b.m.scale.set(1,1.15,1); } }
        F.swing=Math.max(0,F.swing-dt*0.6); bell.rotation.z=Math.sin(time*14)*0.35*F.swing;
        drawSign();
      },
      get fair(){ return {on:F.on,time:F.time,score:F.score,best:F.best}; },
      get ducks(){ return ducks.map(d=>({flying:!!d.fly,gone:d.fly?.gone!=null,p:d.g.position.toArray()})); },
      knockDuck(i){ const d=ducks[i]; if(d&&!d.fly){ launchDuck(d,V(0.3,0.2,-1),7); return true; } return false; },
    };
  }
const stage=buildFair(),update=stage.update;stage.update=function(dt){xrLang=ctx.xrLang;time=ctx.time;update.call(stage,dt);};return stage;}