/* Aboden Games reference implementation, owner-authorized complete port 2026-10-08. See COMPLETE-REFERENCE-PORT-AR.md. */
export default function create(ctx){const {T,scene,groundLine,bar,V,S,GRAV,segCollide,pointCollide,ooh,netGrid,BR,swish,success,miss}=ctx;let {time}=ctx;
function buildGoal(){
    const grp=new T.Group(); scene.add(grp);
    const GW=6, GH=2.3, GD=1.8, GZ=-11, PR=0.07;
    groundLine(grp,-14,GZ,14,GZ);
    groundLine(grp,-GW/2-2.2,GZ,-GW/2-2.2,GZ+2.6); groundLine(grp,GW/2+2.2,GZ,GW/2+2.2,GZ+2.6); groundLine(grp,-GW/2-2.2,GZ+2.6,GW/2+2.2,GZ+2.6);
    groundLine(grp,-10,GZ,-10,GZ+9); groundLine(grp,10,GZ,10,GZ+9); groundLine(grp,-10,GZ+9,10,GZ+9);
    bar(grp,V(-GW/2,0,GZ),V(-GW/2,GH+PR,GZ),PR); bar(grp,V(GW/2,0,GZ),V(GW/2,GH+PR,GZ),PR); bar(grp,V(-GW/2-PR,GH,GZ),V(GW/2+PR,GH,GZ),PR);
    const tb=PR*0.45;
    bar(grp,V(-GW/2,GH,GZ),V(-GW/2,GH,GZ-GD),tb); bar(grp,V(GW/2,GH,GZ),V(GW/2,GH,GZ-GD),tb);
    bar(grp,V(-GW/2,0,GZ-GD),V(-GW/2,GH,GZ-GD),tb); bar(grp,V(GW/2,0,GZ-GD),V(GW/2,GH,GZ-GD),tb);
    bar(grp,V(-GW/2,GH,GZ-GD),V(GW/2,GH,GZ-GD),tb);
    bar(grp,V(-GW/2,0.02,GZ),V(-GW/2,0.02,GZ-GD),tb); bar(grp,V(GW/2,0.02,GZ),V(GW/2,0.02,GZ-GD),tb); bar(grp,V(-GW/2,0.02,GZ-GD),V(GW/2,0.02,GZ-GD),tb);
    const solids=[ [V(-GW/2,0,GZ),V(-GW/2,GH,GZ),PR], [V(GW/2,0,GZ),V(GW/2,GH,GZ),PR], [V(-GW/2,GH,GZ),V(GW/2,GH,GZ),PR] ];
    // ---- goalkeeper: a round ink buddy with two floating gloves; sways, reads the shot, dives ----
    const KZ=GZ+0.35, KR=0.42, HR=0.135;
    const kRoot=new T.Group(); grp.add(kRoot);
    const kBody=new T.Group(); kRoot.add(kBody);
    const inkMat=new T.MeshStandardMaterial({color:0xe2603f,roughness:0.5});
    const gloveMat=new T.MeshStandardMaterial({color:0xf3ead9,roughness:0.6});
    const kBall=new T.Mesh(new T.SphereGeometry(KR,36,24),inkMat); kBall.position.y=KR; kBall.castShadow=true; kBody.add(kBall);
    const eyeW=new T.MeshBasicMaterial({color:0xfffaf2}), eyeD=new T.MeshBasicMaterial({color:0x151515});
    const EY=KR*1.12;
    const kEyes=[-1,1].map(sx=>{
      const w=new T.Mesh(new T.SphereGeometry(0.085,16,12),eyeW); w.scale.set(1,1.15,0.45); w.position.set(sx*0.13,EY,KR*0.9); kBody.add(w);
      const p=new T.Mesh(new T.SphereGeometry(0.044,12,8),eyeD); p.scale.set(1,1,0.4); p.position.set(sx*0.13,EY,KR*0.9+0.035); kBody.add(p);
      return {w,p,sx};
    });
    const kHands=[-1,1].map(sx=>{
      const h=new T.Mesh(new T.SphereGeometry(HR,18,12),gloveMat); h.castShadow=true; kRoot.add(h);
      return {h,sx};
    });
    const K={x:0,y:0,vy:0,ang:0,tx:0,tang:0,plan:false,wait:0,recover:0,saved:false};
    function keeperReset(){ Object.assign(K,{x:0,y:0,vy:0,ang:0,tx:0,tang:0,plan:false,wait:0,recover:0,saved:false}); }
    function keeperPlan(){
      const P=S.pos, v=S.vel; if(v.z>=-0.5) return;
      const t=(KZ-P.z)/v.z;
      let px=P.x+v.x*t+0.5*S.side.x*t*t, py=P.y+v.y*t-0.5*GRAV*t*t;
      if(Math.random()<0.07) px=K.x-(px-K.x)*0.6;          // rarely guesses the wrong side
      else px+=(Math.random()-0.5)*0.3;
      K.tx=Math.max(-GW/2+0.35,Math.min(GW/2-0.35,px));
      const dx=K.tx-K.x;
      K.tang=Math.abs(dx)>0.5 ? -Math.sign(dx)*Math.min(1.35,Math.abs(dx)*0.75) : 0;
      K.jump=py>1.15;
      K.wait=0.07+Math.random()*0.06; K.plan=true; K.plans=(K.plans||0)+1;
    }
    function keeperUpdate(dt){
      if(S.shot && !K.plan && S.shotT>0.02) keeperPlan();
      if(!S.shot){ K.tx=S.pos.x*0.55+Math.sin(time*0.9)*0.25; K.tang=0; }   // cuts the angle to the ball
      if(K.wait>0){ K.wait-=dt; if(K.wait<=0 && K.jump && K.y<=0){ K.vy=5.6; } }
      else {
        const sp=K.plan?8:2.4, dx=K.tx-K.x;
        K.x+=Math.sign(dx)*Math.min(Math.abs(dx),sp*dt);
        const da=K.tang-K.ang; K.ang+=Math.sign(da)*Math.min(Math.abs(da),9*dt);
      }
      if(K.y>0||K.vy>0){ K.vy-=GRAV*dt; K.y=Math.max(0,K.y+K.vy*dt); if(K.y===0) K.vy=0; }
      if(K.plan && S.shotT>1.2){ K.tang=0; }
      kRoot.position.set(K.x,K.y+Math.abs(Math.sin(K.ang))*0.25,KZ);
      kRoot.rotation.z=K.ang;
      // squash & stretch while diving or jumping, like the ball does
      const lift=Math.min(1,Math.abs(K.ang)/1.1+(K.y>0.05?0.8:0));
      const st=1+lift*0.32+Math.sin(time*3)*0.015;
      kBody.scale.set(1/Math.sqrt(st),st,1/Math.sqrt(st));
      // gloves: float at the sides when waiting, reach up over the head when diving
      for(const hd of kHands){
        const idle=V(hd.sx*(KR+0.19),KR*1.0+Math.sin(time*2.4+hd.sx)*0.05,0.12);
        const reach=V(hd.sx*0.22,KR*2*st+0.34,0.05);
        hd.h.position.copy(idle).lerp(reach,lift);
      }
      // eyes follow the ball
      const lx=Math.max(-1,Math.min(1,(S.pos.x-K.x)/2)), ly=Math.max(-1,Math.min(1,(S.pos.y-(K.y+KR))/2));
      for(const e of kEyes){ e.p.position.x=e.sx*0.13+lx*0.03; e.p.position.y=EY+ly*0.035; }
    }
    const ku=V(0,0,0), kf=V(0,0,0);
    function keeperCollide(){
      const ang=K.ang, st=kBody.scale.y, rr=KR*kBody.scale.x;
      ku.set(-Math.sin(ang),Math.cos(ang),0);
      kf.set(K.x,K.y+Math.abs(Math.sin(ang))*0.25,KZ);
      let hitK=segCollide(kf.clone().addScaledVector(ku,rr),kf.clone().addScaledVector(ku,KR*2*st-rr),rr,0.45);
      kRoot.updateMatrixWorld(true);
      for(const hd of kHands){ const w=new T.Vector3(); hd.h.getWorldPosition(w); if(pointCollide(w,HR,0.5)) hitK=true; }
      if(hitK && S.shot && !K.saved){ K.saved=true; ooh(); }
    }
    const back=netGrid(grp,31,13,(u,v)=>[-GW/2+u*GW, v*GH, GZ-GD]);
    netGrid(grp,10,13,(u,v)=>[-GW/2, v*GH, GZ-u*GD]);
    netGrid(grp,10,13,(u,v)=>[ GW/2, v*GH, GZ-u*GD]);
    netGrid(grp,31,10,(u,v)=>[-GW/2+u*GW, GH, GZ-v*GD]);
    function netPoke(x,y,amt){
      for(let k=0;k<back.nu*back.nv;k++){
        const bx=back.base[k*3], by=back.base[k*3+1];
        back.vel[k]+=amt*Math.exp(-((bx-x)*(bx-x)+(by-y)*(by-y))/0.5);
      }
    }
    return {
      grp, aimZ:GZ-0.3,
      ft:sp=>Math.max(0.5,Math.min(1.25,1.35-sp/2600)),
      behind:P=>P.z<GZ-0.05,
      onRespawn(){ keeperReset(); },
      // Every new throw gets a fresh save attempt, even before the last ball comes back (headset volleys).
      onThrow(){ K.plan=false; K.saved=false; K.wait=0; },
      keeperState:()=>K,
      collide(){
        const P=S.pos, v=S.vel;
        keeperCollide();
        for(const s of solids) if(segCollide(s[0],s[1],s[2])) ooh();
        const inX=Math.abs(P.x)<GW/2;
        if(inX && P.y<GH && P.z<GZ){
          if(P.z-BR<GZ-GD){ P.z=GZ-GD+BR; if(v.z<0){ netPoke(P.x,P.y,-v.z*1.6); swish(); v.z=-v.z*0.12; v.x*=0.5; v.y*=0.6; } }
          if(Math.abs(P.x)>GW/2-BR){ P.x=Math.sign(P.x)*(GW/2-BR); v.x*=-0.15; }
          if(P.y>GH-BR){ P.y=GH-BR; if(v.y>0) v.y*=-0.15; }
        }
        if(inX && P.y>GH && P.y-BR<GH && P.z<GZ && P.z>GZ-GD){ P.y=GH+BR; if(v.y<0) v.y=-v.y*0.2; v.x*=0.8; v.z*=0.8; }
        if(!inX && Math.abs(P.x)-BR<GW/2 && P.z<GZ && P.z>GZ-GD && P.y<GH){ P.x=Math.sign(P.x)*(GW/2+BR); v.x=-v.x*0.2; }
        if(S.shot && S.scoredT<=0 && S.prevZ>=GZ && P.z<GZ){ if(Math.abs(P.x)<GW/2 && P.y<GH) success(); else miss(); }
      },
      update(dt){
        keeperUpdate(dt);
        const p=back.geo.attributes.position.array, nu=back.nu, nv=back.nv;
        for(let j=0;j<nv;j++) for(let i=0;i<nu;i++){
          const k=j*nu+i;
          if(i===0||i===nu-1||j===0||j===nv-1){back.off[k]=0; back.vel[k]=0; continue;}
          const nb=(back.off[k-1]+back.off[k+1]+back.off[k-nu]+back.off[k+nu])*0.25;
          back.vel[k]+=((nb-back.off[k])*120-back.off[k]*60-back.vel[k]*6)*dt;
        }
        for(let k=0;k<nu*nv;k++){ back.off[k]+=back.vel[k]*dt; p[k*3+2]=back.base[k*3+2]-back.off[k]; }
        back.geo.attributes.position.needsUpdate=true;
      }
    };
  }
const stage=buildGoal(),update=stage.update;stage.update=function(dt){time=ctx.time;update.call(stage,dt);};return stage;}