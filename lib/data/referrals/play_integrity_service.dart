import 'dart:io';

import 'package:flutter/services.dart';

/// What the device could do with an Integrity request.
sealed class IntegrityTokenResult {
  const IntegrityTokenResult();
}

class IntegrityToken extends IntegrityTokenResult {
  final String token;
  const IntegrityToken(this.token);
}

/// Play Integrity cannot run here (no Play Store or services, outdated, or
/// not installed through Play). The server routes such receipts to review.
class IntegrityUnsupported extends IntegrityTokenResult {
  const IntegrityUnsupported();
}

/// Try again later: network, rate limit, or a Play-side outage.
class IntegrityRetry extends IntegrityTokenResult {
  const IntegrityRetry();
}

/// Our own configuration is wrong (Cloud project number, request hash). Kept
/// apart from "unsupported" so a bad build never sends everyone to review.
class IntegrityMisconfigured extends IntegrityTokenResult {
  const IntegrityMisconfigured();
}

abstract interface class PlayIntegrityService {
  Future<IntegrityTokenResult> requestToken(String requestHash);
}

/// Standard Play Integrity requests through `MainActivity`. The Cloud project
/// number comes from `--dart-define=PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER`.
class AndroidPlayIntegrityService implements PlayIntegrityService {
  static const _channel = MethodChannel(
    'com.eminentsite.czechify/play_integrity',
  );
  static const _projectNumber = int.fromEnvironment(
    'PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER',
  );

  const AndroidPlayIntegrityService();

  @override
  Future<IntegrityTokenResult> requestToken(String requestHash) async {
    if (!Platform.isAndroid) return const IntegrityUnsupported();
    if (_projectNumber <= 0) return const IntegrityMisconfigured();
    try {
      final response = await _channel.invokeMapMethod<String, Object?>(
        'requestToken',
        {'cloudProjectNumber': _projectNumber, 'requestHash': requestHash},
      );
      return decodeIntegrityResponse(response);
    } on PlatformException {
      return const IntegrityRetry();
    } on MissingPluginException {
      return const IntegrityUnsupported();
    }
  }
}

IntegrityTokenResult decodeIntegrityResponse(Map<String, Object?>? response) =>
    switch (response?['status']) {
      'ok'
          when response?['token'] is String &&
              (response!['token'] as String).isNotEmpty =>
        IntegrityToken(response['token'] as String),
      'unsupported' => const IntegrityUnsupported(),
      'misconfigured' => const IntegrityMisconfigured(),
      _ => const IntegrityRetry(),
    };
