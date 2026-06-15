package com.swiftmc.bootstrap;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Resolves and downloads the files needed to run a Minecraft: Java Edition
 * version: the client jar, libraries, and assets. Pure JVM code with no third
 * party dependencies, so it runs unchanged inside the bundled iOS Zero JVM.
 *
 * iOS specifics:
 *  - Native libraries (LWJGL "natives-*" classifiers, anything with an OS rule)
 *    are SKIPPED. iSwiftMC supplies its own iOS natives + GLFW/GL shim; Mojang's
 *    desktop natives are useless here.
 *  - Everything else (pure-Java libraries, assets, client jar) is identical.
 *
 * Usage:  GameInstaller &lt;versionId&gt; &lt;gameDir&gt; [--dry-run]
 * Mojang manifest is fetched live; nothing is bundled.
 */
public final class GameInstaller {

    private static final String MANIFEST =
        "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json";
    private static final String RESOURCES = "https://resources.download.minecraft.net/";

    private final HttpClient http = HttpClient.newBuilder()
        .followRedirects(HttpClient.Redirect.NORMAL).build();
    private final Path gameDir;
    private final boolean dryRun;

    GameInstaller(Path gameDir, boolean dryRun) {
        this.gameDir = gameDir;
        this.dryRun = dryRun;
    }

    public static void main(String[] args) throws Exception {
        if (args.length < 2) {
            System.err.println("usage: GameInstaller <versionId> <gameDir> [--dry-run]");
            System.exit(2);
        }
        String version = args[0];
        Path gameDir = Path.of(args[1]);
        boolean dry = args.length > 2 && args[2].equals("--dry-run");
        new GameInstaller(gameDir, dry).install(version);
    }

    void install(String versionId) throws Exception {
        log("Fetching version manifest...");
        Map<String, Object> manifest = obj(Json.parse(getString(MANIFEST)));

        String versionUrl = findVersionUrl(manifest, versionId);
        if (versionUrl == null) throw new IOException("version not found: " + versionId);

        log("Resolving " + versionId + " ...");
        String versionJsonText = getString(versionUrl);
        Map<String, Object> v = obj(Json.parse(versionJsonText));

        // Persist the version json (Minecraft + our launcher both read it).
        Path versionDir = gameDir.resolve("versions").resolve(versionId);
        writeFile(versionDir.resolve(versionId + ".json"), versionJsonText.getBytes("UTF-8"));

        Plan plan = new Plan();

        // 1) client jar
        Map<String, Object> clientDl = obj(get(obj(get(v, "downloads")), "client"));
        plan.add(versionDir.resolve(versionId + ".jar"),
                 str(clientDl, "url"), str(clientDl, "sha1"), num(clientDl, "size"));

        // 2) libraries (skip native/OS-ruled ones)
        int skipped = 0;
        for (Object lo : arr(get(v, "libraries"))) {
            Map<String, Object> lib = obj(lo);
            if (!allowedOnIOS(lib)) { skipped++; continue; }
            Object downloads = get(lib, "downloads");
            if (downloads == null) continue;
            Object artifact = get(obj(downloads), "artifact");
            if (artifact == null) continue; // classifier-only (natives) -> skip
            Map<String, Object> a = obj(artifact);
            Path dest = gameDir.resolve("libraries").resolve(str(a, "path"));
            plan.add(dest, str(a, "url"), str(a, "sha1"), num(a, "size"));
        }
        log("Libraries: " + (plan.size() - 1) + " queued, " + skipped + " skipped (natives/OS-specific)");

        // 3) assets
        Map<String, Object> assetIndex = obj(get(v, "assetIndex"));
        String assetsId = str(assetIndex, "id");
        String indexText = getString(str(assetIndex, "url"));
        writeFile(gameDir.resolve("assets/indexes").resolve(assetsId + ".json"),
                  indexText.getBytes("UTF-8"));
        Map<String, Object> index = obj(Json.parse(indexText));
        Map<String, Object> objects = obj(get(index, "objects"));
        for (Map.Entry<String, Object> e : objects.entrySet()) {
            Map<String, Object> o = obj(e.getValue());
            String hash = str(o, "hash");
            String sub = hash.substring(0, 2);
            Path dest = gameDir.resolve("assets/objects").resolve(sub).resolve(hash);
            plan.add(dest, RESOURCES + sub + "/" + hash, hash, num(o, "size"));
        }
        log("Assets: " + objects.size() + " objects");

        log(String.format(Locale.ROOT, "TOTAL: %d files, %.1f MiB",
                          plan.size(), plan.bytes / (1024.0 * 1024.0)));

        if (dryRun) { log("--dry-run: resolved only, no large downloads performed."); return; }

        int done = 0;
        for (Download d : plan.items) {
            download(d);
            if (++done % 50 == 0) log("  downloaded " + done + "/" + plan.size());
        }
        log("Install complete: " + gameDir.toAbsolutePath());
    }

