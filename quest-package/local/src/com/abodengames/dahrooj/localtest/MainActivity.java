package com.abodengames.dahrooj.localtest;

import android.app.Activity;
import android.content.*;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.net.Uri;
import android.os.*;
import android.view.*;
import android.widget.*;

public final class MainActivity extends Activity {
    private final Handler handler = new Handler(Looper.getMainLooper());
    private TextView status;
    private Button play;
    private GameService service;
    private boolean bound, waiting;
    private long deadline;
    private final ServiceConnection connection = new ServiceConnection() {
        @Override public void onServiceConnected(ComponentName name, IBinder binder) {
            service = ((GameService.LocalBinder)binder).service();
        }
        @Override public void onServiceDisconnected(ComponentName name) {
            service = null;
            finishWaiting("توقفت الخدمة. أعد تشغيل اللعبة من هنا.");
        }
    };
    private final Runnable poll = new Runnable() {
        @Override public void run() {
            if (!waiting) return;
            if (service != null && service.failure() != null) { finishWaiting(service.failure()); return; }
            if (service != null && service.ready()) {
                finishWaiting("ملفات اللعبة جاهزة. يجري فتح متصفح Quest…");
                openBrowser(); return;
            }
            if (SystemClock.uptimeMillis() >= deadline) { finishWaiting("لم تبدأ اللعبة بعد. اضغط إيقاف ثم جرّب تشغيلها مجددًا."); return; }
            handler.postDelayed(this, 100);
        }
    };
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().setStatusBarColor(Color.rgb(224, 215, 197));
        getWindow().setNavigationBarColor(Color.rgb(224, 215, 197));
        ScrollView scroll = new ScrollView(this);
        scroll.setBackgroundColor(Color.rgb(240, 235, 222));
        LinearLayout panel = new LinearLayout(this);
        panel.setOrientation(LinearLayout.VERTICAL);
        panel.setGravity(Gravity.CENTER_HORIZONTAL);
        panel.setLayoutDirection(View.LAYOUT_DIRECTION_RTL);
        panel.setPadding(dp(32), dp(30), dp(32), dp(30));
        scroll.addView(panel);
        ImageView icon = new ImageView(this);
        icon.setImageResource(R.drawable.game_icon);
        icon.setContentDescription("دحروج");
        panel.addView(icon, new LinearLayout.LayoutParams(dp(100), dp(100)));
        panel.addView(label("دحروج", 32));
        panel.addView(label("نسخة محلية تجريبية", 17));
        panel.addView(label("ملفات اللعبة مضمّنة في هذا التطبيق.\nتُفتح اللعبة في متصفح Quest للعب VR وMR.\nاترك خدمة دحروج تعمل أثناء اللعب.", 17));
        play = button("تشغيل اللعبة");
        panel.addView(play);
        play.setOnClickListener(v -> startGame());
        Button stop = button("إيقاف خدمة اللعبة");
        panel.addView(stop);
        stop.setOnClickListener(v -> {
            releaseBinding();
            stopService(new Intent(this, GameService.class));
            finishWaiting("تم الإيقاف. يمكنك تشغيل اللعبة مجددًا من الزر أعلاه.");
        });
        status = label("للتجربة: أوقف Wi-Fi قبل أول تشغيل.\nتحقق من VR وMR والحفظ على نظارتك.", 15);
        status.setAccessibilityLiveRegion(View.ACCESSIBILITY_LIVE_REGION_POLITE);
        panel.addView(status);
        panel.addView(label("© 2026 Aboden Games • 0.1 local test", 13));
        setContentView(scroll);
    }
    private TextView label(String text, int size) {
        TextView view = new TextView(this);
        view.setText(text); view.setTextSize(size);
        view.setTextColor(Color.rgb(38, 41, 50)); view.setGravity(Gravity.CENTER);
        view.setPadding(0, dp(8), 0, dp(8));
        return view;
    }
    private Button button(String text) {
        Button button = new Button(this);
        button.setText(text); button.setTextSize(18); button.setAllCaps(false);
        button.setTextColor(Color.WHITE);
        button.setBackgroundTintList(ColorStateList.valueOf(Color.rgb(48, 52, 65)));
        LinearLayout.LayoutParams layout = new LinearLayout.LayoutParams(dp(280), dp(60));
        layout.topMargin = dp(8); button.setLayoutParams(layout);
        return button;
    }
    private int dp(int value) { return Math.round(value * getResources().getDisplayMetrics().density); }
    private void startGame() {
        releaseBinding();
        try {
            getPackageManager().getApplicationInfo("com.oculus.browser", 0);
            Intent intent = new Intent(this, GameService.class);
            startForegroundService(intent);
            bound = bindService(intent, connection, Context.BIND_AUTO_CREATE);
            if (!bound) throw new IllegalStateException("Could not bind game service");
            waiting = true; play.setEnabled(false);
            status.setText("جارٍ تجهيز ملفات اللعبة المحلية…");
            deadline = SystemClock.uptimeMillis() + 15000;
            handler.post(poll);
        } catch (Exception e) {
            finishWaiting("تعذّر البدء. يلزم تثبيت التطبيق على Meta Quest مع متصفح Quest. (" + e.getClass().getSimpleName() + ")");
        }
    }
    private void openBrowser() {
        // Meta's documented system deep link opens Browser without an embedded WebView.
        Intent shell = getPackageManager().getLaunchIntentForPackage("com.oculus.vrshell");
        if (shell != null) {
            shell.putExtra("intent_data", "systemux://browser");
            shell.putExtra("uri", GameService.URL);
            try { startActivity(shell); return; } catch (ActivityNotFoundException | SecurityException ignored) { }
        }
        try {
            startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(GameService.URL)).setPackage("com.oculus.browser"));
        } catch (ActivityNotFoundException | SecurityException e) {
            status.setText("افتح متصفح Quest وأدخل العنوان المحلي:\n" + GameService.URL + "\nاترك خدمة دحروج تعمل.");
        }
    }
    private void finishWaiting(String message) {
        waiting = false; handler.removeCallbacks(poll); play.setEnabled(true); status.setText(message);
    }
    private void releaseBinding() {
        waiting = false; handler.removeCallbacks(poll);
        if (bound) { unbindService(connection); bound = false; }
        service = null;
    }
    @Override public void onDestroy() { releaseBinding(); super.onDestroy(); }
}
