// Bridges the Dart-idiomatic camelCase models to the rust backend's snake_case
// JSON wire format. Requests: camelCase -> snake_case. Responses: snake_case ->
// camelCase. Recurses through maps + lists; leaves scalars untouched.

String camelToSnake(String s) {
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c.toUpperCase() == c && c.toLowerCase() != c) {
      if (i > 0) b.write('_');
      b.write(c.toLowerCase());
    } else {
      b.write(c);
    }
  }
  return b.toString();
}

String snakeToCamel(String s) {
  if (!s.contains('_')) return s;
  final parts = s.split('_');
  final b = StringBuffer(parts.first);
  for (final p in parts.skip(1)) {
    if (p.isEmpty) continue;
    b.write(p[0].toUpperCase());
    b.write(p.substring(1));
  }
  return b.toString();
}

dynamic _convert(dynamic value, String Function(String) key) {
  if (value is Map) {
    // Build an explicit Map<String, dynamic> — Map.map() would infer
    // Map<dynamic, dynamic>, which breaks `as Map<String, dynamic>` casts
    // in the generated fromJson code.
    final out = <String, dynamic>{};
    value.forEach((k, v) {
      final nk = k is String ? key(k) : k.toString();
      out[nk] = _convert(v, key);
    });
    return out;
  }
  if (value is List) {
    return value.map((e) => _convert(e, key)).toList();
  }
  return value;
}

/// Request body camelCase -> snake_case. Skips non-JSON bodies (FormData, etc).
dynamic keysToSnake(dynamic body) {
  if (body is Map || body is List) return _convert(body, camelToSnake);
  return body;
}

/// Response body snake_case -> camelCase.
dynamic keysToCamel(dynamic body) {
  if (body is Map || body is List) return _convert(body, snakeToCamel);
  return body;
}
