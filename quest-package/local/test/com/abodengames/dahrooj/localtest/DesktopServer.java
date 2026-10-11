package com.abodengames.dahrooj.localtest;

import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.CountDownLatch;

/** Verification fixture: serves the exact staged APK payload with the production Java server. */
public final class DesktopServer {
    public static void main(String[] args) throws Exception {
        Path root = Paths.get(args[0]);
        Map<String,Long> inventory = new HashMap<>();
        for (String line : Files.readAllLines(root.resolve("game-index.tsv"))) {
            String[] fields = line.split("\t"); inventory.put(fields[0],Long.parseLong(fields[1]));
        }
        LocalAssetServer server = new LocalAssetServer(new LocalAssetServer.Assets() {
            public InputStream open(String path) throws IOException { return Files.newInputStream(root.resolve("game").resolve(path)); }
            public long size(String path) { return inventory.getOrDefault(path,-1L); }
        },Integer.parseInt(args[1]));
        Runtime.getRuntime().addShutdownHook(new Thread(server::close));
        System.out.println("Serving packaged game on http://127.0.0.1:" + server.port());
        new CountDownLatch(1).await();
    }
}
