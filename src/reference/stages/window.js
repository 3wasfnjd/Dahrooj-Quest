/* Aboden Games. Ported with owner authorization 2026-10-08 from quest@c7925b7cd7371b6bb87c44a0743721ad55f177dd. See docs/REFERENCE-REUSE-AR.md. */
export default function create(ctx){
const {T,scene,groundLine,BR,V,bar,postMat,chProgress,S,segCollide,ooh,success,miss}=ctx;

function buildWindow(){
    const grp=new T.Group(); scene.add(grp);
    const WZ=-11, FR=0.05;
    groundLine(grp,-14,WZ,14,WZ);
    const START=1.15, MIN=BR*2*1.2, SHRINK=0.85;
    const W={size:START,x:2.4,y:1.6,frame:null,bars:[],pop:1,won:false,moveT:0};
    function build(){
      if(W.frame){ grp.remove(W.frame); W.frame.traverse(o=>{ if(o.geometry) o.geometry.dispose(); }); }
      W.frame=new T.Group(); grp.add(W.frame);
      const h=W.size/2+FR;
      const c=[V(-h,-h,0),V(h,-h,0),V(h,h,0),V(-h,h,0)];
      for(let i=0;i<4;i++) bar(W.frame,c[i],c[(i+1)%4],FR);
      for(const p of c){ const k=new T.Mesh(new T.SphereGeometry(FR*1.4,12,8),postMat); k.position.copy(p); k.castShadow=true; W.frame.add(k); }
      W.frame.position.set(W.x,W.y,WZ);
      W.pole=bar(W.frame,V(0,-W.y,0),V(0,-h,0),0.035);
      W.bars=[0,1,2,3].map(i=>[c[i],c[(i+1)%4]]);
      W.pop=0;ctx.changed();
    }
    function relocate(){
      W.size=Math.max(MIN,W.size*SHRINK);
      let nx,ny,tries=0;
      do{ nx=(Math.random()*2-1)*3.2; ny=0.9+Math.random()*1.9; tries++; }
      while(Math.hypot(nx-W.x,ny-W.y)<1.6 && tries<20);
      W.x=nx; W.y=ny; build();
      if(W.size<=MIN+1e-6) chProgress('windowMin',1);
    }
    build();
    const wp=V(0,0,0), wq=V(0,0,0);
    return {
      grp, aimZ:WZ,
      ft:sp=>Math.max(0.5,Math.min(1.25,1.35-sp/2600)),
      behind:P=>P.z<WZ-0.05,
      // The window moves on its own a moment after a hit, whichever Dahrooj scored (in the headset the
      // next throw often starts before the scoring ball comes back, so waiting for a respawn left it stuck).
      onRespawn(){ if(W.won&&W.moveT<=0){ W.won=false; relocate(); } },
      collide(){
        const P=S.pos, o=W.frame.position;
        for(const [a,b] of W.bars){ if(segCollide(wp.copy(a).add(o),wq.copy(b).add(o),FR,0.6)) ooh(); }
        segCollide(V(o.x,0,WZ),V(o.x,o.y-W.size/2-FR,WZ),0.035,0.5);
        if(S.shot && S.scoredT<=0 && S.missT<=0 && S.prevZ>=WZ && P.z<WZ){
          const h=W.size/2;
          if(Math.abs(P.x-o.x)<h && Math.abs(P.y-o.y)<h){ if(!W.won){ W.won=true; W.moveT=1.2; } success(); } else miss();
        }
      },
      update(dt){
        if(W.won&&W.moveT>0){ W.moveT-=dt; if(W.moveT<=0){ W.won=false; relocate(); } }
        if(W.pop<1){ W.pop=Math.min(1,W.pop+dt*3.5); const t=W.pop, s=1+Math.sin(t*Math.PI)*0.25*(1-t); W.frame.scale.setScalar(Math.max(0.001,t<1?Math.min(1,t*1.4)*s:1)); }
      }
    };
  }
const stage=buildWindow(),update=stage.update;stage.update=function(dt){update.call(stage,dt);};return stage;
}
