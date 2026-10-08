/* Aboden Games. Ported with owner authorization 2026-10-08 from quest@c7925b7cd7371b6bb87c44a0743721ad55f177dd. See docs/REFERENCE-REUSE-AR.md. */
export default function create(ctx){
const {T,scene,V,S,audio,sfxOut,bodyOf,shove,BR,hit,miss,react,GRAV,UP,addCount,success,toast,xrOnNow,chProgress}=ctx;
let {time,xrLang}=ctx;
function buildBowling(){
    const grp=new T.Group(); scene.add(grp);
    const S_PIN=0.34, PH=2.967*S_PIN, CR=0.15, CH=PH, HEAD=-16, LANE_W=1.9, BACK=-19.4;
    // Lane boards with the aiming arrows, and dark gutters at the sides.
    const laneTex=(()=>{const c=document.createElement('canvas');c.width=128;c.height=1024;const x=c.getContext('2d');
      for(let i=0;i<16;i++){x.fillStyle=i%2?'#d9a066':'#cf955a';x.fillRect(i*8,0,8,1024);}
      x.fillStyle='rgba(120,70,30,.35)';for(let i=0;i<16;i++)x.fillRect(i*8,0,1,1024);
      x.fillStyle='#8a4b2a';for(let i=-2;i<=2;i++){const ax=64+i*20,ay=330+Math.abs(i)*26;x.beginPath();x.moveTo(ax,ay-18);x.lineTo(ax+6,ay);x.lineTo(ax-6,ay);x.fill();}
      for(let i=-3;i<=3;i++){x.beginPath();x.arc(64+i*16,620,3,0,7);x.fill();}
      const t=new T.CanvasTexture(c);t.anisotropy=4;return t;})();
    const laneLen=1-BACK;
    const lane=new T.Mesh(new T.PlaneGeometry(LANE_W,laneLen),new T.MeshStandardMaterial({map:laneTex,roughness:.45,metalness:0}));
    lane.rotation.x=-Math.PI/2; lane.position.set(0,.006,(1+BACK)/2); lane.receiveShadow=true; grp.add(lane);
    for(const s of [-1,1]){
      const gut=new T.Mesh(new T.PlaneGeometry(.22,laneLen),new T.MeshStandardMaterial({color:0x3a3340,roughness:.6}));
      gut.rotation.x=-Math.PI/2; gut.position.set(s*(LANE_W/2+.11),.005,(1+BACK)/2); grp.add(gut);
    }
    // The pit at the back: a dark board that stops the pins and the ball.
    const back=new T.Mesh(new T.BoxGeometry(LANE_W+.44,.7,.12),new T.MeshStandardMaterial({color:0x2c2d3d,roughness:.8}));
    back.position.set(0,.35,BACK-.06); back.castShadow=true; grp.add(back);
    // Pins: Motri's model once it loads, a turned shape until then.
    const prof=[[0,0],[.33,0],[.42,.08],[.5,.3],[.42,.5],[.24,.66],[.22,.74],[.3,.86],[.27,.96],[0,1]].map(([r,y])=>new T.Vector2(r*.511*S_PIN,y*PH));
    let pinGeo=new T.LatheGeometry(prof,20), pinMat=new T.MeshStandardMaterial({color:0xf4efe6,roughness:.35});
    const pins=[];
    // refPinPositions from Motri, head pin first: depth back along the lane and offset across it.
    const REF=[[-10.79,67.77],[-11.94,68.49],[-11.94,67.05],[-13.08,69.21],[-13.08,67.77],[-13.08,66.32],[-14.25,69.94],[-14.25,68.49],[-14.25,67.05],[-14.25,65.6]];
    const spots=REF.map(([x,z])=>[(z-67.77)*S_PIN,HEAD+(x+10.79)*S_PIN]);
    const m=0.6, invI=1/(m*(3*CR*CR+CH*CH)/12);
    for(let i=0;i<10;i++){
      const g=new T.Group(), mesh=new T.Mesh(pinGeo,pinMat); mesh.position.y=-CH/2; mesh.castShadow=true; g.add(mesh); grp.add(g);
      pins.push({mesh:g,body:mesh,x:V(0,0,0),v:V(0,0,0),q:new T.Quaternion(),w:V(0,0,0),invM:1/m,invI,sleep:true,down:false,gone:false});
    }
    ctx.loadPin(gltf=>{
      let src=null; gltf.scene.traverse(o=>{if(o.isMesh&&!src)src=o;}); if(!src) return;
      const geo=src.geometry.clone(); geo.scale(S_PIN,S_PIN,S_PIN);
      const mat=src.material; if(mat.map)mat.map.colorSpace=T.SRGBColorSpace;
      for(const p of pins){ p.body.geometry=geo; p.body.material=mat; }
      pinGeo=geo; pinMat=mat;
    });
    const samples=[];
    for(const y of [-CH/2,-CH/6,CH/6,CH/2]) for(let k=0;k<8;k++){ const a=k/8*Math.PI*2, r=Math.abs(y)>CH/3?CR*.8:CR; samples.push(V(Math.cos(a)*r,y,Math.sin(a)*r)); }
    let roll=0, knocked=0, touched=false, clackT=0, struck=false, thrown=false, autoT=0;
    const isDown=p=>p.gone||V(0,1,0).applyQuaternion(p.q).y<0.5||p.x.y<CH/2-.25;
    function setPins(all){
      pins.forEach((p,i)=>{
        if(!all&&!p.down) return;
        if(!all&&p.down){ p.gone=true; p.mesh.visible=false; p.sleep=true; return; }
        p.x.set(spots[i][0],CH/2+.001,spots[i][1]); p.v.set(0,0,0); p.w.set(0,0,0); p.q.identity(); p.sleep=true; p.down=false; p.gone=false;
        p.mesh.visible=true; p.mesh.position.copy(p.x); p.mesh.quaternion.copy(p.q);
      });
      if(all){ roll=0; knocked=0; }
    }
    setPins(true);
    const ballBody={x:S.pos,v:S.vel,w:V(0,0,0),invM:1/2.5,invI:0};
    const ra=V(0,0,0), rb=V(0,0,0), tv=V(0,0,0), tv2=V(0,0,0), cr=V(0,0,0);
    function velAt(b,r,out){ return out.copy(b.w).cross(r).add(b.v); }
    function applyImp(b,r,dir,j){ b.v.addScaledVector(dir,j*b.invM); if(b.invI) b.w.addScaledVector(cr.copy(r).cross(dir),j*b.invI); }
    function contact(A,B,p,n,depth,e,mu){
      const ia=A.invM, ib=B?B.invM:0, tot=ia+ib; if(tot<=0) return 0;
      const corr=Math.max(0,depth-0.002)*0.8;
      A.x.addScaledVector(n,corr*ia/tot); if(B) B.x.addScaledVector(n,-corr*ib/tot);
      ra.subVectors(p,A.x); if(B) rb.subVectors(p,B.x);
      velAt(A,ra,tv); if(B){ velAt(B,rb,tv2); tv.sub(tv2); }
      const vn=tv.dot(n); if(vn>=0) return 0;
      const ka=cr.copy(ra).cross(n).lengthSq()*A.invI, kb=B?cr.copy(rb).cross(n).lengthSq()*B.invI:0;
      const j=-(1+(vn>-0.6?0:e))*vn/(ia+ib+ka+kb);
      applyImp(A,ra,n,j); if(B) applyImp(B,rb,n,-j);
      tv.addScaledVector(n,-vn); const vt=tv.length();
      if(vt>1e-5){
        const t=tv.divideScalar(vt).clone();
        const kta=cr.copy(ra).cross(t).lengthSq()*A.invI, ktb=B?cr.copy(rb).cross(t).lengthSq()*B.invI:0;
        let jt=-vt/(ia+ib+kta+ktb); jt=Math.max(-mu*j,Math.min(mu*j,jt));
        applyImp(A,ra,t,jt); if(B) applyImp(B,rb,t,-jt);
      }
      return j;
    }
    const inv=new T.Quaternion(), lp=V(0,0,0), wp=V(0,0,0), nrm=V(0,0,0);
    function pointInPin(p,B){
      inv.copy(B.q).invert(); lp.copy(p).sub(B.x).applyQuaternion(inv);
      const rad=Math.hypot(lp.x,lp.z), pr=CR-rad, pa=CH/2-Math.abs(lp.y);
      if(pr<=0||pa<=0) return 0;
      if(pa<pr) nrm.set(0,Math.sign(lp.y)||1,0); else nrm.set(lp.x/(rad||1),0,lp.z/(rad||1));
      nrm.applyQuaternion(B.q); return Math.min(pa,pr);
    }
    // A wooden clack, louder for harder hits (made here, no recorded sounds).
    function clack(s){
      if(!audio||time-clackT<0.04) return; clackT=time;
      const t=audio.currentTime;
      for(const f of [520+Math.random()*120,1180+Math.random()*160]){
        const o=audio.createOscillator(), g=audio.createGain();
        o.type='square'; o.frequency.setValueAtTime(f,t); o.frequency.exponentialRampToValueAtTime(f*.6,t+.08);
        g.gain.setValueAtTime(0.0001,t); g.gain.exponentialRampToValueAtTime(0.012+s*0.05,t+0.003); g.gain.exponentialRampToValueAtTime(0.0001,t+0.09+s*0.06);
        o.connect(g).connect(sfxOut()); o.start(t); o.stop(t+0.2);
      }
    }
    const live=()=>pins.filter(p=>!p.gone);
    return {
      grp, bridge:{bodies:pins,radius:CR,height:CH}, aimZ:-9, farZ:BACK+.5, friction:0.97, shotTime:10,
      shoot(obj,point,dir){ const p=bodyOf(pins,obj); if(!p) return false; for(const q of pins) q.sleep=false; shove(p,dir,point,4); return true; },
      pins:()=>pins.map(p=>({down:p.down,gone:p.gone,x:p.x.x,y:p.x.y,z:p.x.z})),
      frame:()=>({roll,knocked}),
      ft:sp=>Math.max(0.55,Math.min(1.1,1.2-sp/3000)),
      behind:P=>P.z<HEAD-0.4,
      onRespawn(){
        // After the first roll the fallen pins are swept away; after a strike or the second roll, a fresh rack.
        if(!thrown) return;
        thrown=false; roll++;
        if(roll>=2||pins.every(p=>p.down)) setPins(true); else setPins(false);
        touched=false; struck=false;
      },
      touched:()=>touched,
      collide(){
        const P=S.pos, v=S.vel;
        // The back board.
        if(P.z<BACK+BR&&Math.abs(P.x)<LANE_W/2+.3&&P.y<.7+BR){ P.z=BACK+BR; if(v.z<0){ hit(V(0,0,1),-v.z,V(P.x,P.y,BACK)); v.z*=-.25; } }
        if(S.shot) thrown=true;
        if(S.shot && !touched && P.z<HEAD-1.6) miss();
      },
      ballContact(){
        for(const c of live()){
          inv.copy(c.q).invert(); lp.copy(S.pos).sub(c.x).applyQuaternion(inv);
          const rad=Math.hypot(lp.x,lp.z);
          const qx=rad>CR?lp.x/rad*CR:lp.x, qz=rad>CR?lp.z/rad*CR:lp.z, qy=Math.max(-CH/2,Math.min(CH/2,lp.y));
          wp.set(qx,qy,qz).applyQuaternion(c.q).add(c.x);
          const n=V(0,0,0).subVectors(S.pos,wp), d=n.length();
          if(d>1e-5 && d<BR){
            n.divideScalar(d); for(const p of live()) p.sleep=false;
            const before=S.vel.dot(n);
            const j=contact(ballBody,c,wp.clone(),n,BR-d,0.3,0.3);
            if(j>0){ hit(n,Math.max(0,-before)*0.5,wp.clone()); clack(Math.min(1,j/3)); if(!touched && S.shot){ touched=true; react('joy',1.3); } }
          }
        }
      },
      update(dt){
        this.ballContact();
        // Every pin shot down while Dahrooj is still in hand: a moment later, a fresh rack.
        if(!S.shot&&!thrown&&pins.every(p=>p.down||p.gone)){ autoT+=dt; if(autoT>1.6){ autoT=0; roll=0; setPins(true); touched=false; struck=false; } } else autoT=0;
        const L=live(); if(L.every(c=>c.sleep)) return;
        for(const c of L){
          if(c.sleep) continue;
          c.v.y-=GRAV*dt; c.x.addScaledVector(c.v,dt);
          const wq=new T.Quaternion(c.w.x*dt*0.5,c.w.y*dt*0.5,c.w.z*dt*0.5,0).multiply(c.q);
          c.q.set(c.q.x+wq.x,c.q.y+wq.y,c.q.z+wq.z,c.q.w+wq.w).normalize();
          c.v.multiplyScalar(Math.pow(0.8,dt)); c.w.multiplyScalar(Math.pow(0.45,dt));
          if(c.x.z<BACK+CR){ c.x.z=BACK+CR; if(c.v.z<0) c.v.z*=-.2; }
        }
        for(let it=0;it<3;it++){
          for(const A of L){
            if(A.sleep) continue;
            for(const s of samples){
              wp.copy(s).applyQuaternion(A.q).add(A.x);
              if(wp.y<0) contact(A,null,wp.clone(),UP,-wp.y,0.2,0.5);
              for(const B of L){
                if(B===A) continue;
                const dep=pointInPin(wp,B);
                if(dep>0){ B.sleep=false; const j=contact(A,B,wp.clone(),nrm.clone(),dep,0.3,0.3); if(j>.6) clack(Math.min(1,j/4)); }
              }
            }
          }
        }
        for(const c of L){
          c.mesh.position.copy(c.x); c.mesh.quaternion.copy(c.q);
          // Settled pins go back to sleep.
          if(c.v.lengthSq()<.004&&c.w.lengthSq()<.01) c.calm=(c.calm||0)+dt; else c.calm=0;
          if(c.calm>.6) c.sleep=true;
          if(!c.down && isDown(c)){ c.down=true; knocked++; addCount('bowling'); }
        }
        if(!struck && S.shot && pins.every(p=>p.down)){ struck=true; S.scoredT=0; S.missT=0; success(); toast(xrOnNow()&&xrLang==='en'?(roll===0?'Strike!':'Spare!'):(roll===0?'سترايك!':'سبير!')); if(roll===0) chProgress('strike1',1); }
      }
    };
  }
const stage=buildBowling(),update=stage.update;stage.update=function(dt){time=ctx.time;xrLang=ctx.xrLang;update.call(stage,dt);};return stage;
}
