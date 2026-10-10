export const CHALLENGES = [
    ['keeper3', 3, 'سجّل على الحارس ٣ مرات', 'Score 3 goals'],
    ['hoop3', 3, '٣ سلات متتابعة', '3 hoops in a row'],
    ['windowMin', 1, 'أصغر شباك', 'Smallest window'],
    ['cansOne', 1, 'كل العلب برمية', 'Clear cans in one throw'],
    ['styles5', 3, 'الستايلات الثلاثة', 'Play all 3 styles'],
    ['summit1', 1, 'قمة الجبل', 'Reach the summit'],
    ['monsters15', 15, 'اهزم ١٥ وحشًا', 'Defeat 15 monsters'],
    ['strike1', 1, 'سترايك', 'Bowl a strike'],
    ['crates5', 5, 'فجّر ٥ صناديق', 'Explode 5 crates'],
    ['skyPop5', 5, 'فجّر ٥ دحاريج في السماء', 'Pop 5 Dahroojs above your head'],
    ['curve3', 3, '٣ أهداف منحنية', '3 curved goals'],
    ['bricks20', 20, 'اكسر ٢٠ طوبة', 'Break 20 bricks'],
    ['wall1', 1, 'حطّم جدارًا', 'Clear a wall'],
    ['fair25', 25, '٢٥ نقطة بالملاهي', '25 in one fair round'],
    ['bell3', 3, 'اضرب الجرس ٣ مرات', 'Ring 3 bells'],
    ['pop20', 20, 'فرقع ٢٠ دحروج', 'Pop 20 Dahroojs'],
    ['balance1', 1, 'أكمل مرحلة توازن', 'Complete a balance round'],
    ['balance5', 5, 'مراحل التوازن الخمس', 'All five balance rounds'],
    ['balanceClean', 1, 'توازن دون سقوط أو إعادة', 'Balance without falling or retrying'],
    ['ricochet1', 1, 'أكمل مرحلة ارتداد', 'Complete a ricochet round'],
    ['ricochet5', 5, 'مراحل الارتداد الخمس', 'All five ricochet rounds'],
    ['ricochetAce', 1, 'ارتداد من أول رمية', 'Ricochet on the first throw'],
    ['maze1', 1, 'أكمل متاهة', 'Complete a maze'],
    ['maze5', 5, 'المتاهات الخمس', 'All five mazes'],
    ['mazeClean', 1, 'اجمع النجوم وأكمل المتاهة دون إعادة', 'Collect the stars and finish without retrying'],
] as const;
export type ChallengeId = typeof CHALLENGES[number][0];
export const UNLOCKS = { party: 1, glasses: 3, cap: 5, flower: 7, crown: 10, headphones: 12, scarf: 14, aviator:'balance5', woodhat:'ricochet5', starGlasses:'maze5', beanie:'mazeClean' } as const;
export function accessoryAvailable(id:string,completed:number,progress:Record<string,number>){
    if(!id)return true;
    const need=UNLOCKS[id as keyof typeof UNLOCKS];
    if(!need)return false;
    if(progress['reward:'+id]===1)return true;
    if(typeof need==='number')return completed>=need;
    const challenge=CHALLENGES.find(c=>c[0]===need);
    return !!challenge&&(progress[challenge[0]]||0)>=challenge[1];
}

/** Retired rings wins retain earned accessories, without marking any maze complete. */
export function preserveRingsRewards(progress:Record<string,number>){
    const retired=[['rings1',1],['rings5',5],['ringsClean',1]] as const;
    const legacy=retired.filter(([id,goal])=>(progress[id]||0)>=goal).length;
    if(!legacy)return;
    const completed=CHALLENGES.filter(([id,goal])=>!id.startsWith('maze')&&(progress[id]||0)>=goal).length+legacy+((progress.free25||0)>=25?1:0);
    for(const [id,need] of Object.entries(UNLOCKS))if(typeof need==='number'&&completed>=need)progress['reward:'+id]=1;
    if((progress.rings5||0)>=5)progress['reward:starGlasses']=1;
    for(const [id] of retired)delete progress[id];
}
