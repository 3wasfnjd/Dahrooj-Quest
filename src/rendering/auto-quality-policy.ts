export const QUALITY_LEVELS=[
 {viewport:1,environment:1},
 {viewport:.9,environment:.8},
 {viewport:.8,environment:.6},
 {viewport:.7,environment:.4},
 {viewport:.6,environment:.25},
] as const;

/** Frame-cadence controller, not a GPU benchmark. Times are XR RAF milliseconds. */
export class AutoQualityPolicy {
 level=0;
 changes:{time:number;level:number;reason:string}[]=[];
 private previous:number|undefined;
 private windowStart=0;
 private frames=0;
 private late=0;
 private total=0;
 private badWindows=0;
 private healthyMs=0;
 private graceUntil=0;
 private lastChange=-Infinity;
 private rate=72;
 get quality(){return QUALITY_LEVELS[this.level];}
 pause(time:number,grace=2000){this.previous=undefined;this.graceUntil=time+grace;this.clearWindow(time);this.badWindows=0;this.healthyMs=0;}
 private clearWindow(time:number){this.windowStart=time;this.frames=this.late=this.total=0;}
 sample(time:number,frameRate?:number){
  const rate=Number.isFinite(frameRate)&&frameRate!>=30&&frameRate!<=144?frameRate!:72;
  if(rate!==this.rate){this.rate=rate;this.pause(time);}
  const previous=this.previous;this.previous=time;
  if(previous===undefined){this.clearWindow(time);return;}
  const delta=time-previous;
  if(!Number.isFinite(delta)||delta<=0||delta>250){this.pause(time);return;}
  if(time<this.graceUntil){this.clearWindow(time);return;}
  const budget=1000/this.rate;
  this.frames++;this.total+=delta;if(delta>budget*1.35)this.late++;
  const duration=time-this.windowStart;
  if(duration<1500||this.frames<20)return;
  const missed=this.late/this.frames,mean=this.total/this.frames;
  const bad=missed>.12||mean>budget*1.18;
  const good=missed<.025&&mean<budget*1.08;
  this.badWindows=bad?this.badWindows+1:0;
  this.healthyMs=good?this.healthyMs+duration:0;
  if(this.badWindows>=2&&this.level<QUALITY_LEVELS.length-1&&time-this.lastChange>=3000){
   this.change(this.level+1,time,'sustained-frame-pressure');
  }else if(this.healthyMs>=20000&&this.level>0&&time-this.lastChange>=20000){
   this.change(this.level-1,time,'sustained-stable-frames');
  }
  this.clearWindow(time);
 }
 private change(level:number,time:number,reason:string){
  this.level=level;this.lastChange=time;this.badWindows=0;this.healthyMs=0;
  this.changes.push({time,level,reason});if(this.changes.length>32)this.changes.shift();
 }
}
