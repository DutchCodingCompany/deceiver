import 'dart:convert';

import 'deceiver_data.dart';

/// What a [DeceiverResponseInfo] describes.
enum DeceiverResponseKind {
  /// Made with `jsonResponse()`.
  json,

  /// Made with `errorResponse()`.
  error,

  /// Made with `emptyResponse()`.
  empty,

  /// Made with `sequentialResponse()`, see [DeceiverResponseInfo.variants].
  sequential,

  /// Made with `randomResponse()`, see [DeceiverResponseInfo.variants].
  random,

  /// A response builder of your own. Its response is only known when it runs.
  custom,
}

/// What a mock responds, as far as known when it is registered. See
/// [DeceiverData.responseInfo].
///
/// The response helpers (`jsonResponse()`, `errorResponse()`, etc.) describe
/// their response. Response builders of your own are
/// [DeceiverResponseKind.custom].
class DeceiverResponseInfo {
  const DeceiverResponseInfo({
    required this.kind,
    this.statusCode,
    this.headers = const {},
    this.body,
    this.variants = const [],
  });

  /// The info of a response builder of your own.
  static const custom = DeceiverResponseInfo(kind: DeceiverResponseKind.custom);

  /// What kind of response builder this is.
  final DeceiverResponseKind kind;

  /// The status code, or `null` for [DeceiverResponseKind.sequential],
  /// [DeceiverResponseKind.random] and [DeceiverResponseKind.custom].
  final int? statusCode;

  /// The response headers.
  final Map<String, String> headers;

  /// The response body, or `null` if it is empty or unknown.
  final String? body;

  /// The responses of a [DeceiverResponseKind.sequential] or
  /// [DeceiverResponseKind.random] builder, in order.
  final List<DeceiverResponseInfo> variants;

  /// A one-line summary, such as `200 · JSON · 2 items`.
  String get summary => switch (kind) {
    DeceiverResponseKind.json => '$statusCode · JSON${_jsonSummary()}',
    DeceiverResponseKind.error => '$statusCode · error${_errorSummary()}',
    DeceiverResponseKind.empty => '$statusCode · empty',
    DeceiverResponseKind.sequential => 'sequence: ${_variantCodes(' → ')}',
    DeceiverResponseKind.random => 'random: ${_variantCodes(' | ')}',
    DeceiverResponseKind.custom => 'custom response',
  };

  String _jsonSummary() {
    final body = this.body;
    if (body == null || body.isEmpty) return '';
    return switch (jsonDecode(body)) {
      List(length: 1) => ' · 1 item',
      List(:final length) => ' · $length items',
      Map(length: 1) => ' · 1 field',
      Map(:final length) => ' · $length fields',
      _ => ' · ${body.length > 30 ? '${body.substring(0, 30)}…' : body}',
    };
  }

  String _errorSummary() {
    final body = this.body;
    if (body == null || body.isEmpty) return '';
    return switch (jsonDecode(body)) {
      {'error': final String message} => ': "$message"',
      _ => '',
    };
  }

  String _variantCodes(String separator) =>
      variants.map((v) => v.statusCode?.toString() ?? '?').join(separator);
}

final _infos = Expando<DeceiverResponseInfo>('DeceiverResponseInfo');

/// Attaches [info] to [builder] and returns [builder].
DeceiverResponseBuilder describeResponse(
  DeceiverResponseBuilder builder,
  DeceiverResponseInfo info,
) {
  _infos[builder] = info;
  return builder;
}

/// The info attached to [builder] with [describeResponse], or
/// [DeceiverResponseInfo.custom].
DeceiverResponseInfo responseInfoOf(DeceiverResponseBuilder builder) =>
    _infos[builder] ?? DeceiverResponseInfo.custom;
