// The APK always contains the game. No first-visit download, updater or remote cache is needed.
// Remove only old Dahrooj caches at this loopback origin; keep the player's localStorage/IndexedDB.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', event => event.waitUntil((async () => {
  for (const key of await caches.keys()) if (key.startsWith('dahrooj-')) await caches.delete(key);
  await self.clients.claim();
})()));
// Intentionally no fetch handler: all files come from the APK's local service on every launch.
