/// User-facing failure returned by the server-managed AI service.
class LlmServiceException implements Exception {
  const LlmServiceException(this.message, {this.code});

  final String message;

  /// The server's machine-readable reason (for example `quota_exceeded`),
  /// when it sent one.
  final String? code;

  @override
  String toString() => message;
}
