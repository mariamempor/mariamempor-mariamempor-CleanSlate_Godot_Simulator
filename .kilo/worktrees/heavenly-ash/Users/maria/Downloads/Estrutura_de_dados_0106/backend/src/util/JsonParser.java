package helpdesk.util;

import java.util.HashMap;
import java.util.Map;

/**
 * Parser JSON simples para fins educacionais (sem dependências externas).
 */
public class JsonParser {

    public static Map<String, String> parse(String json) {
        Map<String, String> map = new HashMap<>();
        if (json == null || json.trim().isEmpty()) return map;

        json = json.trim();
        if (json.startsWith("{")) json = json.substring(1);
        if (json.endsWith("}")) json = json.substring(0, json.length() - 1);

        int i = 0;
        while (i < json.length()) {
            // Find key
            int keyStart = json.indexOf('"', i);
            if (keyStart == -1) break;
            int keyEnd = json.indexOf('"', keyStart + 1);
            if (keyEnd == -1) break;
            String key = json.substring(keyStart + 1, keyEnd);

            // Find colon
            int colon = json.indexOf(':', keyEnd + 1);
            if (colon == -1) break;

            // Find value
            int valueStart = colon + 1;
            while (valueStart < json.length() && json.charAt(valueStart) == ' ') valueStart++;

            String value;
            int valueEnd;

            if (valueStart < json.length() && json.charAt(valueStart) == '"') {
                // String value
                StringBuilder sb = new StringBuilder();
                int j = valueStart + 1;
                while (j < json.length()) {
                    char c = json.charAt(j);
                    if (c == '\\' && j + 1 < json.length()) {
                        char next = json.charAt(j + 1);
                        if (next == '"') { sb.append('"'); j += 2; }
                        else if (next == '\\') { sb.append('\\'); j += 2; }
                        else if (next == 'n') { sb.append('\n'); j += 2; }
                        else if (next == 'r') { sb.append('\r'); j += 2; }
                        else { sb.append(c); j++; }
                    } else if (c == '"') {
                        break;
                    } else {
                        sb.append(c);
                        j++;
                    }
                }
                value = sb.toString();
                valueEnd = j + 1;
            } else if (valueStart < json.length() && json.charAt(valueStart) == 'n') {
                // null
                value = "";
                valueEnd = valueStart + 4;
            } else {
                // Number or boolean
                valueEnd = valueStart;
                while (valueEnd < json.length() && json.charAt(valueEnd) != ',' && json.charAt(valueEnd) != '}') {
                    valueEnd++;
                }
                value = json.substring(valueStart, valueEnd).trim();
            }

            map.put(key, value);

            // Move past comma
            i = valueEnd;
            while (i < json.length() && (json.charAt(i) == ',' || json.charAt(i) == ' ')) i++;
        }

        return map;
    }

    public static String toJsonArray(String[] items) {
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < items.length; i++) {
            if (i > 0) sb.append(",");
            sb.append(items[i]);
        }
        sb.append("]");
        return sb.toString();
    }
}
