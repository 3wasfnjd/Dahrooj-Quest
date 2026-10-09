import * as T from '@iwsdk/core';
import type {IUniform} from 'three';
import {referenceShader} from './render-color.js';

type Spot = {x:number;z:number;scale:number};
type Options = {
    root:T.Group; court:{x:number;z:number}; uniforms:Record<string,IUniform>;
    shade:string; track:string; slab:string; pond:string; shadow:string;
    grassColor:T.Color; pondAt:(x:number,z:number)=>number;
    castShadow:(x:number,z:number,height:number,radius:number)=>void;
};

/** Original, opaque park vegetation. Built once, animated in shaders; no leaf textures or tree GLBs. */
export function createProceduralVegetation(o:Options) {
    let seed=19079;
    const random=()=>((seed=seed*16807%2147483647)/2147483647);
    const spots:Spot[]=[], matrix=new T.Matrix4(), pose=new T.Object3D();
    // A sparse ring leaves the court and pond open. A rear row frames the targets.
    for(let i=0;i<30;i++){
        const a=i/30*Math.PI*2+(random()-.5)*.09,r=24+random()*17;
        const x=o.court.x+Math.cos(a)*r,z=o.court.z+Math.sin(a)*r;
        if((Math.abs(x-o.court.x)<13&&z>-29&&z<26)||o.pondAt(x,z)>-.4)continue;
        spots.push({x,z,scale:.85+random()*.4});
    }
    for(let i=0;i<12;i++)spots.push({x:o.court.x-24+i*4.4+(random()-.5)*1.5,z:-34-random()*10,scale:.85+random()*.4});
    const vertex=`
      uniform float uTime,uSway;varying vec4 vClip;varying float vDist;varying vec3 vNormal,vColor;
      void main(){
        mat4 m=modelMatrix*instanceMatrix;mat3 n=mat3(m);
        vNormal=normalize(n*(normal/vec3(dot(n[0],n[0]),dot(n[1],n[1]),dot(n[2],n[2]))));
        vColor=instanceColor;vec4 p=m*vec4(position,1.);
        p.x+=sin(uTime*.8+m[3].x*.18+m[3].z*.11)*uSway;
        vec4 mv=viewMatrix*p;vDist=-mv.z;gl_Position=projectionMatrix*mv;vClip=gl_Position;
      }`;
    const material=(sway:number)=>referenceShader(T,{uniforms:{...o.uniforms,uSway:{value:sway}},vertexShader:vertex,
        fragmentShader:o.shade+'varying vec3 vNormal,vColor;void main(){gl_FragColor=vec4(motriShade(vColor,normalize(vNormal),0.),1.);}',
        transparent:false,depthWrite:true});
    const trunks=new T.InstancedMesh(new T.CylinderGeometry(.15,.24,1,6),material(0),spots.length*3);
    const crowns=new T.InstancedMesh(new T.IcosahedronGeometry(1,1),material(.055),spots.length*3+36);
    trunks.name='xr-procedural-trunks';crowns.name='xr-procedural-crowns';
    const colors=[0x73a847,0x8cba51,0x4e9662,0xe3b455,0xe48b87].map(c=>new T.Color(c));
    const bark=new T.Color(0x866047);let crownCount=0,branchCount=0,bushes=0;
    const put=(mesh:T.InstancedMesh,index:number,x:number,y:number,z:number,sx:number,sy:number,sz:number,color:T.Color,tilt=0)=>{
        pose.position.set(x,y,z);pose.rotation.set(0,random()*Math.PI*2,tilt);pose.scale.set(sx,sy,sz);pose.updateMatrix();
        matrix.copy(pose.matrix);mesh.setMatrixAt(index,matrix);mesh.setColorAt(index,color);
    };
    for(let i=0;i<spots.length;i++){
        const {x,z,scale:s}=spots[i],height=(3.2+random()*.9)*s,color=colors[i%colors.length];
        put(trunks,branchCount++,x,height*.45,z,s,height*.9,s,bark);
        for(const side of [-1,1])put(trunks,branchCount++,x+side*.4*s,height*.7,z,.6*s,height*.55,.6*s,bark,side*.55);
        put(crowns,crownCount++,x,height+.6*s,z,1.35*s,1.6*s,1.2*s,color);
        put(crowns,crownCount++,x-.85*s,height-.05*s,z+.15*s,1.1*s,1.15*s,1.05*s,color);
        put(crowns,crownCount++,x+.8*s,height+.05*s,z-.15*s,1.05*s,1.25*s,1.1*s,color);
        o.castShadow(x,z,height,1.8*s);
    }
    for(let i=0;i<36;i++){
        const a=random()*Math.PI*2,r=17+random()*14,x=o.court.x+Math.cos(a)*r,z=o.court.z+Math.sin(a)*r;
        if((Math.abs(x-o.court.x)<12&&z>-29&&z<25)||o.pondAt(x,z)>-.25)continue;
        const s=.65+random()*.5;put(crowns,crownCount++,x,.55*s,z,1.25*s,.8*s,s,colors[i%3]);bushes++;
        o.castShadow(x,z,.7*s,1.2*s);
    }
    crowns.count=crownCount;trunks.count=branchCount;
    for(const mesh of [trunks,crowns]){
        mesh.instanceMatrix.needsUpdate=true;mesh.instanceColor!.needsUpdate=true;
        mesh.computeBoundingSphere();mesh.boundingSphere!.radius+=.1;o.root.add(mesh);
    }

    // Three solid triangles per tuft, in sixteen cullable patches. No camera-facing blades or alpha masks.
    const positions:number[]=[],tips:number[]=[];
    for(let b=0;b<3;b++){
        const angle=b*Math.PI*2/3,dx=Math.cos(angle)*.2,dz=Math.sin(angle)*.2;
        positions.push(-dx,0,-dz,.04,.48+b*.04,.02,dx,0,dz);tips.push(0,1,0);
    }
    const geometry=new T.BufferGeometry();geometry.setAttribute('position',new T.Float32BufferAttribute(positions,3));geometry.setAttribute('tip',new T.Float32BufferAttribute(tips,1));
    const grassMaterial=referenceShader(T,{uniforms:{...o.uniforms,uColor:{value:o.grassColor}},side:T.DoubleSide,transparent:false,depthWrite:true,
        vertexShader:'uniform sampler2D uPerlin;'+o.track+o.slab+o.pond+o.shadow+`
          uniform vec3 uCam;uniform float uTime;attribute float tip;
          varying vec4 vClip;varying float vDist,vTip,vShade;
          void main(){
            vec3 base=(modelMatrix*instanceMatrix*vec4(0.,0.,0.,1.)).xyz;
            float fade=1.-smoothstep(10.,22.,length(base.xz-uCam.xz));
            float slab=slabAt(base.xz),pond=pondAt(base.xz);
            if(fade<=0.||slab>.7||pond>-.08){gl_Position=vec4(2.,2.,2.,1.);return;}
            vec3 p=position;p.y*=fade*(1.-trackAt(base.xz)*.85)*(1.-smoothstep(.35,.7,slab));
            vec4 world=modelMatrix*instanceMatrix*vec4(p,1.);
            world.x+=sin(uTime*1.4+base.x*.7+base.z*.4)*.065*tip*fade;
            vTip=tip;vShade=shadowAt(base.xz);vec4 mv=viewMatrix*world;
            vDist=-mv.z;gl_Position=projectionMatrix*mv;vClip=gl_Position;
          }`,
        fragmentShader:o.shade+'uniform vec3 uColor;varying float vTip,vShade;void main(){vec3 c=uColor*mix(.86,1.1,vTip);gl_FragColor=vec4(motriShade(c,vec3(0.,1.,0.),max((1.-vTip)*.35,vShade*.85)),1.);}'});
    const grassGroup=new T.Group();grassGroup.name='xr-vegetation-grass';o.root.add(grassGroup);
    let tufts=0;
    for(let tx=0;tx<4;tx++)for(let tz=0;tz<4;tz++){
        const matrices:T.Matrix4[]=[];
        for(let ix=0;ix<16;ix++)for(let iz=0;iz<16;iz++){
            const x=o.court.x-30+tx*15+(ix+.15+random()*.7)*15/16;
            const z=o.court.z-30+tz*15+(iz+.15+random()*.7)*15/16;
            if(o.pondAt(x,z)>-.2)continue;
            pose.position.set(x,.005,z);pose.rotation.set(0,random()*Math.PI*2,0);pose.scale.setScalar(.8+random()*.4);pose.updateMatrix();matrices.push(pose.matrix.clone());
        }
        if(!matrices.length)continue;
        const patch=new T.InstancedMesh(geometry,grassMaterial,matrices.length);
        patch.name=tufts?'xr-grass-patch':'xr-grass';matrices.forEach((m,i)=>patch.setMatrixAt(i,m));
        patch.instanceMatrix.needsUpdate=true;patch.computeBoundingSphere();patch.boundingSphere!.radius+=.1;grassGroup.add(patch);tufts+=matrices.length;
    }
    return {spots,stats:{trees:spots.length,bushes,grassTufts:tufts,grassTriangles:tufts*3,treeTriangles:branchCount*24+crownCount*80,grassPatches:grassGroup.children.length,treeDrawCalls:2}};
}
