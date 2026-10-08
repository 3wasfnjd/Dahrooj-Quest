/* Aboden Games. Ported with owner authorization 2026-10-08 from quest@c7925b7cd7371b6bb87c44a0743721ad55f177dd. See docs/REFERENCE-REUSE-AR.md. */
export function stageArt(ctx){const {T,V,UP,scene,S,BR,hit}=ctx;const INK=0x2c2d3d;const lineMat=new T.MeshBasicMaterial({color:INK,transparent:true,opacity:.18}),postMat=new T.MeshStandardMaterial({color:INK,roughness:.7}),netMat=new T.LineBasicMaterial({color:INK,transparent:true,opacity:.3});
function groundLine(grp,x1,z1,x2,z2,w=0.07){
    const len=Math.hypot(x2-x1,z2-z1);
    const m=new T.Mesh(new T.PlaneGeometry(len,w),lineMat);
    m.rotation.x=-Math.PI/2; m.rotation.z=-Math.atan2(z2-z1,x2-x1);
    m.position.set((x1+x2)/2,0.003,(z1+z2)/2); grp.add(m);
  }
function groundArc(grp,cx,cz,r,a0,a1,w=0.07){
    const m=new T.Mesh(new T.RingGeometry(r-w/2,r+w/2,64,1,a0,a1-a0),lineMat);
    m.rotation.x=-Math.PI/2; m.position.set(cx,0.003,cz); grp.add(m);
  }
function bar(grp,a,b,r,mat=postMat){
    const dir=new T.Vector3().subVectors(b,a), len=dir.length();
    const m=new T.Mesh(new T.CylinderGeometry(r,r,len,14),mat);
    m.position.copy(a).addScaledVector(dir,0.5);
    m.quaternion.setFromUnitVectors(UP,dir.normalize());
    m.castShadow=true;m.userData.collider='Cylinder';grp.add(m);return m;
  }
function netGrid(grp,nu,nv,pt){
    const n=nu*nv, posA=new Float32Array(n*3), base=new Float32Array(n*3), idx=[];
    for(let j=0;j<nv;j++) for(let i=0;i<nu;i++){
      const p=pt(i/(nu-1),j/(nv-1)), k=(j*nu+i)*3; base[k]=posA[k]=p[0]; base[k+1]=posA[k+1]=p[1]; base[k+2]=posA[k+2]=p[2];
      if(i<nu-1) idx.push(j*nu+i,j*nu+i+1);
      if(j<nv-1) idx.push(j*nu+i,(j+1)*nu+i);
    }
    const geo=new T.BufferGeometry(); geo.setAttribute('position',new T.BufferAttribute(posA,3)); geo.setIndex(idx);
    grp.add(new T.LineSegments(geo,netMat));
    return {nu,nv,geo,base,off:new Float32Array(n),vel:new Float32Array(n)};
  }
function rbox(w,h,d,r,m){
    const sh=new T.Shape(),x=-w/2+r,y=-h/2+r,iw=w-2*r,ih=h-2*r;
    sh.moveTo(x,-h/2);sh.lineTo(x+iw,-h/2);sh.quadraticCurveTo(w/2,-h/2,w/2,y);sh.lineTo(w/2,y+ih);sh.quadraticCurveTo(w/2,h/2,x+iw,h/2);
    sh.lineTo(x,h/2);sh.quadraticCurveTo(-w/2,h/2,-w/2,y+ih);sh.lineTo(-w/2,y);sh.quadraticCurveTo(-w/2,-h/2,x,-h/2);
    const g=new T.ExtrudeGeometry(sh,{depth:d-2*r,bevelEnabled:true,bevelThickness:r,bevelSize:r*.9,bevelSegments:3,curveSegments:5});
    g.translate(0,0,-(d-2*r)/2);return new T.Mesh(g,m);
  }
function bodyOf(list,obj){ for(let o=obj;o;o=o.parent){ const b=list.find(x=>x.mesh===o); if(b) return b; } return null; }
function shove(b,dir,point,k){ b.v.addScaledVector(dir,k); const r=point.clone().sub(b.x); b.w.add(r.cross(dir).multiplyScalar(k*3)); b.sleep=false;ctx.pushBody(b); }
function segCollide(a,b,r,e=0.7){
    const ab=new T.Vector3().subVectors(b,a);
    const t=Math.max(0,Math.min(1,new T.Vector3().subVectors(S.pos,a).dot(ab)/ab.lengthSq()));
    const cp=a.clone().addScaledVector(ab,t);
    return pointCollide(cp,r,e);
  }
function pointCollide(cp,r,e){
    const n=S.pos.clone().sub(cp), d=n.length();
    if(d>0 && d<BR+r){
      n.divideScalar(d); S.pos.copy(cp).addScaledVector(n,BR+r);
      const vn=S.vel.dot(n);
      if(vn<0){ hit(n,-vn,cp.clone().addScaledVector(n,r)); S.vel.addScaledVector(n,-(1+e)*vn); S.side.set(0,0,0); }
      return true;
    }
    return false;
  }
return {lineMat,postMat,netMat,groundLine,groundArc,bar,netGrid,rbox,bodyOf,shove,segCollide,pointCollide};
}
