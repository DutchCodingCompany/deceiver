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
