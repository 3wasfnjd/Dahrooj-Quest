/* Aboden Games reference implementation, owner-authorized complete port 2026-10-08. See COMPLETE-REFERENCE-PORT-AR.md. */
export default function create(ctx){const {T,scene,INK,bar,V,S,audio,sfxOut,bodyOf,shove,miss,pointCollide,BR,hit,react,GRAV,UP,addCount,chProgress,success}=ctx;let {time}=ctx;
function buildCans(){
    const grp=new T.Group(); scene.add(grp);
    const TY=0.9, TW=2.2, TD=0.9, TZ=-20, CR=0.22, CH=0.5;
    // table
    const top=new T.Mesh(new T.BoxGeometry(TW,0.06,TD),new T.MeshStandardMaterial({color:0xcfae86,roughness:0.85}));
    top.position.set(0,TY-0.03,TZ); top.castShadow=true; top.receiveShadow=true; grp.add(top);
    const tf=new T.LineSegments(new T.EdgesGeometry(top.geometry),new T.LineBasicMaterial({color:INK,transparent:true,opacity:0.6}));
    tf.position.copy(top.position); grp.add(tf);
    for(const sx of [-1,1]) for(const sz of [-1,1]) bar(grp,V(sx*(TW/2-0.1),0,TZ+sz*(TD/2-0.1)),V(sx*(TW/2-0.1),TY-0.06,TZ+sz*(TD/2-0.1)),0.035);
    // cans
    const canGeo=new T.CylinderGeometry(CR,CR,CH,28);
    const labelGeo=new T.CylinderGeometry(CR*1.01,CR*1.01,CH*0.56,28,1,true);
    const rimGeo=new T.TorusGeometry(CR*0.97,0.012,6,28);
    const tinMat=new T.MeshStandardMaterial({color:0xc9c4bb,metalness:0.35,roughness:0.35});
    const labelMats=[new T.MeshStandardMaterial({color:0xe2603f,roughness:0.6}),new T.MeshStandardMaterial({color:0x2c2d3d,roughness:0.6})];
    const rimMat=new T.MeshBasicMaterial({color:INK});
    const m=1, invI=1/(m*(3*CR*CR+CH*CH)/12);
    const cans=[];
    for(let i=0;i<6;i++){
      const g=new T.Group();
      const body=new T.Mesh(canGeo,tinMat); body.castShadow=true; g.add(body);
      const lab=new T.Mesh(labelGeo,labelMats[i%2]); lab.castShadow=false; g.add(lab);
      for(const s of [-1,1]){ const r=new T.Mesh(rimGeo,rimMat); r.rotation.x=Math.PI/2; r.position.y=s*CH/2; g.add(r); }
      grp.add(g);
      cans.push({mesh:g,x:V(0,0,0),v:V(0,0,0),q:new T.Quaternion(),w:V(0,0,0),invM:1/m,invI,sleep:true});
    }
    const samples=[];
    for(const s of [-1,1]) for(let k=0;k<8;k++){ const a=k/8*Math.PI*2; samples.push(V(Math.cos(a)*CR,s*CH/2,Math.sin(a)*CR)); }
    let cleared=false, clangT=0, touched=false, fullShot=false, autoT=0;
    function resetCans(){
      const g=0.006, sp=2*CR+g;
      const layout=[[-sp,0],[0,0],[sp,0],[-sp/2,1],[sp/2,1],[0,2]];
      layout.forEach(([x,row],i)=>{ const c=cans[i];
        c.x.set(x,TY+CH/2+row*(CH+0.003)+0.001,TZ); c.v.set(0,0,0); c.w.set(0,0,0); c.q.identity(); c.sleep=true; c.down=false;
        c.mesh.position.copy(c.x); c.mesh.quaternion.copy(c.q); });
      cleared=false;
    }
    resetCans();
    const ballBody={x:S.pos,v:S.vel,w:V(0,0,0),invM:1/2.5,invI:0};
    const ra=V(0,0,0), rb=V(0,0,0), tv=V(0,0,0), tv2=V(0,0,0), cr=V(0,0,0);
    function velAt(b,r,out){ return out.copy(b.w).cross(r).add(b.v); }
    function contact(A,B,p,n,depth,e,mu){
      const ia=A.invM, ib=B?B.invM:0, tot=ia+ib; if(tot<=0) return 0;
      const corr=Math.max(0,depth-0.002)*0.8;
      A.x.addScaledVector(n,corr*ia/tot); if(B) B.x.addScaledVector(n,-corr*ib/tot);
      ra.subVectors(p,A.x); if(B) rb.subVectors(p,B.x);
      velAt(A,ra,tv); if(B){ velAt(B,rb,tv2); tv.sub(tv2); }
      const vn=tv.dot(n); if(vn>=0) return 0;
      const ka=cr.copy(ra).cross(n).lengthSq()*A.invI, kb=B?cr.copy(rb).cross(n).lengthSq()*B.invI:0;
      const ee=vn>-0.6?0:e;
      const j=-(1+ee)*vn/(ia+ib+ka+kb);
      applyImp(A,ra,n,j); if(B) applyImp(B,rb,n,-j);
      // friction
      tv.addScaledVector(n,-vn); const vt=tv.length();
      if(vt>1e-5){
        const t=tv.divideScalar(vt).clone();
        const kta=cr.copy(ra).cross(t).lengthSq()*A.invI, ktb=B?cr.copy(rb).cross(t).lengthSq()*B.invI:0;
        let jt=-vt/(ia+ib+kta+ktb); jt=Math.max(-mu*j,Math.min(mu*j,jt));
        applyImp(A,ra,t,jt); if(B) applyImp(B,rb,t,-jt);
      }
      return j;
    }
    function applyImp(b,r,dir,j){ b.v.addScaledVector(dir,j*b.invM); if(b.invI) b.w.addScaledVector(cr.copy(r).cross(dir),j*b.invI); }
    const inv=new T.Quaternion(), lp=V(0,0,0), wp=V(0,0,0), nrm=V(0,0,0);
    // point against a can's cylinder; returns depth and sets nrm (world, pointing out of the can)
    function pointInCan(p,B){
      inv.copy(B.q).invert(); lp.copy(p).sub(B.x).applyQuaternion(inv);
      const rad=Math.hypot(lp.x,lp.z), pr=CR-rad, pa=CH/2-Math.abs(lp.y);
      if(pr<=0||pa<=0) return 0;
      if(pa<pr) nrm.set(0,Math.sign(lp.y)||1,0); else nrm.set(lp.x/(rad||1),0,lp.z/(rad||1));
      nrm.applyQuaternion(B.q); return Math.min(pa,pr);
    }
    function wakeAll(){ for(const c of cans) c.sleep=false; }
    function clang(s){
      if(!audio||time-clangT<0.05) return; clangT=time;
      const t=audio.currentTime;
      for(const f of [880+Math.random()*200,1420+Math.random()*200,2350]){
        const o=audio.createOscillator(), g=audio.createGain();
        o.type='triangle'; o.frequency.value=f;
        g.gain.setValueAtTime(0.0001,t); g.gain.exponentialRampToValueAtTime(0.02+s*0.07,t+0.004); g.gain.exponentialRampToValueAtTime(0.0001,t+0.25+s*0.2);
        o.connect(g).connect(sfxOut()); o.start(t); o.stop(t+0.5);
      }
    }
    const onTable=c=>c.x.y>TY-0.05 && Math.abs(c.x.x)<TW/2 && Math.abs(c.x.z-TZ)<TD/2;
    return {
      grp, aimZ:TZ,
      shoot(obj,point,dir){ const c=bodyOf(cans,obj); if(!c) return false; wakeAll(); shove(c,dir,point,4.5); clang(0.7); return true; },
      ft:sp=>Math.max(0.8,Math.min(1.6,1.75-sp/2400)),
      behind:P=>P.z<TZ-0.7,
      onRespawn(){ if(cleared) resetCans(); touched=false; fullShot=false; },
      touched:()=>touched,
      collide(){
        if(S.shot && !touched && S.pos.z<TZ-1) miss();
        // ball vs the table block
        const P=S.pos;
        const cx=Math.max(-TW/2,Math.min(TW/2,P.x)), cy=Math.max(0,Math.min(TY,P.y)), cz=Math.max(TZ-TD/2,Math.min(TZ+TD/2,P.z));
        pointCollide(V(cx,cy,cz),0,0.4);
      },
      // ball vs cans (wakes the pile); also used for extra balls in a headset volley
      ballContact(){
        for(const c of cans){
          inv.copy(c.q).invert(); lp.copy(S.pos).sub(c.x).applyQuaternion(inv);
          const rad=Math.hypot(lp.x,lp.z);
          const qx=rad>CR?lp.x/rad*CR:lp.x, qz=rad>CR?lp.z/rad*CR:lp.z, qy=Math.max(-CH/2,Math.min(CH/2,lp.y));
          wp.set(qx,qy,qz).applyQuaternion(c.q).add(c.x);
          const n=V(0,0,0).subVectors(S.pos,wp), d=n.length();
          if(d>1e-5 && d<BR){
            n.divideScalar(d); wakeAll();
            const before=S.vel.dot(n);
            const j=contact(ballBody,c,wp.clone(),n,BR-d,0.35,0.3);
            if(j>0){ hit(n,Math.max(0,-before)*0.7,wp.clone()); clang(Math.min(1,j/4)); if(!touched && S.shot){ touched=true; fullShot=cans.every(onTable); react('joy',1.3); } }
          }
        }
      },
      update(dt){
        this.ballContact();
        // Knocked off by the headset's blaster while Dahrooj is still in hand: a moment later, a fresh stack.
        if(cleared&&!S.shot){ autoT+=dt; if(autoT>1.6){ autoT=0; resetCans(); } } else autoT=0;
        if(cans.every(c=>c.sleep)) return;
        for(const c of cans){
          if(c.sleep) continue;
          c.v.y-=GRAV*dt; c.x.addScaledVector(c.v,dt);
          const wq=new T.Quaternion(c.w.x*dt*0.5,c.w.y*dt*0.5,c.w.z*dt*0.5,0).multiply(c.q);
          c.q.set(c.q.x+wq.x,c.q.y+wq.y,c.q.z+wq.z,c.q.w+wq.w).normalize();
          c.v.multiplyScalar(Math.pow(0.85,dt)); c.w.multiplyScalar(Math.pow(0.5,dt));
        }
        for(let it=0;it<3;it++){
          for(const A of cans){
            if(A.sleep) continue;
            for(const s of samples){
              wp.copy(s).applyQuaternion(A.q).add(A.x);
              if(wp.y<0) contact(A,null,wp.clone(),UP,-wp.y,0.25,0.6);
              else if(wp.y<TY && wp.y>TY-0.12 && Math.abs(wp.x)<TW/2 && Math.abs(wp.z-TZ)<TD/2 && A.x.y>TY) contact(A,null,wp.clone(),UP,TY-wp.y,0.25,0.6);
              for(const B of cans){
                if(B===A) continue;
                const dep=pointInCan(wp,B);
                if(dep>0){ const j=contact(A,B,wp.clone(),nrm.clone(),dep,0.25,0.4); if(j>1.2) clang(Math.min(1,j/6)); }
              }
            }
          }
        }
        for(const c of cans){ c.mesh.position.copy(c.x); c.mesh.quaternion.copy(c.q); if(!c.down && !onTable(c)){ c.down=true; addCount('cans'); } }
        if(!cleared && cans.every(c=>!onTable(c))){ cleared=true; if(S.shot && fullShot) chProgress('cansOne',1); if(S.shot){ S.scoredT=0; S.missT=0; success(); } }
      }
    };
  }
const stage=buildCans(),update=stage.update;stage.update=function(dt){time=ctx.time;update.call(stage,dt);};return stage;}