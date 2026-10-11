package com.abodengames.dahrooj.localtest;

import android.app.*;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.os.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.*;

/** Keeps bundled files available while Quest Browser is in front or presenting XR. */
public final class GameService extends Service {
    public static final int PORT = 48189;
    public static final String URL = "http://127.0.0.1:" + PORT + "/";
    public static final String STOP = "com.abodengames.dahrooj.localtest.STOP";
    private static final String CHANNEL = "local-game";
    private final ExecutorService loader = Executors.newSingleThreadExecutor();
    private final LocalBinder binder = new LocalBinder();
    private volatile LocalAssetServer server;
    private volatile String failure;
    private boolean starting, stopping;

    public final class LocalBinder extends Binder { public GameService service() { return GameService.this; } }
    public boolean ready() { return server != null; }
    public String failure() { return failure; }
    @Override public IBinder onBind(Intent intent) { return binder; }

    @Override public void onCreate() {
        super.onCreate();
        NotificationChannel channel = new NotificationChannel(CHANNEL, "ملفات دحروج المحلية", NotificationManager.IMPORTANCE_LOW);
        channel.setDescription("إبقاء اللعبة متاحة أثناء اللعب في متصفح Quest");
        getSystemService(NotificationManager.class).createNotificationChannel(channel);
    }
    @Override public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && STOP.equals(intent.getAction())) {
            stopServing();
            stopForeground(STOP_FOREGROUND_REMOVE);
            stopSelf(); return START_NOT_STICKY;
        }
        Intent home = new Intent(this, MainActivity.class);
        Intent stop = new Intent(this, GameService.class).setAction(STOP);
        int pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE;
        Notification notification = new Notification.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.service_icon)
            .setContentTitle("دحروج قيد التشغيل")
            .setContentText("ملفات اللعبة متاحة داخل النظارة")
            .setContentIntent(PendingIntent.getActivity(this, 0, home, pendingFlags))
            .addAction(new Notification.Action.Builder(null, "إيقاف", PendingIntent.getService(this, 1, stop, pendingFlags)).build())
            .setOngoing(true).setOnlyAlertOnce(true).build();
        if (Build.VERSION.SDK_INT >= 34)
            startForeground(1, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE);
        else startForeground(1, notification);
        synchronized (this) {
            if (!starting && server == null && !stopping) { starting = true; loader.execute(this::load); }
        }
        // No boot receiver or automatic network work. Relaunch the app if the OS stops it.
        return START_NOT_STICKY;
    }
    private void load() {
        try {
            Map<String,Long> inventory = new HashMap<>();
            try (BufferedReader input = new BufferedReader(new InputStreamReader(getAssets().open("game-index.tsv"), StandardCharsets.UTF_8))) {
                String line;
                while ((line = input.readLine()) != null) {
                    String[] fields = line.split("\t", -1);
                    if (fields.length != 3 || fields[0].isEmpty() || inventory.containsKey(fields[0]))
                        throw new IOException("Invalid asset inventory");
                    long size = Long.parseLong(fields[1]);
                    if (size < 0) throw new IOException("Invalid asset size");
                    inventory.put(fields[0], size);
                }
            }
            if (!inventory.containsKey("index.html")) throw new IOException("Missing game entry");
            LocalAssetServer created = new LocalAssetServer(new LocalAssetServer.Assets() {
                public InputStream open(String path) throws IOException { return getAssets().open("game/" + path); }
                public long size(String path) { Long size = inventory.get(path); return size == null ? -1 : size; }
            }, PORT);
            synchronized (this) {
                if (stopping) created.close();
                else server = created;
            }
        } catch (Exception e) {
            failure = "تعذّر تشغيل ملفات اللعبة المحلية. أوقف الخدمة ثم أعد المحاولة. (" + e.getClass().getSimpleName() + ")";
            // Keep the error available to the bound launcher, but don't leave a failed FGS running.
            stopForeground(STOP_FOREGROUND_REMOVE);
            stopSelf();
        } finally { synchronized (this) { starting = false; } }
    }
    private synchronized void stopServing() {
        stopping = true;
        if (server != null) { server.close(); server = null; }
    }
    @Override public void onDestroy() {
        stopServing();
        loader.shutdownNow();
        stopForeground(STOP_FOREGROUND_REMOVE);
        super.onDestroy();
    }
}
