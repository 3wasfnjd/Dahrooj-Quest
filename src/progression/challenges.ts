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
] as const;
export type ChallengeId = typeof CHALLENGES[number][0];
export const UNLOCKS = { party: 1, glasses: 3, cap: 5, flower: 7, crown: 10, headphones: 12, scarf: 14 } as const;
