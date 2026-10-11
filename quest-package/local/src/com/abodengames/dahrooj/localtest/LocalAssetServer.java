package com.abodengames.dahrooj.localtest;

import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.*;

/** An allowlisted, read-only HTTP server. No proxy, downloads, uploads or directory listings. */
public final class LocalAssetServer implements AutoCloseable {
    public interface Assets {
        InputStream open(String path) throws IOException;
        long size(String path); // -1 means not in the packaged inventory.
    }
    public static final String CSP = "default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; "
        + "style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; media-src 'self' blob:; "
        // GLTFLoader's ImageBitmapLoader fetches embedded GLB images through local blob URLs.
        + "connect-src 'self' data: blob:; worker-src 'self' blob:; font-src 'self'; "
        + "object-src 'none'; base-uri 'self'; frame-ancestors 'none'";
    private final Assets assets;
    private final ServerSocket listener;
    private final ThreadPoolExecutor workers;
    private final Set<Socket> sockets = ConcurrentHashMap.newKeySet();
    private volatile boolean closed;

    public LocalAssetServer(Assets assets, int port) throws IOException {
        this.assets = assets;
        listener = new ServerSocket();
        listener.setReuseAddress(true);
        // Numeric address avoids DNS and never exposes the server to LAN interfaces.
        try { listener.bind(new InetSocketAddress(InetAddress.getByAddress(new byte[]{127,0,0,1}), port), 32); }
        catch (IOException e) { listener.close(); throw e; }
        workers = new ThreadPoolExecutor(2, 6, 30, TimeUnit.SECONDS,
            new ArrayBlockingQueue<Runnable>(32), r -> { Thread t = new Thread(r, "dahrooj-http"); t.setDaemon(true); return t; });
        Thread thread = new Thread(this::accept, "dahrooj-listen");
        thread.setDaemon(true);
        thread.start();
    }
    public int port() { return listener.getLocalPort(); }
    public boolean isLoopbackOnly() { return listener.getInetAddress().isLoopbackAddress(); }
    private void accept() {
        while (!closed) {
            try {
                Socket socket = listener.accept();
                socket.setSoTimeout(8000);
                sockets.add(socket);
                try { workers.execute(() -> serve(socket)); }
                catch (RejectedExecutionException e) { sockets.remove(socket); socket.close(); }
            } catch (IOException e) { if (!closed) close(); }
        }
    }
    private void serve(Socket socket) {
        try (Socket connection = socket;
             InputStream in = new BufferedInputStream(connection.getInputStream());
             OutputStream out = new BufferedOutputStream(connection.getOutputStream())) {
            try { respond(in, out); }
            catch (BadRequest e) { reply(out, e.code, e.reason, null, 0); }
            out.flush();
        } catch (IOException ignored) { /* Closing a tab or stopping the service cancels its request. */ }
        finally { sockets.remove(socket); }
    }
    private static final class BadRequest extends Exception {
        final int code; final String reason;
        BadRequest(int code, String reason) { this.code = code; this.reason = reason; }
    }
    private void respond(InputStream in, OutputStream out) throws IOException, BadRequest {
        ByteArrayOutputStream buffer = new ByteArrayOutputStream();
        int last = 0;
        while (true) {
            int b = in.read();
            if (b < 0) throw new BadRequest(400, "Bad Request");
            buffer.write(b);
            last = (last << 8) | b;
            if (last == 0x0d0a0d0a) break;
            if (buffer.size() >= 16384) throw new BadRequest(431, "Request Header Fields Too Large");
        }
        String[] lines = new String(buffer.toByteArray(), StandardCharsets.US_ASCII).split("\r\n");
        String[] request = lines[0].split(" ", -1);
        if (request.length != 3 || !request[2].matches("HTTP/1\\.[01]")) throw new BadRequest(400, "Bad Request");
        boolean head = "HEAD".equals(request[0]);
        if (!head && !"GET".equals(request[0])) { reply(out,405,"Method Not Allowed","Allow: GET, HEAD\r\n",0); return; }
        Map<String,String> headers = new HashMap<>();
        for (int i = 1; i < lines.length; i++) {
            int colon = lines[i].indexOf(':');
            if (colon <= 0) throw new BadRequest(400, "Bad Request");
            String key = lines[i].substring(0, colon).toLowerCase(Locale.ROOT);
            if (!key.matches("[a-z0-9-]+") || headers.containsKey(key)) throw new BadRequest(400, "Bad Request");
            headers.put(key, lines[i].substring(colon + 1).trim());
        }
        String host = headers.get("host");
        if (!("127.0.0.1:" + port()).equals(host) && !("localhost:" + port()).equals(host))
            throw new BadRequest(403, "Forbidden");
        String path;
        try {
            String raw = request[1].split("\\?", 2)[0];
            if (!raw.startsWith("/") || raw.contains("#")) throw new IllegalArgumentException();
            path = URLDecoder.decode(raw.replace("+", "%2B"), "UTF-8");
            if (path.contains("\\") || path.contains("\0")) throw new IllegalArgumentException();
            for (String part : path.split("/", -1))
                if (part.equals(".") || part.equals("..")) throw new IllegalArgumentException();
        } catch (IllegalArgumentException e) { throw new BadRequest(400, "Bad Request"); }
        path = path.equals("/") ? "index.html" : path.substring(1);
        long size = assets.size(path);
        if (size < 0) throw new BadRequest(404, "Not Found");
        long start = 0, end = size - 1;
        boolean partial = false;
        String range = headers.get("range");
        // HEAD has the same representation length as GET without a Range request.
        if (!head && range != null) {
            try {
                if (!range.matches("bytes=[0-9]*-[0-9]*") || size == 0) throw new IllegalArgumentException();
                String[] parts = range.substring(6).split("-", -1);
                if (parts[0].isEmpty()) {
                    long suffix = Long.parseLong(parts[1]);
                    if (suffix <= 0) throw new IllegalArgumentException();
                    start = Math.max(0, size - suffix);
                } else {
                    start = Long.parseLong(parts[0]);
                    if (!parts[1].isEmpty()) end = Math.min(end, Long.parseLong(parts[1]));
                }
                if (start >= size || start > end) throw new IllegalArgumentException();
                partial = true;
            } catch (IllegalArgumentException e) {
                reply(out,416,"Range Not Satisfiable","Content-Range: bytes */" + size + "\r\n",0); return;
            }
        }
        long count = size == 0 ? 0 : end - start + 1;
        String extra = "Content-Type: " + mime(path) + "\r\nAccept-Ranges: bytes\r\n"
            + (partial ? "Content-Range: bytes " + start + "-" + end + "/" + size + "\r\n" : "");
        // Open before sending a success header, so a missing asset cannot become a false 200.
        try (InputStream asset = assets.open(path)) {
            reply(out, partial ? 206 : 200, partial ? "Partial Content" : "OK", extra, count);
            if (head) return;
            while (start > 0) {
                long skipped = asset.skip(start);
                if (skipped == 0) { if (asset.read() < 0) throw new EOFException(); skipped = 1; }
                start -= skipped;
            }
            byte[] chunk = new byte[32768];
            while (count > 0) {
                int read = asset.read(chunk, 0, (int)Math.min(chunk.length, count));
                if (read < 0) throw new EOFException();
                out.write(chunk, 0, read); count -= read;
            }
        }
    }
    private static void reply(OutputStream out, int code, String reason, String extra, long length) throws IOException {
        String header = "HTTP/1.1 " + code + " " + reason + "\r\nContent-Length: " + length
            + "\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n"
            + "Referrer-Policy: no-referrer\r\nPermissions-Policy: xr-spatial-tracking=(self), camera=(), microphone=(), geolocation=()\r\n"
            + "Content-Security-Policy: " + CSP + "\r\n" + (extra == null ? "" : extra) + "\r\n";
        out.write(header.getBytes(StandardCharsets.US_ASCII));
    }
    public static String mime(String path) {
        String ext = path.substring(path.lastIndexOf('.') + 1).toLowerCase(Locale.ROOT);
        switch (ext) {
            case "html": return "text/html; charset=utf-8";
            case "js": case "mjs": return "text/javascript; charset=utf-8";
            case "css": return "text/css; charset=utf-8";
            case "json": case "webmanifest": return "application/json; charset=utf-8";
            case "wasm": return "application/wasm";
            case "glb": return "model/gltf-binary";
            case "gltf": return "model/gltf+json";
            case "woff2": return "font/woff2";
            case "png": return "image/png";
            case "jpg": case "jpeg": return "image/jpeg";
            case "webp": return "image/webp";
            case "svg": return "image/svg+xml";
            case "ktx2": return "image/ktx2";
            case "ogg": return "audio/ogg";
            case "mp3": return "audio/mpeg";
            case "wav": return "audio/wav";
            case "txt": return "text/plain; charset=utf-8";
            default: return "application/octet-stream";
        }
    }
    @Override public synchronized void close() {
        if (closed) return;
        closed = true;
        try { listener.close(); } catch (IOException ignored) { }
        workers.shutdownNow();
        for (Socket socket : sockets) try { socket.close(); } catch (IOException ignored) { }
        sockets.clear();
    }
}
