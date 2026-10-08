import { CanvasTexture, Mesh, MeshBasicMaterial, PlaneGeometry, Raycaster, Vector3, Quaternion, BufferGeometry, Float32BufferAttribute, Line, LineBasicMaterial, SRGBColorSpace, createSystem } from '@iwsdk/core';
import type { Intersection } from '@iwsdk/core';
import { contextOf } from '../core/context';
import type { GameContext } from '../core/context';
import { ACCESSORIES, MODES, SHOTS, STYLES, THROWS } from '../core/config';
import { CHALLENGES } from '../progression/challenges';
import { label, MODE_NAMES, STYLE_NAMES, THROW_NAMES, SHOT_NAMES, ACCESSORY_NAMES } from '../localization/strings';
import { pulse } from '../haptics/haptics';
import { recenterWorld } from '../xr/session-system';
type Button = {
    text: string;
    x: number;
    y: number;
    w: number;
    h: number;
    action: () => void;
    locked?: boolean;
};
export class SpatialUI {
    open = false;
    page: 'modes' | 'settings' | 'challenges' | 'accessories' = 'modes';
    private pageIndex = 0;
    private canvas = document.createElement('canvas');
    private pen: CanvasRenderingContext2D;
    private texture: CanvasTexture;
    readonly panel: Mesh;
    private hudCanvas = document.createElement('canvas');
    private hudPen: CanvasRenderingContext2D;
    private hudTexture: CanvasTexture;
    private hud: Mesh;
    private buttons: Button[] = [];
    private hover = -1;
    private dirty = true;
    private timer = 0;
    private lastHud = '';
    private message = '';
    private messageUntil = 0;
    private ray = new Raycaster();
    private hits: Intersection[] = [];
    private p = new Vector3();
    private q = new Quaternion();
    private beam: Line;
    constructor(readonly c: GameContext) {
        this.canvas.width = 1200;
        this.canvas.height = 1000;
        this.pen = this.canvas.getContext('2d')!;
        this.texture = new CanvasTexture(this.canvas);
        this.texture.colorSpace = SRGBColorSpace;
        this.panel = new Mesh(new PlaneGeometry(1.2, 1), new MeshBasicMaterial({ map: this.texture, transparent: true, depthWrite: false, depthTest: false }));
        this.panel.renderOrder = 50;
        this.panel.visible = false;
        c.world.scene.add(this.panel);
        this.hudCanvas.width = 1200;
        this.hudCanvas.height = 210;
        this.hudPen = this.hudCanvas.getContext('2d')!;
        this.hudTexture = new CanvasTexture(this.hudCanvas);
        this.hudTexture.colorSpace = SRGBColorSpace;
        this.hud = new Mesh(new PlaneGeometry(1.8, 0.315), new MeshBasicMaterial({ map: this.hudTexture, transparent: true, depthWrite: false, depthTest: false }));
        this.hud.renderOrder = 40;
        this.hud.visible = false;
        c.world.scene.add(this.hud);
        const geo = new BufferGeometry();
        geo.setAttribute('position', new Float32BufferAttribute(new Float32Array(6), 3));
        this.beam = new Line(geo, new LineBasicMaterial({ color: 0xf1c879, transparent: true, depthWrite: false, depthTest: false }));
        this.beam.renderOrder = 60;
        c.world.scene.add(this.beam);
        c.events.on('notice', notice => { this.message = c.store.data.language === 'ar' ? notice.ar : notice.en; this.messageUntil = performance.now() + 7000; this.dirty = true; });
        c.events.on('mode', () => this.positionHUD());
        c.events.on('score', () => { this.lastHud = ''; });
        c.store.onChange = () => { this.dirty = true; this.lastHud = ''; };
    }
    private t(ar: string, en: string) { return this.c.store.data.language === 'ar' ? ar : en; }
    show(page: typeof this.page = 'modes') { this.open = true; this.page = page; this.pageIndex = 0; this.hover = -1; this.dirty = true; this.p.set(0, 0, -1).applyQuaternion(this.c.input.orientation); this.p.y = 0; this.p.normalize(); this.panel.position.copy(this.c.input.head).addScaledVector(this.p, 1.25); this.panel.position.y = Math.max(0.85, this.c.input.head.y - 0.1); this.panel.lookAt(this.c.input.head); this.panel.visible = true; }
    close() { this.open = false; this.panel.visible = false; this.beam.visible = false; }
    private positionHUD() { this.c.space.point(0, this.c.mode === 'summit' ? 3.85 : 2.75, -3.3, this.hud.position); this.hud.quaternion.copy(this.c.space.rotation); this.hud.scale.setScalar(Math.max(0.4, this.c.space.scale)); }
    private buildButtons() {
        this.buttons.length = 0;
        const c = this.c, d = c.store.data, lang = d.language, add = (text: string, x: number, y: number, w: number, h: number, action: () => void, locked = false) => this.buttons.push({ text, x, y, w, h, action, locked });
        const cycle = <T>(items: readonly T[], value: T) => items[(items.indexOf(value) + 1) % items.length];
        if (this.page === 'modes') {
            MODES.forEach((id, i) => { const col = lang === 'ar' ? 2 - i % 3 : i % 3; add(label(MODE_NAMES[id], lang), 55 + col * 370, 155 + Math.floor(i / 3) * 150, 350, 125, () => { c.modes.activate(id); this.close(); }); });
            add(this.t('الإعدادات', 'Settings'), 55, 625, 350, 90, () => this.show('settings'));
            add(this.t('التحديات', 'Challenges'), 425, 625, 350, 90, () => this.show('challenges'));
            add(this.t('الزينة', 'Accessories'), 795, 625, 350, 90, () => this.show('accessories'));
            add(this.t('إعادة النمط', 'Reset mode'), 55, 740, 350, 90, () => { c.modes.activate(c.mode); this.close(); });
            add(this.t('تغيير موضع AR', 'Reposition AR'), 425, 740, 350, 90, () => { if (c.xr === 'immersive-ar')
                void c.mr.begin(); }, c.xr !== 'immersive-ar');
            add(this.t('الخروج من XR', 'Leave XR'), 795, 740, 350, 90, () => { void c.world.renderer.xr.getSession()?.end(); });
        }
        if (this.page === 'settings') {
            const options: [
                string,
                () => void
            ][] = [
                [`${this.t('الشكل', 'Style')} · ${label(STYLE_NAMES[d.style], lang)}`, () => { d.style = cycle(STYLES, d.style); c.store.noteStyle(); }], [`${this.t('الرمي', 'Throw')} · ${label(THROW_NAMES[d.throwType], lang)}`, () => { d.throwType = cycle(THROWS, d.throwType); }], [`${this.t('الطلقة', 'Shot')} · ${label(SHOT_NAMES[d.shot], lang)}`, () => { d.shot = cycle(SHOTS, d.shot); }], [this.t('اللغة · العربية', 'Language · English'), () => { d.language = lang === 'ar' ? 'en' : 'ar'; }], [`${this.t('الوقت', 'Time')} · ${this.t(({ day: 'نهار', dusk: 'غسق', night: 'ليل', dawn: 'فجر', auto: 'تلقائي' })[d.time], d.time)}`, () => { d.time = cycle(['day', 'dusk', 'night', 'dawn', 'auto'] as const, d.time); }], [`${this.t('الطقس', 'Weather')} · ${this.t(({ clear: 'صافٍ', rain: 'مطر', snow: 'ثلج', auto: 'تلقائي' })[d.weather], d.weather)}`, () => { d.weather = cycle(['clear', 'rain', 'snow', 'auto'] as const, d.weather); }],
                ...(['master', 'music', 'sfx', 'ambience', 'ui'] as const).map((key, i) => [`${this.t(['الصوت العام', 'الموسيقى', 'المؤثرات', 'الطبيعة', 'القوائم'][i], key)} · ${Math.round(d[key] * 100)}%`, () => { d[key] = d[key] >= 0.95 ? 0 : Math.min(1, Math.round((d[key] + 0.25) * 4) / 4); c.audio.levels(); }] as [
                    string,
                    () => void
                ]),
                [this.t('إعادة توجيه العالم · VR', 'Recenter world · VR'), () => recenterWorld(c)],
            ];
            options.slice(this.pageIndex * 6, this.pageIndex * 6 + 6).forEach(([text, action], i) => add(text, 65, 145 + i * 100, 1070, 85, () => { action(); c.store.touch(); this.dirty = true; }));
            add(this.t('المزيد', 'More'), 65, 760, 520, 85, () => { this.pageIndex = 1 - this.pageIndex; this.dirty = true; });
            add(this.t('الأنماط', 'Modes'), 615, 760, 520, 85, () => this.show());
        }
        if (this.page === 'challenges') {
            CHALLENGES.slice(this.pageIndex * 8, this.pageIndex * 8 + 8).forEach(([id, goal, ar, en], i) => add(`${this.t(ar, en)} · ${Math.min(goal, d.challenges[id] || 0)}/${goal}`, 55, 140 + i * 80, 1090, 66, () => { }, true));
            add(this.t('الصفحة التالية', 'Next page'), 55, 800, 535, 80, () => { this.pageIndex = 1 - this.pageIndex; this.dirty = true; });
            add(this.t('الزينة', 'Accessories'), 610, 800, 535, 80, () => this.show('accessories'));
        }
        if (this.page === 'accessories') {
            ACCESSORIES.forEach((id, i) => add(`${c.store.canWear(id) ? d.accessory === id ? '✓ ' : '' : '🔒 '}${label(ACCESSORY_NAMES[id], lang)}`, 65, 145 + i * 100, 1070, 85, () => { d.accessory = id; c.store.touch(); this.dirty = true; }, !c.store.canWear(id)));
            add(this.t('الأنماط', 'Modes'), 65, 780, 1070, 85, () => this.show());
        }
        add(this.t('متابعة اللعب · B', 'Resume · B'), 55, 905, 1090, 66, () => this.close());
    }
    private draw() {
        this.buildButtons();
        const g = this.pen;
        g.fillStyle = '#22242d';
        g.fillRect(0, 0, 1200, 1000);
        g.fillStyle = '#eac98f';
        g.font = '700 62px Dahrooj';
        g.textAlign = 'center';
        g.direction = this.c.store.data.language === 'ar' ? 'rtl' : 'ltr';
        g.fillText(this.t('دحروج', 'DAHROOJ'), 600, 83);
        g.font = '500 23px Dahrooj';
        g.fillStyle = '#c5c4be';
        g.fillText(this.t('أشر باليد اليمنى واضغط الزناد للاختيار', 'Point with the right hand · trigger selects'), 600, 121);
        this.buttons.forEach((b, i) => { g.fillStyle = i === this.hover && !b.locked ? '#72513e' : b.locked ? '#2d303a' : '#393c47'; g.beginPath(); g.roundRect(b.x, b.y, b.w, b.h, 20); g.fill(); g.fillStyle = b.locked ? '#9da4b0' : '#f5eee0'; g.font = `${this.page === 'challenges' ? 29 : 33}px Dahrooj`; g.fillText(b.text, b.x + b.w / 2, b.y + b.h / 2 + 12, b.w - 32); });
        this.texture.needsUpdate = true;
        this.dirty = false;
    }
    update(dt: number) {
        const c = this.c;
        if (!c.xr || !c.focused || !c.tracked) {
            this.panel.visible = this.hud.visible = this.beam.visible = false;
            return;
        }
        if (!c.placing) {
            if (c.input.right.secondaryDown) {
                if (this.open)
                    this.close();
                else
                    this.show();
            }
            if (c.input.left.primaryDown)
                this.show('challenges');
            if (c.input.left.secondaryDown)
                this.show('settings');
        }
        this.panel.visible = this.open;
        this.hud.visible = !this.open;
        this.beam.visible = this.open && c.input.right.tracked;
        if (this.open && c.input.right.tracked) {
            const r = c.input.right;
            this.ray.set(r.ray, r.direction);
            this.hits.length = 0;
            this.panel.updateMatrixWorld();
            this.ray.intersectObject(this.panel, false, this.hits);
            const uv = this.hits[0]?.uv;
            const hover = uv ? this.buttons.findIndex(b => uv.x * 1200 >= b.x && uv.x * 1200 <= b.x + b.w && (1 - uv.y) * 1000 >= b.y && (1 - uv.y) * 1000 <= b.y + b.h) : -1;
            if (hover !== this.hover) {
                this.hover = hover;
                this.dirty = true;
            }
            const attr = this.beam.geometry.getAttribute('position');
            this.p.copy(r.ray).addScaledVector(r.direction, this.hits[0]?.distance || 1.5);
            attr.setXYZ(0, r.ray.x, r.ray.y, r.ray.z);
            attr.setXYZ(1, this.p.x, this.p.y, this.p.z);
            attr.needsUpdate = true;
            this.beam.geometry.computeBoundingSphere();
            if (r.triggerDown && hover >= 0 && !this.buttons[hover].locked) {
                this.buttons[hover].action();
                c.audio.uiSound();
                pulse(r, 0.15, 20);
            }
            if (this.dirty)
                this.draw();
        }
        this.timer += dt;
        if (this.timer >= 0.25) {
            this.timer = 0;
            const mode = c.modes.current;
            const text = c.placing ? this.message : `${label(MODE_NAMES[c.mode], c.store.data.language)}   ${mode?.score || 0}   ${mode?.detail || ''}`;
            const hint = performance.now() < this.messageUntil ? this.message : this.t('Grip: امسك وأفلت للرمي · A: استدعاء · B: الأنماط', 'Grip: hold & release to throw · A: recall · B: modes');
            const full = text + hint;
            if (full !== this.lastHud) {
                this.lastHud = full;
                const g = this.hudPen;
                g.fillStyle = '#252833';
                g.fillRect(0, 0, 1200, 210);
                g.textAlign = 'center';
                g.direction = c.store.data.language === 'ar' ? 'rtl' : 'ltr';
                g.fillStyle = '#f0c787';
                g.font = '48px Dahrooj';
                g.fillText(text, 600, 76, 1150);
                g.fillStyle = '#f2eee5';
                g.font = '28px Dahrooj';
                g.fillText(hint, 600, 139, 1140);
                this.hudTexture.needsUpdate = true;
            }
        }
        if (c.placing) {
            this.p.set(0, -0.22, -1.25).applyQuaternion(c.input.orientation);
            this.hud.position.copy(c.input.head).add(this.p);
            this.hud.lookAt(c.input.head);
            this.hud.scale.setScalar(0.65);
        }
    }
}
export class UISystem extends createSystem({}) {
    update(dt: number) { contextOf(this.world).ui.update(dt); }
}
