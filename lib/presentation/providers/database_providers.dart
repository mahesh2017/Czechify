import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/database/database.dart' as db;
import '../../data/repositories/drift_curriculum_repository.dart';
import '../../data/repositories/drift_vocabulary_repository.dart';
import '../../data/repositories/drift_conversation_repository.dart';
import '../../data/repositories/drift_progress_repository.dart';
import '../../data/repositories/drift_exam_repository.dart';
import '../../data/seeds/content_seeder.dart';
import '../../data/content/curriculum_pack_source.dart';
import '../../domain/repositories/curriculum_repository.dart';
import '../../domain/repositories/vocabulary_repository.dart';
import '../../domain/repositories/conversation_repository.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/repositories/exam_repository.dart';
import 'sync_providers.dart';

/// Database singleton provider.
final databaseProvider = Provider<db.AppDatabase>((ref) {
  final database = db.AppDatabase();
  ref.onDispose(database.close);
  return database;
});

/// Content seeder provider.
final contentSeederProvider = Provider<ContentSeeder>((ref) {
  return ContentSeeder(
    ref.read(databaseProvider),
    CurriculumPackSource(backend: ref.read(backendServiceProvider)),
  );
});

/// Curriculum repository provider.
final curriculumRepositoryProvider = Provider<CurriculumRepository>((ref) {
  return DriftCurriculumRepository(ref.read(databaseProvider));
});

/// Vocabulary repository provider.
final vocabularyRepositoryProvider = Provider<VocabularyRepository>((ref) {
  return DriftVocabularyRepository(ref.read(databaseProvider));
});

/// Conversation repository provider.
final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return DriftConversationRepository(ref.read(databaseProvider));
});

/// Progress repository provider.
final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return DriftProgressRepository(ref.read(databaseProvider));
});

/// Exam repository provider.
final examRepositoryProvider = Provider<ExamRepository>((ref) {
  return DriftExamRepository(ref.read(databaseProvider));
});

/// SharedPreferences provider for lightweight KV storage.
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

/// Key under which the last-installed bundled content revision is stored.
const _bundledRevisionKey = 'bundled_content_revision';

/// App initialization is local-first: verify existing content or atomically
/// install the bundled snapshot. Network availability never gates the router.
///
/// A stored content revision forces a re-seed when the app ships changed
/// content, since [ContentSeeder.hasUsableLocalContent] only checks counts and
/// would miss an edit that keeps the counts identical.
final appInitializationProvider = FutureProvider<void>((ref) async {
  final seeder = ref.read(contentSeederProvider);
  final prefs = await SharedPreferences.getInstance();
  final installedRevision = prefs.getInt(_bundledRevisionKey) ?? 0;

  if (installedRevision != ContentSeeder.bundledContentRevision) {
    await seeder.reinstallBundledContent();
    await prefs.setInt(
      _bundledRevisionKey,
      ContentSeeder.bundledContentRevision,
    );
  } else {
    await seeder.ensureBundledContent();
  }
});

/// Refresh backend state and curriculum after local startup has completed.
/// Consumers deliberately ignore errors so cached/bundled content remains
/// usable during outages.
final backgroundInitializationProvider = FutureProvider<void>((ref) async {
  await ref.watch(appInitializationProvider.future);
  await ref.watch(backendInitProvider.future);
  await ref.read(contentSeederProvider).refreshFromRemote();
});
