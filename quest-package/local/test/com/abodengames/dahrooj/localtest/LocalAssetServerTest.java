package com.abodengames.dahrooj.localtest;

import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;

/** Runs the actual server with TCP requests, independently of Android or a browser cache. */
public final class LocalAssetServerTest {
    private static int assertions;
    private static void check(boolean value, String reason) {
        if (!value) throw new AssertionError(reason);
        assertions++;
    }
    private static final class Response {
        final String header; final byte[] body;
        Response(byte[] bytes) {
            String all = new String(bytes, StandardCharsets.ISO_8859_1);
            int split = all.indexOf("\r\n\r\n");
            if (split < 0) throw new AssertionError("Incomplete response");
            header = all.substring(0, split); body = Arrays.copyOfRange(bytes, split + 4, bytes.length);
        }
        boolean status(int code) { return header.startsWith("HTTP/1.1 " + code + " "); }
    }
    private static Response request(int port, String method, String path, String headers) throws Exception {
        try (Socket socket = new Socket(InetAddress.getByAddress(new byte[]{127,0,0,1}), port)) {
            socket.setSoTimeout(5000);
            String host = headers.startsWith("Host:") ? "" : "Host: 127.0.0.1:" + port + "\r\n";
            socket.getOutputStream().write((method + " " + path + " HTTP/1.1\r\n" + host + headers + "\r\n").getBytes(StandardCharsets.US_ASCII));
            return new Response(socket.getInputStream().readAllBytes());
        }
    }
    public static void main(String[] args) throws Exception {
        Map<String,byte[]> files = new HashMap<>();
        files.put("index.html", "<h1>دحروج</h1>".getBytes(StandardCharsets.UTF_8));
        files.put("game.wasm", new byte[]{0,97,115,109});
        files.put("a+b.js", "export default 1".getBytes(StandardCharsets.UTF_8));
        files.put("music.ogg", "0123456789".getBytes(StandardCharsets.UTF_8));
        LocalAssetServer.Assets assets = new LocalAssetServer.Assets() {
            public InputStream open(String path) { return new ByteArrayInputStream(files.get(path)); }
            public long size(String path) { return files.containsKey(path) ? files.get(path).length : -1; }
        };
        int stoppedPort;
        try (LocalAssetServer server = new LocalAssetServer(assets, 0)) {
            int port = server.port(); stoppedPort = port;
            check(server.isLoopbackOnly(), "Must not listen on LAN interfaces");
            Response root = request(port,"GET","/?xrdiag=1","");
            check(root.status(200) && Arrays.equals(root.body,files.get("index.html")), "Root bytes, UTF-8 and diagnostic query");
            check(root.header.contains("Content-Length: " + root.body.length), "Content length is byte length");
            check(root.header.contains("Content-Security-Policy: " + LocalAssetServer.CSP), "Offline CSP");
            check(root.header.contains("xr-spatial-tracking=(self)"), "WebXR policy");
            check(!root.header.contains("Access-Control-Allow-Origin"), "No cross-origin exposure");
            check(request(port,"HEAD","/music.ogg","").body.length == 0, "HEAD has no body");
            check(request(port,"HEAD","/music.ogg","Range: bytes=3-4\r\n").header.contains("Content-Length: 10"), "HEAD representation length");
            check(request(port,"GET","/game.wasm","").header.contains("application/wasm"), "Streaming WASM MIME");
            check(request(port,"GET","/a+b.js","").status(200), "Literal plus in filename");
            check(request(port,"GET","/missing.js","").status(404), "Missing asset must not return HTML");
            for (String path : new String[]{"/../index.html","/%2e%2e/index.html","/x/./index.html","/%5cindex.html","/a%00","/%GG","http://evil.invalid/"})
                check(request(port,"GET",path,"").status(400), "Reject traversal or malformed path: " + path);
            check(request(port,"POST","/","").status(405), "Read-only methods");
            check(request(port,"GET","/","Host: evil.invalid\r\n").status(403), "DNS rebinding host rejected");
            check(request(port,"GET","/","Host: 127.0.0.1:"+port+"\r\nHost: localhost:"+port+"\r\n").status(400), "Duplicate host rejected");
            check(request(port,"GET","/","X-Test: " + "x".repeat(17000) + "\r\n").status(431), "Header memory bounded");
            Response range = request(port,"GET","/music.ogg","Range: bytes=2-4\r\n");
            check(range.status(206) && Arrays.equals(range.body,new byte[]{50,51,52}) && range.header.contains("bytes 2-4/10"), "Media range bytes");
            check(new String(request(port,"GET","/music.ogg","Range: bytes=-2\r\n").body,StandardCharsets.US_ASCII).equals("89"), "Suffix range");
            check(request(port,"GET","/music.ogg","Range: bytes=7-\r\n").body.length==3, "Open-ended range");
            for (String bad : new String[]{"bytes=99-","bytes=5-2","bytes=-0","bytes=1-2,4-5","bytes=9999999999999999999999-"})
                check(request(port,"GET","/music.ogg","Range: " + bad + "\r\n").status(416), "Invalid range: " + bad);
            ExecutorService clients = Executors.newFixedThreadPool(6);
            try {
                List<Future<Boolean>> pending = new ArrayList<>();
                for (int i=0;i<18;i++) pending.add(clients.submit(() -> request(port,"GET","/game.wasm","").status(200)));
                for (Future<Boolean> response : pending) check(response.get(), "Concurrent asset load");
            } finally { clients.shutdownNow(); }
        }
        try (Socket ignored = new Socket("127.0.0.1",stoppedPort)) { throw new AssertionError("Server still listening after close"); }
        catch (ConnectException expected) { assertions++; }
        // A stopped service must release the stable origin port for the next app launch.
        try (LocalAssetServer restarted = new LocalAssetServer(assets,stoppedPort)) {
            check(request(restarted.port(),"GET","/","").status(200), "Restart reuses the save origin");
        }
        System.out.println("PASS: " + assertions + " local-server assertions (JVM, not Quest hardware)");
    }
}