    /** Mojang library rules: include when the (possibly absent) rules resolve to allow for a non-OS host. */
    private boolean allowedOnIOS(Map<String, Object> lib) {
        Object rules = get(lib, "rules");
        if (rules == null) return true;
        boolean allow = false;
        for (Object ro : arr(rules)) {
            Map<String, Object> r = obj(ro);
            Object os = get(r, "os");
            boolean applies = (os == null); // no os clause -> applies to everyone
            String action = str(r, "action");
            if (applies) allow = "allow".equals(action);
            // os-specific clauses are desktop (windows/osx/linux); none match iOS,
            // so they never flip the decision here.
        }
        return allow;
    }

    private String findVersionUrl(Map<String, Object> manifest, String id) {
        for (Object o : arr(get(manifest, "versions"))) {
            Map<String, Object> ver = obj(o);
            if (id.equals(str(ver, "id"))) return str(ver, "url");
        }
        return null;
    }

    // --- download with sha1 verification + skip-if-present ---
    private void download(Download d) throws Exception {
        if (Files.exists(d.dest) && d.sha1 != null && sha1(d.dest).equalsIgnoreCase(d.sha1)) {
            return; // already have a good copy
        }
        Files.createDirectories(d.dest.getParent());
        HttpResponse<byte[]> resp = http.send(
            HttpRequest.newBuilder(URI.create(d.url)).GET().build(),
            HttpResponse.BodyHandlers.ofByteArray());
        if (resp.statusCode() != 200) throw new IOException("HTTP " + resp.statusCode() + " for " + d.url);
        byte[] body = resp.body();
        if (d.sha1 != null) {
            String got = sha1(body);
            if (!got.equalsIgnoreCase(d.sha1))
                throw new IOException("sha1 mismatch for " + d.url + " (got " + got + ")");
        }
        Files.write(d.dest, body);
    }

    private String getString(String url) throws Exception {
        HttpResponse<String> r = http.send(
            HttpRequest.newBuilder(URI.create(url)).GET().build(),
            HttpResponse.BodyHandlers.ofString());
        if (r.statusCode() != 200) throw new IOException("HTTP " + r.statusCode() + " for " + url);
        return r.body();
    }

    private void writeFile(Path p, byte[] data) throws IOException {
        Files.createDirectories(p.getParent());
        Files.write(p, data);
    }

    private static String sha1(byte[] data) throws Exception {
        MessageDigest md = MessageDigest.getInstance("SHA-1");
        return hex(md.digest(data));
    }
    private static String sha1(Path p) throws Exception { return sha1(Files.readAllBytes(p)); }
    private static String hex(byte[] b) {
        StringBuilder sb = new StringBuilder(b.length * 2);
        for (byte x : b) sb.append(Character.forDigit((x >> 4) & 0xf, 16))
                           .append(Character.forDigit(x & 0xf, 16));
        return sb.toString();
    }

    private static void log(String m) { System.out.println("[installer] " + m); }

    // --- typed JSON helpers ---
    @SuppressWarnings("unchecked")
    private static Map<String, Object> obj(Object o) { return (Map<String, Object>) o; }
    @SuppressWarnings("unchecked")
    private static List<Object> arr(Object o) { return (List<Object>) o; }
    private static Object get(Map<String, Object> m, String k) { return m == null ? null : m.get(k); }
    private static String str(Map<String, Object> m, String k) { Object o = get(m, k); return o == null ? null : o.toString(); }
    private static long num(Map<String, Object> m, String k) { Object o = get(m, k); return o == null ? 0L : ((Number) o).longValue(); }

    // --- plan structs ---
    private static final class Download {
        final Path dest; final String url, sha1; final long size;
        Download(Path d, String u, String s, long z) { dest = d; url = u; sha1 = s; size = z; }
    }
    private static final class Plan {
        final List<Download> items = new ArrayList<>();
        long bytes;
        void add(Path d, String url, String sha1, long size) {
            if (url == null) return;
            items.add(new Download(d, url, sha1, size));
            bytes += size;
        }
        int size() { return items.size(); }
    }
}
