// One cached list texture; scrolling moves UVs, not text or GPU texture uploads.
export function createChallengeList(T,{parent,panelWidth,panelHeight,pixelsWidth,pixelsHeight,font}){
 const view=Object.freeze({x:36,y:192,w:672,h:684,row:72}),px=panelWidth/pixelsWidth,py=panelHeight/pixelsHeight;
 const canvas=document.createElement('canvas');canvas.width=view.w;canvas.height=view.h;
 const tex=new T.CanvasTexture(canvas);tex.colorSpace=T.SRGBColorSpace;tex.generateMipmaps=false;tex.minFilter=T.LinearFilter;tex.magFilter=T.LinearFilter;
 const material=new T.MeshBasicMaterial({map:tex,transparent:true,depthTest:false,depthWrite:false,fog:false,toneMapped:false});
 const mesh=new T.Mesh(new T.PlaneGeometry(view.w*px,view.h*py),material);mesh.name='xr-challenge-list';mesh.renderOrder=21;mesh.position.set((view.x+view.w/2-pixelsWidth/2)*px,(pixelsHeight/2-view.y-view.h/2)*py,.001);parent.add(mesh);
 const thumb=new T.Mesh(new T.PlaneGeometry(6*px,1),new T.MeshBasicMaterial({color:0x686273,transparent:true,depthTest:false,depthWrite:false,fog:false,toneMapped:false}));thumb.name='xr-challenge-scrollbar';thumb.renderOrder=22;parent.add(thumb);
 let offset=0,key='';
 function position(){
  const height=canvas.height,max=Math.max(0,height-view.h);offset=Math.max(0,Math.min(max,offset));tex.repeat.y=view.h/height;tex.offset.y=1-(offset+view.h)/height;
  const h=view.h*view.h/height,top=view.y+(max?offset/max*(view.h-h):0);thumb.scale.y=h*py;thumb.position.set((view.x+view.w+12-pixelsWidth/2)*px,(pixelsHeight/2-top-h/2)*py,.002);
 }
 function rows(items,lang){
  const next=lang+'|'+items.map(x=>x.id+':'+x.value+'/'+x.goal).join('|');if(key===next)return;key=next;
  const height=Math.max(view.h,items.length*view.row);if(canvas.height!==height)canvas.height=height;
  const c=canvas.getContext('2d'),rtl=lang!=='en';c.clearRect(0,0,canvas.width,canvas.height);c.direction=rtl?'rtl':'ltr';
  items.forEach((x,k)=>{
   const y=k*view.row,ok=x.value>=x.goal;c.fillStyle=ok?'#303141':'#fffaf2';c.beginPath();c.roundRect(0,y,view.w,view.row-6,18);c.fill();
   c.fillStyle=ok?'#fffaf2':'#2c2d3d';c.textAlign=rtl?'right':'left';c.font=font(700,32);
   const words=((ok?'✓ ':'')+(rtl?x.title:x.en||x.title)).split(' '),lines=[];let line='';
   for(const word of words){const s=line?line+' '+word:word;if(line&&c.measureText(s).width>view.w-130){lines.push(line);line=word;}else line=s;}if(line)lines.push(line);
   lines.forEach((line,i)=>c.fillText(line,rtl?view.w-20:20,y+view.row/2+9+(i-(lines.length-1)/2)*32));
   c.textAlign=rtl?'left':'right';c.direction='ltr';c.font=font(800,28);c.fillText(`${x.value}/${x.goal}`,rtl?18:view.w-18,y+view.row/2+9);c.direction=rtl?'rtl':'ltr';
  });
  tex.needsUpdate=true;position();
 }
 const scrollTo=value=>{offset=value;position();};
 position();mesh.visible=thumb.visible=false;
 return {view,rows,scrollTo,scrollBy:n=>scrollTo(offset+n),show(on){mesh.visible=thumb.visible=on;},get offset(){return offset;},get max(){return Math.max(0,canvas.height-view.h);},hit(x,y){return x>=view.x&&x<=view.x+view.w&&y>=view.y&&y<=view.y+view.h;}};
}
