/* Aboden Games. Ported with owner authorization 2026-10-08 from quest@c7925b7cd7371b6bb87c44a0743721ad55f177dd. See docs/REFERENCE-REUSE-AR.md. */
export default function create(ctx){
const {T,scene,V,groundLine,groundArc,bar,INK,postMat,netMat,S,BR,hit,pointCollide,ooh,segCollide,miss,success,swish}=ctx;

function buildHoop(){
    const grp=new T.Group(); scene.add(grp);
    const BBZ=-9, BBW=1.8, BBB=2.9, BBT=3.95, RY=3.05, RR=0.48, TUBE=0.035, RZ=BBZ+0.15+RR;
    const rimC=V(0,RY,RZ);
    // court lines
    const base=BBZ-1.2;
    groundLine(grp,-9,base,9,base);
    groundLine(grp,-1.8,base,-1.8,base+5.8); groundLine(grp,1.8,base,1.8,base+5.8); groundLine(grp,-1.8,base+5.8,1.8,base+5.8);
    groundArc(grp,0,base+5.8,1.8,0,Math.PI*2);
    groundArc(grp,0,RZ,6.75,Math.PI*1.08,Math.PI*1.92);
    // pole and arm
    bar(grp,V(0,0,BBZ-0.9),V(0,BBT-0.25,BBZ-0.9),0.09);
    bar(grp,V(0,BBT-0.25,BBZ-0.9),V(0,BBT-0.25,BBZ-0.03),0.06);
    // backboard
    const board=new T.Mesh(new T.BoxGeometry(BBW,BBT-BBB,0.05),new T.MeshStandardMaterial({color:0xf8f3ea,roughness:0.6}));
    board.position.set(0,(BBB+BBT)/2,BBZ-0.025); board.castShadow=true; grp.add(board);
    const frame=new T.LineSegments(new T.EdgesGeometry(board.geometry),new T.LineBasicMaterial({color:INK}));
    frame.position.copy(board.position); grp.add(frame);
    const sq=new T.LineSegments(new T.EdgesGeometry(new T.PlaneGeometry(0.6,0.45)),new T.LineBasicMaterial({color:INK}));
    sq.position.set(0,RY+0.25,BBZ+0.003); grp.add(sq);
    // rim
    const rim=new T.Mesh(new T.TorusGeometry(RR,TUBE,10,48),postMat); rim.rotation.x=Math.PI/2; rim.position.copy(rimC); rim.castShadow=true; grp.add(rim);
    bar(grp,V(0,RY,BBZ),V(0,RY,RZ-RR),0.03);
    // net: three rings of points joined in a diamond pattern
    const N=16, rings=[[RR,0,0],[RR*0.78,-0.26,0.5],[RR*0.56,-0.52,0]];
    const npos=new Float32Array(N*3*3), nidx=[];
    for(let i=0;i<N;i++){ nidx.push(i,N+i, (i+1)%N,N+i, N+i,2*N+i, N+i,2*N+(i+1)%N); }
    const ngeo=new T.BufferGeometry(); ngeo.setAttribute('position',new T.BufferAttribute(npos,3)); ngeo.setIndex(nidx);
    grp.add(new T.LineSegments(ngeo,netMat));
    const net={off:V(0,0,0),vel:V(0,0,0),stretch:0,sv:0};
    function netDraw(){
      for(let r=0;r<3;r++){ const [rad,dy,ph]=rings[r], k=r/2;
        for(let i=0;i<N;i++){ const a=(i+ph)/N*Math.PI*2, j=(r*N+i)*3;
          npos[j]=rimC.x+Math.cos(a)*rad+net.off.x*k;
          npos[j+1]=rimC.y+dy*(1+net.stretch*k)+net.off.y*k;
          npos[j+2]=rimC.z+Math.sin(a)*rad+net.off.z*k; } }
      ngeo.attributes.position.needsUpdate=true;
    }
    netDraw();
    return {
      grp, aimZ:RZ,
      ft:sp=>Math.max(0.75,Math.min(1.5,1.7-sp/2400)),
      behind:P=>P.z<BBZ-0.05,
      collide(){
        const P=S.pos, v=S.vel;
        // backboard front face
        if(Math.abs(P.x)<BBW/2+BR*0.4 && P.y>BBB-BR*0.4 && P.y<BBT+BR*0.4 && P.z-BR<BBZ && P.z>BBZ-0.3){
          P.z=BBZ+BR; if(v.z<0){ hit(V(0,0,1),-v.z,V(P.x,P.y,BBZ)); v.z=-v.z*0.6; v.x*=0.9; S.side.set(0,0,0); }
        }
        // rim: closest point on the ring
        const hx=P.x-rimC.x, hz=P.z-rimC.z, hl=Math.hypot(hx,hz)||1e-6;
        if(pointCollide(V(rimC.x+hx/hl*RR,rimC.y,rimC.z+hz/hl*RR),TUBE,0.55)) ooh();
        // pole
        segCollide(V(0,0,BBZ-0.9),V(0,BBT-0.25,BBZ-0.9),0.09,0.5);
        if(S.shot && S.scoredT<=0 && v.y<0 && P.y<RY-0.7 && S.shotT>0.4) miss();
        // through the hoop from above
        if(S.shot && S.scoredT<=0 && S.prevY>=RY && P.y<RY && Math.hypot(P.x-rimC.x,P.z-rimC.z)<RR){
          success(); swish(); net.vel.set(v.x*0.15,-0.4,v.z*0.15); net.sv+=6;
        }
      },
      update(dt){
        net.vel.addScaledVector(net.off,-70*dt).multiplyScalar(Math.pow(0.02,dt));
        net.off.addScaledVector(net.vel,dt);
        net.sv+=(-net.stretch*80-net.sv*6)*dt; net.stretch+=net.sv*dt;
        netDraw();
      }
    };
  }
const stage=buildHoop(),update=stage.update;stage.update=function(dt){update.call(stage,dt);};return stage;
}
