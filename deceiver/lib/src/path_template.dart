/// Throws an [ArgumentError] if [url] can't be used as a base URL: it must
/// have a scheme and host, and no query or fragment.
void checkBaseUrl(Uri url, String name) {
  if (!url.hasScheme || url.host.isEmpty || url.hasQuery || url.hasFragment) {
    throw ArgumentError.value(
      url,
      name,
      'Must have a scheme and host, and no query or fragment',
    );
  }
}

/// Whether [url] has the same scheme, host and port as [base], and a path
/// under the path of [base].
bool isUnderBaseUrl(Uri url, Uri base) {
  if (url.scheme != base.scheme ||
      url.host != base.host ||
      url.port != base.port) {
    return false;
  }

  final baseSegments = base.pathSegments.where((s) => s.isNotEmpty).toList();
  final segments = url.pathSegments;
  if (segments.length < baseSegments.length) return false;
  for (var i = 0; i < baseSegments.length; i++) {
    if (segments[i] != baseSegments[i]) return false;
  }
  return true;
}

/// A parsed path template such as `/users/{id}`.
///
/// A `{name}` placeholder matches exactly one non-empty path segment. Every
/// other segment must match literally. Segments are compared after
/// percent-decoding.
class PathTemplate {
  /// Parses [path].
  ///
  /// Throws an [ArgumentError] if [path] contains a query, a fragment or a
  /// placeholder that is not a whole `{name}` segment.
  PathTemplate(String path) : _segments = _parse(path);

  /// For every segment: the placeholder name, or the decoded literal.
  final List<({String value, bool isPlaceholder})> _segments;

  /// Returns the placeholder values if [url] matches, or `null` otherwise.
  ///
  /// Only the path of [url] is compared.
  Map<String, String>? match(Uri url) {
    final segments = url.pathSegments;
    if (segments.length != _segments.length) return null;

    final parameters = <String, String>{};
    for (var i = 0; i < _segments.length; i++) {
      final (:value, :isPlaceholder) = _segments[i];
      final segment = segments[i];
      if (isPlaceholder) {
        if (segment.isEmpty) return null;
        parameters[value] = segment;
      } else if (segment != value) {
        return null;
      }
    }
    return parameters;
  }

  static final _placeholder = RegExp(r'^\{([A-Za-z_][A-Za-z0-9_]*)\}$');

  static List<({String value, bool isPlaceholder})> _parse(String path) {
    if (path.contains('?') || path.contains('#')) {
      throw ArgumentError.value(
        path,
        'path',
        'Only the path is matched. Use on.match() to match on the query',
      );
    }

    final withoutLeadingSlash = path.startsWith('/') ? path.substring(1) : path;
    if (withoutLeadingSlash.isEmpty) return const [];

    return [
      for (final segment in withoutLeadingSlash.split('/'))
        if (_placeholder.firstMatch(segment) case final match?)
          (value: match.group(1)!, isPlaceholder: true)
        else if (segment.contains('{') || segment.contains('}'))
          throw ArgumentError.value(
            path,
            'path',
            'Placeholders must be a whole segment like {id}, got "$segment"',
          )
        else
          (value: _decodeSegment(segment), isPlaceholder: false),
    ];
  }

  /// Decodes [segment] the same way [Uri.pathSegments] does, so it accepts
  /// both `café` and `caf%C3%A9`.
  static String _decodeSegment(String segment) {
    final decoded = Uri(path: '/$segment').pathSegments;
    return decoded.length == 1 ? decoded.single : segment;
  }
}
