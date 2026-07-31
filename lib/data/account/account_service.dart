import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database.dart';
import '../sync/backend_service.dart';
import '../sync/sync_service.dart';

class AccountService {
  AccountService(
    this._backend,
    this._db,
    this._sync, {
    this.onLocalDataChanged,
  });

  final BackendService _backend;
  final AppDatabase _db;
  final SyncService _sync;
  final void Function()? onLocalDataChanged;

  Future<void> linkEmail(String email) => _backend.requestEmailLink(email);

  /// Whether [deleteAccountAndLocalData] needs a password to re-authenticate.
  bool get deletionNeedsPassword => _backend.requiresPasswordToDelete;

  Future<void> setPassword(String password) => _backend.setPassword(password);

  Future<void> sendPasswordRecovery(String email) =>
      _backend.sendPasswordRecovery(email);

  Future<void> switchToExistingAccount({
    required String email,
    required String password,
  }) async {
    final session = await _backend.authenticateExisting(
      email: email,
      password: password,
    );
    final previousSession = _backend.currentSession;
    var targetCommitted = false;
    await _sync.beginAccountTransition();
    try {
      await _backend.installSession(session);
      final snapshot = await _sync.downloadAccountSnapshot();
      await _db.transaction(() async {
        await _db.clearLearnerDataRows();
        await _sync.installAccountSnapshot(snapshot);
        if (_backend.userId != session.user.id) {
          throw StateError('Target account session changed during install.');
        }
      });
      targetCommitted = true;
      await _clearAccountScopedArtifacts();
      onLocalDataChanged?.call();
    } catch (_) {
      // Once the target database commit succeeds, restoring the old session
      // would expose target data under the wrong identity.
      if (!targetCommitted && previousSession != null) {
        await _backend.installSession(previousSession);
      } else if (!targetCommitted) {
        await _backend.clearLocalSession();
      }
      rethrow;
    } finally {
      _sync.endAccountTransition();
    }
  }

  Future<File> createExportFile() async {
    final local = await _db.exportLearnerData();
    final preferences = await _exportLocalPreferences();
    Map<String, dynamic>? cloud;
    if (_backend.isSignedIn) cloud = await _backend.exportCloudData();
    final payload = {
      'format': 'czechify-user-export',
      'format_version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'local_data': local,
      'local_preferences': preferences,
      'cloud_export': cloud,
    };
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/czechify-export-${DateTime.now().millisecondsSinceEpoch}.json',
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
    return file;
  }

  Future<void> shareExport() async {
    final file = await createExportFile();
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'Czechify data export',
        ),
      );
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  /// [password] is forwarded to re-authenticate before the cloud account is
  /// deleted; see [BackendService.deleteCloudAccount]. Null is correct for
  /// anonymous accounts, which have no credential to re-enter.
  Future<void> deleteAccountAndLocalData({String? password}) async {
    if (_backend.isSignedIn) {
      await _backend.deleteCloudAccount(password: password);
    }
    await _db.clearLearnerData();
    await _clearAccountScopedArtifacts();
    await _backend.ensureAnonymousSession();
    onLocalDataChanged?.call();
  }

  Future<Map<String, Object?>> _exportLocalPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    return {
      for (final key in _exportablePreferenceKeys)
        if (preferences.containsKey(key)) key: preferences.get(key),
    };
  }

  /// Auth/session, PKCE, device-id, and internal keys must never be exported.
  static const _exportablePreferenceKeys = <String>{
    'settings_learner_name',
    'settings_starting_level',
    'settings_onboarding_done',
    'settings_theme_mode',
    'settings_tts_rate',
    'settings_tts_voice_gender',
    'settings_daily_goal_xp',
    'settings_hearts_enabled',
    'settings_sound_enabled',
    'settings_haptic_enabled',
  };

  Future<void> _clearAccountScopedArtifacts() async {
    final preferences = await SharedPreferences.getInstance();
    for (final key in const {
      'settings_learner_name',
      'settings_starting_level',
      'settings_onboarding_done',
      'srs_new_cards_today',
      'srs_new_cards_date',
      'exam_checkpoint_a1',
      'exam_checkpoint_a2',
    }) {
      await preferences.remove(key);
    }

    final temporary = await getTemporaryDirectory();
    if (!await temporary.exists()) return;
    await for (final entity in temporary.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (name.startsWith('pronunciation_') && name.endsWith('.wav') ||
          name.startsWith('czechify-export-') && name.endsWith('.json')) {
        try {
          await entity.delete();
        } catch (_) {
          // Best effort for files held open by the platform audio/share layer.
        }
      }
    }
  }
}
