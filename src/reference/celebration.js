/* Aboden Games reference implementation, owner-authorized complete port 2026-10-08. See COMPLETE-REFERENCE-PORT-AR.md. */
export function createReferenceConfetti({T,scene,camera,V,BR}){return (()=>{
    const COUNT=180, POOL=4, AMP=0.7, REST=1-AMP, DUR=3.5;
    const geo=new T.PlaneGeometry(0.05,0.1);
    const mat=new T.MeshLambertMaterial({side:T.DoubleSide});
    const cols=['#4b4e56','#8a8e97','#2c2d3d','#e8857a'].map(c=>new T.Color(c));   // ball blues, ink, blush
    const pool=[], m4=new T.Matrix4(), pv=V(0,0,0), sv=V(1,1,1), eul=new T.Euler();
    for(let k=0;k<POOL;k++){
      const mesh=new T.InstancedMesh(geo,mat,COUNT);
      mesh.castShadow=true; mesh.visible=false; mesh.frustumCulled=false;
      const rp=new Float32Array(COUNT), ang=new Float32Array(COUNT), qs=[];
      for(let i=0;i<COUNT;i++){
        rp[i]=Math.random(); ang[i]=Math.random()*Math.PI*2;
        qs.push(new T.Quaternion().setFromEuler(eul.set(Math.random()*6.283,Math.random()*6.283,Math.random()*6.283)));
        mesh.setColorAt(i,cols[i%cols.length]);
      }
      scene.add(mesh);
      pool.push({mesh,rp,ang,qs,t:0,active:false,radius:4,elev:6});
    }
    function pop(position,radius=4,elevation=6,scale=1){
      const c=pool.find(c=>!c.active); if(!c) return null;
      c.active=true; c.t=0; c.radius=radius; c.elev=elevation;
      c.mesh.position.copy(position); c.mesh.scale.setScalar(scale); c.mesh.visible=true;
      return c;
    }
    function update(dt){
      for(const c of pool){
        if(!c.active) continue;
        c.t+=dt;
        const lin=Math.min(1,c.t/DUR), p=1-(1-lin)*(1-lin);          // gsap default ease (power1.out)
        for(let i=0;i<COUNT;i++){
          const start=REST*c.rp[i], end=start+AMP;
          let pr=Math.max(0,Math.min(1,(p-start)/(end-start)));
          pr=1-Math.pow(1-pr,3);
          const sc=Math.min(1,(1-Math.abs(pr-0.5)*2)*20);
          const strength=(c.rp[i]*99)%1;
          pv.set(Math.sin(c.ang[i])*pr*strength*c.radius,
                 (1-Math.pow(1-pr*2,2))*strength*c.elev,
                 Math.cos(c.ang[i])*pr*strength*c.radius);
          sv.setScalar(Math.max(0.0001,sc));
          m4.compose(pv,c.qs[i],sv); c.mesh.setMatrixAt(i,m4);
        }
        c.mesh.instanceMatrix.needsUpdate=true;
        if(lin>=1){ c.active=false; c.mesh.visible=false; }
      }
    }
    // one burst where the ball landed; scaled with distance so it reads the same size on screen
    function celebrate(at){
      const p=V(at.x,Math.max(0,at.y-BR),at.z);
      const k=Math.max(1,p.distanceTo(camera.position)/7);
      pop(p,1.6,1.5,k);
    }
    return {pop,update,celebrate};
  })();}
export const challenges=[
  {id:'free25',   title:'٢٥ ارتداد',                    en:'25 bounces', goal:25},
  {id:'keeper3',  title:'سجّل على الحارس ٣ مرات',       en:'Score past the keeper 3 times', goal:3},
  {id:'hoop3',    title:'٣ سلات ورا بعض',              en:'3 hoops in a row', goal:3},
  {id:'windowMin',title:'صغّر الشباك لأصغر حجم', en:'Shrink the window to its smallest', goal:1},
  {id:'cansOne',  title:'طيّح كل العلب برمية وحدة',   en:'Knock down every can in one throw', goal:1},
  {id:'styles5',  title:'العب بكل الستايلات الخمسة',          en:'Play in all five styles', goal:5},
  {id:'summit1',  title:'اوصل قمة الجبل',                 en:'Reach the top of the Summit', goal:1},
  {id:'monsters15',title:'اهزم ١٥ وحش في مرحلة القمة',     en:'Beat 15 monsters on the Summit', goal:15},
  {id:'strike1',  title:'سترايك في البولينغ',               en:'A strike in bowling', goal:1},
  {id:'crates5',  title:'فجّر ٥ صناديق في عالم النظارة',     en:'Blow up 5 crates in the headset world', goal:5},
  {id:'skyPop5',  title:'فجّر ٥ دحاريج في السماء', en:'Pop 5 Dahroojs above your head', goal:5},
  {id:'curve3',   title:'سجّل ٣ أهداف برمية ملتفة في النظارة', en:'Score 3 curved goals in the headset', goal:3},
  {id:'bricks20', title:'اكسر ٢٠ طوبة في حائط الطوب', en:'Break 20 bricks on the brick wall', goal:20},
  {id:'wall1',    title:'حطّم حائط الطوب كامل', en:'Smash the whole brick wall', goal:1},
  {id:'fair25',   title:'اجمع ٢٥ نقطة في جولة ملاهي', en:'Score 25 in one round at the fair', goal:25},
  {id:'bell3',    title:'اضرب جرس الملاهي ٣ مرات', en:'Ring the fair bell 3 times', goal:3},
  {id:'pop20',    title:'فجّر ٢٠ دحروج بالطلقات',     en:'Pop 20 Dahroojs with your shots', goal:20},
];