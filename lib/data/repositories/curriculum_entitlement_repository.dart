import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/curriculum_entitlement.dart';

typedef CurriculumEntitlementFetch =
    Future<Map<String, dynamic>?> Function(String userId);

/// Reads a server-owned curriculum override and keeps the last authoritative
/// result available offline. Cache keys include the auth user id so switching
/// accounts can never carry reviewer access into another account.
class CurriculumEntitlementRepository {
  CurriculumEntitlementRepository({
    required this.fetchRemote,
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;

  static const _cachePrefix = 'curriculum_entitlement_v1_';

  final CurriculumEntitlementFetch fetchRemote;
  final Future<SharedPreferences> Function() _preferences;

  Future<CurriculumEntitlement> load(String? userId) async {
    if (userId == null || userId.isEmpty) return CurriculumEntitlement.none;
    final preferences = await _preferences();
    final cacheKey = '$_cachePrefix$userId';

    try {
      final row = await fetchRemote(userId);
      final entitlement =
          row == null
              ? CurriculumEntitlement.none
              : CurriculumEntitlement.fromJson(row);
      await preferences.setString(cacheKey, jsonEncode(entitlement.toJson()));
      return entitlement;
    } catch (_) {
      final cached = preferences.getString(cacheKey);
      if (cached == null) return CurriculumEntitlement.none;
      try {
        final json = jsonDecode(cached);
        if (json is! Map<String, dynamic>) return CurriculumEntitlement.none;
        return CurriculumEntitlement.fromJson(json);
      } catch (_) {
        return CurriculumEntitlement.none;
      }
    }
  }
}
