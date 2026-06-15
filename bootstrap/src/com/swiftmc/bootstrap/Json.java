package com.swiftmc.bootstrap;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Tiny dependency-free JSON parser. Enough for Mojang's manifests (objects,
 * arrays, strings, numbers, booleans, null). Kept minimal on purpose so the
 * bootstrap JAR has zero third-party libraries.
 *
 * Objects -> Map<String,Object>, Arrays -> List<Object>, numbers -> Long/Double.
 */
public final class Json {
    private final String s;
    private int i;

    private Json(String s) { this.s = s; }

    public static Object parse(String text) {
        Json p = new Json(text);
        p.ws();
        Object v = p.value();
        p.ws();
        if (p.i != p.s.length()) throw p.err("trailing characters");
        return v;
    }

    private Object value() {
        char c = peek();
        switch (c) {
            case '{': return object();
            case '[': return array();
            case '"': return string();
            case 't': case 'f': return bool();
            case 'n': expect("null"); return null;
            default:  return number();
        }
    }

    private Map<String, Object> object() {
        Map<String, Object> m = new LinkedHashMap<>();
        expect('{'); ws();
        if (peek() == '}') { i++; return m; }
        while (true) {
            ws();
            String k = string(); ws();
            expect(':'); ws();
            m.put(k, value()); ws();
            char c = next();
            if (c == '}') return m;
            if (c != ',') throw err("expected , or } in object");
        }
    }

    private List<Object> array() {
        List<Object> a = new ArrayList<>();
        expect('['); ws();
        if (peek() == ']') { i++; return a; }
        while (true) {
            ws();
            a.add(value()); ws();
            char c = next();
            if (c == ']') return a;
            if (c != ',') throw err("expected , or ] in array");
        }
    }

    private String string() {
        expect('"');
        StringBuilder b = new StringBuilder();
        while (true) {
            char c = next();
            if (c == '"') return b.toString();
            if (c == '\\') {
                char e = next();
                switch (e) {
                    case '"':  b.append('"'); break;
                    case '\\': b.append('\\'); break;
                    case '/':  b.append('/'); break;
                    case 'b':  b.append('\b'); break;
                    case 'f':  b.append('\f'); break;
                    case 'n':  b.append('\n'); break;
                    case 'r':  b.append('\r'); break;
                    case 't':  b.append('\t'); break;
                    case 'u':
                        b.append((char) Integer.parseInt(s.substring(i, i + 4), 16));
                        i += 4; break;
                    default: throw err("bad escape \\" + e);
                }
            } else {
                b.append(c);
            }
        }
    }

    private Object number() {
        int start = i;
        boolean dbl = false;
        while (i < s.length()) {
            char c = s.charAt(i);
            if (c == '-' || c == '+' || (c >= '0' && c <= '9')) { i++; }
            else if (c == '.' || c == 'e' || c == 'E') { dbl = true; i++; }
            else break;
        }
        String num = s.substring(start, i);
        if (num.isEmpty()) throw err("expected number");
        return dbl ? (Object) Double.parseDouble(num) : (Object) Long.parseLong(num);
    }

    private Boolean bool() {
        if (peek() == 't') { expect("true"); return Boolean.TRUE; }
        expect("false"); return Boolean.FALSE;
    }

    // --- low level ---
    private char peek() { if (i >= s.length()) throw err("unexpected end"); return s.charAt(i); }
    private char next() { if (i >= s.length()) throw err("unexpected end"); return s.charAt(i++); }
    private void expect(char c) { if (next() != c) throw err("expected '" + c + "'"); }
    private void expect(String w) {
        if (!s.startsWith(w, i)) throw err("expected '" + w + "'");
        i += w.length();
    }
    private void ws() { while (i < s.length() && Character.isWhitespace(s.charAt(i))) i++; }
    private RuntimeException err(String m) { return new RuntimeException("JSON @" + i + ": " + m); }
}
