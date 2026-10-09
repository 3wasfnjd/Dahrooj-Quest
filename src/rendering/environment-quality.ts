import {BufferGeometry,type Mesh,type Scene} from '@iwsdk/core';

/** Stable, dispersed grass subsets: a lower tier must not cut off half the field. */
export function dispersedTriangleIndices(triangles:number){
 const order=Uint32Array.from({length:triangles},(_,i)=>i);let seed=123456789;
 for(let i=triangles-1;i>0;i--){seed=(Math.imul(seed,1664525)+1013904223)>>>0;const j=seed%(i+1);[order[i],order[j]]=[order[j],order[i]];}
 const indices=new Uint32Array(triangles*3);
 for(let i=0;i<triangles;i++)for(let c=0;c<3;c++)indices[i*3+c]=order[i]*3+c;
 return indices;
}

export function createEnvironmentQuality(){
 const grassCache=new Map<BufferGeometry,BufferGeometry>();
 return {
  draw<T>(scene:Scene,density:number,render:()=>T):T{
   if(density>=1)return render();
   const restore:(()=>void)[]=[];
   try{
    const grass=scene.getObjectByName('xr-grass') as Mesh|undefined;
    if(grass?.isMesh&&grass.visible&&!grass.geometry.index&&grass.geometry.drawRange.start===0){
     const original=grass.geometry;let reduced=grassCache.get(original);
     if(!reduced){reduced=original.clone();reduced.setIndex(Array.from(dispersedTriangleIndices(Math.floor(original.attributes.position.count/3))));grassCache.set(original,reduced);}
     const count=Math.min(original.attributes.position.count,original.drawRange.count);
     reduced.setDrawRange(0,Math.floor(count*density/3)*3);grass.geometry=reduced;restore.push(()=>{grass.geometry=original;});
    }
    const weather=scene.getObjectByName('xr-weather-particles') as Mesh|undefined;
    if(weather?.isMesh&&weather.visible){
     const geometry=weather.geometry,{start,count}=geometry.drawRange;
     const available=Math.max(0,(geometry.index?.count??geometry.attributes.position.count)-start);
     geometry.setDrawRange(start,Math.floor(Math.min(available,count)*density/6)*6);
     restore.push(()=>geometry.setDrawRange(start,count));
    }
    return render();
   }finally{for(const reset of restore)reset();}
  },
  dispose(){for(const geometry of grassCache.values())geometry.dispose();grassCache.clear();}
 };
}
