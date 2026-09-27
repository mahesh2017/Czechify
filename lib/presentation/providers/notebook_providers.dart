import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/notebook_store.dart';

/// Where notebook steps are recorded on this device.
final notebookStoreProvider = Provider<NotebookStore>((ref) => NotebookStore());

/// Notebook steps put off with "I don't have a pen right now", oldest first.
///
/// Invalidate after [NotebookStore.defer], [NotebookStore.markWritten] or
/// [NotebookStore.record] so the copybook shows the current list.
final notebookTodoProvider = FutureProvider<List<NotebookTodo>>((ref) async {
  final todos = await ref.read(notebookStoreProvider).todos();
  return todos..sort((a, b) => a.deferredAt.compareTo(b.deferredAt));
});
