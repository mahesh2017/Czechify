import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/monetization/monetization_repository.dart';
import '../../data/monetization/snapshot_verifier.dart';
import 'database_providers.dart';
import 'sync_providers.dart';

/// Public Ed25519 verification keys only. Empty in development and before
/// rollout. Never fetch verification keys from the signed document itself.
final snapshotVerifierProvider = Provider<SnapshotVerifier>((ref) {
  const raw = String.fromEnvironment(
    'MONETIZATION_SNAPSHOT_PUBLIC_KEYS',
    defaultValue: '{}',
  );
  final keys = jsonDecode(raw) as Map<String, dynamic>;
  return SnapshotVerifier({
    for (final e in keys.entries)
      e.key: base64Url.decode(base64Url.normalize(e.value as String)),
  });
});

final Provider<MonetizationRepository> monetizationRepositoryProvider =
    Provider<MonetizationRepository>((ref) {
      final backend = ref.watch(backendServiceProvider);
      final repository = MonetizationRepository(
        database: ref.watch(databaseProvider),
        verifier: ref.watch(snapshotVerifierProvider),
        fetch: (accountId) async {
          if (backend.userId != accountId || backend.client == null) {
            throw const EntitlementFetchUnavailable(
              'Account context unavailable.',
            );
          }
          final response = await backend.client!.functions.invoke(
            'monetization-api/entitlements',
            method: HttpMethod.get,
          );
          final data = response.data;
          if (response.status != 200 ||
              data is! Map ||
              data['snapshot_jws'] is! String) {
            throw const FormatException('Entitlement service unavailable.');
          }
          return data['snapshot_jws'] as String;
        },
      )..setAccount(backend.userId);
      if (backend.client != null) {
        final subscription = backend.authChanges.listen((_) {
          repository.setAccount(backend.userId);
          ref.invalidate(monetizationLoadProvider);
        });
        ref.onDispose(subscription.cancel);
      }
      ref.onDispose(repository.dispose);
      return repository;
    });

final FutureProvider<MonetizationLoad> monetizationLoadProvider =
    FutureProvider<MonetizationLoad>((ref) async {
      await ref.watch(backendInitProvider.future);
      final result = await ref.watch(monetizationRepositoryProvider).load();
      final document = result.document;
      if (document != null) {
        final boundaries =
            [
                  document.snapshot.core.validUntil,
                  document.snapshot.core.offlineValidUntil,
                  document.snapshot.migrationGraceUntil,
                  document.staff.expiresAt,
                ]
                .whereType<DateTime>()
                .where((t) => t.isAfter(result.now))
                .toList()
              ..sort();
        if (boundaries.isNotEmpty) {
          final timer = Timer(
            boundaries.first.difference(result.now),
            ref.invalidateSelf,
          );
          ref.onDispose(timer.cancel);
        }
      }
      return result;
    });
