/** Describes the existing Touch-controller bindings in xr-runtime.js. */
type Pair=readonly [ar:string,en:string];
export function questControls(mode:string,throwStyle:string){
 const tilting=mode==='balance'||mode==='maze',tabletop=tilting||mode==='ricochet';
 let leftTrigger:Pair=['إطلاق المقذوف','Fire projectile'];
 let rightTrigger:Pair=['شحن ثم إفلات للرمي','Hold, then release'];
 let grip:Pair=['القبضة: إمساك بديل · اضغط للشحن وأفلت للرمي','Grip also holds Dahrooj · hold to charge, release to throw'];
 let a:Pair=['استرجاع دحروج','Recall Dahrooj'];
 if(throwStyle==='hand'){
  rightTrigger=['إمساك ورمي باليد','Hold, swing, release'];
  grip=['القبضة: امسك دحروج، حرّك يدك وارمِ ثم أفلت','Grip: hold Dahrooj, swing your hand, then release'];
 }else if(throwStyle==='sling'){
  leftTrigger=['غير مستخدم بالنبيطة','Unused with slingshot'];rightTrigger=['سحب ثم إفلات','Pull, then release'];
  grip=['النبيطة باليسرى · اسحب دحروج باليمنى ثم أفلت','Slingshot in the left hand · pull with the right, then release'];
 }
 if(tabletop){
  a=['إعادة المحاولة','Retry round'];
  leftTrigger=rightTrigger=tilting?['إمساك وإمالة اللوح','Hold and tilt board']:['تصويب ثم إفلات','Aim, then release'];
  grip=tilting?['القبضة: امسك اللوح وأمله · الإفلات يوقفه','Grip: hold and tilt the board · release to pause']:['القبضة: وجّه للوح الخشبي وأدره بخطوات ٥°','Grip: point at a wooden paddle and turn it in 5° steps'];
 }else if(mode==='climb'){
  a=['قفز','Jump'];leftTrigger=['قفز','Jump'];rightTrigger=['رمي دحروج','Throw Dahrooj'];
  grip=['القير الأيسر: حركة · القير الأيمن: تكبير وتصغير الجبل','Left stick: move · right stick: resize the mountain'];
 }else if(mode==='rain'){
  leftTrigger=rightTrigger=['إطلاق المقذوف','Fire projectile'];
  grip=['الزناد: اضغط باستمرار لإطلاق المقذوفات','Trigger: hold for repeated shots'];
 }
 return {a,leftTrigger,rightTrigger,grip};
}
